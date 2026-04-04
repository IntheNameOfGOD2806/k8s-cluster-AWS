# Khởi tạo EC2 instance làm Nginx Load Balancer (TCP Proxy đứng trước các K8s Master Nodes)
# Thực thi provisioning qua Ansible: cài Docker, cấu hình stream TCP, cài FileBrowser.
resource "aws_instance" "k8s_nginx_lb" {
  ami           = var.ami["nginx_lb"]
  instance_type = var.instance_type["nginx_lb"]
  # Gán profile đã tạo ở trên vào đây
  # iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name

  # # QUAN TRỌNG: Để fix lỗi IMDS 404/hop limit cho CSI Driver
  # metadata_options {
  #   http_endpoint               = "enabled"
  #   http_tokens                 = "required" # Sử dụng IMDSv2
  #   http_put_response_hop_limit = 2          # Phải là 2 để Pod truy cập được metadata
  # }
  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_subnet.id
  tags = {
    Name = "k8s_nginx_lb"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_nginx_lb.id]
  # depends_on      = [aws_instance.k8s_master, aws_instance.k8s_worker]
  # 
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.public_ip
  }
  provisioner "local-exec" {
    command = "sleep 60 && ansible-playbook -i '${self.public_ip},' installDocker.yaml"
  }

  #nginx
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' installNginx.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/nginx/tcpconf.d",
      "echo 'stream { include /etc/nginx/tcpconf.d/*.conf; }' | sudo tee -a /etc/nginx/nginx.conf"
    ]
  }
  #file browser
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' installFileBrowser.yaml"
  }
  #jenkins
  # provisioner "local-exec" {
  #   command = "ansible-playbook -i '${self.public_ip},' installjenkins.yaml"
  # }
}

# Khởi tạo EC2 instance làm Kubernetes Master Node 1 (Control Plane chính)
# Khởi tạo K8s cluster (kubeadm init), cài đặt Docker, Rancher, ArgoCD, Prometheus, Grafana và cập nhật IP cho Nginx LB.
resource "aws_instance" "k8s_master" {
  ami           = var.ami["master"]
  instance_type = var.instance_type["master"]
  # Gán profile đã tạo ở trên vào đây
  iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name

  # QUAN TRỌNG: Để fix lỗi IMDS 404/hop limit cho CSI Driver
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Sử dụng IMDSv2
    http_put_response_hop_limit = 2          # Phải là 2 để Pod truy cập được metadata
  }
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_subnet.id
  tags = {
    Name = "k8s_master"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_master.id]
  depends_on      = [aws_instance.k8s_nginx_lb]
  # 
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.public_ip
  }
  provisioner "file" {
    source      = "./master.sh"
    destination = "/home/ubuntu/master.sh"
  }
  provisioner "file" {
    source      = "./nginx_lb.conf"
    destination = "/home/ubuntu/nginx_lb.conf"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("k8s.pem")
      host        = aws_instance.k8s_nginx_lb.public_ip
    }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("k8s.pem")
      host        = aws_instance.k8s_nginx_lb.public_ip
    }
    inline = [
      "sudo cp /home/ubuntu/nginx_lb.conf /etc/nginx/tcpconf.d/k8s.conf",
      "sudo sed -i 's/PLACEHOLDER_MASTER_IP_1/${aws_instance.k8s_master.private_ip}/g' /etc/nginx/tcpconf.d/k8s.conf",
      "sudo systemctl reload nginx"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 20"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/master.sh",
      "sudo sh /home/ubuntu/master.sh k8s-master ${aws_instance.k8s_nginx_lb.private_ip}"
    ]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' getJoinCommandk8s.yaml"
  }
  provisioner "local-exec" {
    # install docker
    command = "ansible-playbook -i '${self.public_ip},' installDocker.yaml"
  }
  provisioner "local-exec" {
    # install rancher
    command = "ansible-playbook -i '${self.public_ip},' installRancher.yaml"
  }
  provisioner "local-exec" {
    # fetch kubeconfig
    command = "ansible-playbook -i '${self.public_ip},' fetchKubeConfigfromMaster.yaml"
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' installHelm.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "kubectl create namespace argocd",
      "kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    ]

  }
  provisioner "file" {
    source      = "./storageClassEBS.yaml"
    destination = "/home/ubuntu/storageClassEBS.yaml"
  }
  provisioner "file" {
    source      = "./values-edit.yaml"
    destination = "/home/ubuntu/values-edit.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "kubectl apply -f /home/ubuntu/storageClassEBS.yaml"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver",
      "helm repo update",
      "helm upgrade --install aws-ebs-csi-driver --namespace kube-system aws-ebs-csi-driver/aws-ebs-csi-driver"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts",
      "helm repo add grafana https://grafana.github.io/helm-charts",
      "helm repo update",
      "kubectl create namespace monitoring"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "kubectl create namespace logging",
      "helm repo add elastic https://helm.elastic.co",
      "helm repo update",
      "helm search repo elastic --version 7",
      "helm pull elastic/elasticsearch --version 7.17.3"
    ]
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "cd /home/ubuntu",
  #     "export HELM_MAX_INDEX_SIZE=20971520",
  #     # "helm search repo kube-prometheus-stack",
  #     # "helm pull prometheus-community/kube-prometheus-stack",
  #     # "tar -xvzf kube-prometheus-stack-82.13.6.tgz",
  #     # "cd kube-prometheus-stack",
  #     "helm upgrade -i prometheus -n monitoring -f values-edit.yaml ."
  #   ]

  # }
  # provisioner "remote-exec" {
  #   inline = [
  #     "helm upgrade -i prometheus -n monitoring -f values-edit.yaml ."
  #   ]
  # }

}
# resource "helm_release" "aws_ebs_csi_driver" {
#   name       = "aws-ebs-csi-driver"
#   repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
#   chart      = "aws-ebs-csi-driver"
#   namespace  = "kube-system"
# }

# Khởi tạo EC2 instance làm Kubernetes Master Node 2 (Control Plane dự phòng - cho High Availability)
# Chạy ở Private Subnet, dùng Nginx LB làm Bastion. Join cluster dưới dạng control-plane và cập nhật IP vào Nginx LB.
resource "aws_instance" "k8s_master_2" {
  ami           = var.ami["master"]
  instance_type = var.instance_type["master"]
  # Gán profile đã tạo ở trên vào đây
  iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name

  # QUAN TRỌNG: Để fix lỗi IMDS 404/hop limit cho CSI Driver
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Sử dụng IMDSv2
    http_put_response_hop_limit = 2          # Phải là 2 để Pod truy cập được metadata
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_private_subnet.id
  tags = {
    Name = "k8s_master_2"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_master.id]
  depends_on      = [aws_instance.k8s_master]
  # 
  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = file("k8s.pem")
    host                = self.private_ip
    bastion_host        = aws_instance.k8s_nginx_lb.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("k8s.pem")
  }
  provisioner "file" {
    source      = "./master-2.sh"
    destination = "/home/ubuntu/master-2.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/master-2.sh",
      "sudo sh /home/ubuntu/master-2.sh k8s-master-2"
    ]
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("k8s.pem")
      host        = aws_instance.k8s_nginx_lb.public_ip
    }
    inline = [
      # Không cần cp nữa vì file đã có từ Master 1
      "sudo sed -i 's/localhost/${aws_instance.k8s_master_2.private_ip}/g' /etc/nginx/tcpconf.d/k8s.conf",
      "sudo systemctl reload nginx"
    ]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i '${self.public_ip},' getJoinCommandk8s.yaml"
  }
  provisioner "local-exec" {
    # install docker
    command = "ansible-playbook -i '${self.public_ip},' installDocker.yaml"
  }
  # provisioner "local-exec" {
  #   # install rancher
  #   command = "ansible-playbook -i '${self.public_ip},' installRancher.yaml"
  # }
  # provisioner "local-exec" {
  #   # fetch kubeconfig
  #   command = "ansible-playbook -i '${self.public_ip},' fetchKubeConfigfromMaster.yaml"
  # }
  provisioner "file" {
    source      = "./join-command-master.sh"
    destination = "/home/ubuntu/join-command-master.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "set -e", # Dừng script ngay nếu có lệnh lỗi
      "echo '-------------Joining Cluster as Control Plane-------------'",

      # Kiểm tra và thực hiện Join
      "if [ -f '/home/ubuntu/join-command-master.sh' ]; then",
      "  sudo sh /home/ubuntu/join-command-master.sh",
      "else",
      "  echo 'LỖI: Không tìm thấy file join-command-master.sh!'",
      "  exit 1",
      "fi",

      "echo '-------------Cấu hình Kubeconfig cho user-------------'",

      # Tạo thư mục .kube và copy config
      "mkdir -p $HOME/.kube",
      "if [ -f '/etc/kubernetes/admin.conf' ]; then",
      "  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "  sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "  echo 'Cấu hình Kubeconfig thành công!'",
      "else",
      "  echo 'Cảnh báo: Không tìm thấy admin.conf. Có thể lệnh join chưa hoàn tất đúng cách.'",
      "fi"
    ]
  }

}

# Khởi tạo các EC2 instance làm Kubernetes Worker Node
# Chạy ở Private Subnet. Tự động nhận số lượng thông qua biến count và chạy script join Kubernetes cluster qua Bastion host.
resource "aws_instance" "k8s_worker" {
  count         = var.worker_count
  ami           = var.ami["worker"]
  instance_type = var.instance_type["worker"]
  # Gán profile đã tạo ở trên vào đây
  iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name

  # QUAN TRỌNG: Để fix lỗi IMDS 404/hop limit cho CSI Driver
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Sử dụng IMDSv2
    http_put_response_hop_limit = 2          # Phải là 2 để Pod truy cập được metadata
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_private_subnet.id
  tags = {
    Name = "k8s_worker-${count.index}"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_worker.id]
  depends_on      = [aws_instance.k8s_master]
  # 
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.private_ip
    # --- BASTION CONFIGURATION ---
    bastion_host        = aws_instance.k8s_nginx_lb.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("k8s.pem")
    # -----------------------------
  }
  provisioner "file" {
    source      = "./worker.sh"
    destination = "/home/ubuntu/worker.sh"
  }
  provisioner "file" {
    source      = "./join-command.sh"
    destination = "/home/ubuntu/join-command.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/worker.sh",
      "sudo sh /home/ubuntu/worker.sh k8s-worker-${count.index}",
      "chmod +x /home/ubuntu/join-command.sh",
      "sudo sh /home/ubuntu/join-command.sh"
    ]
  }
}





resource "aws_instance" "k8s_nfs" {
  count         = var.nfs_count
  ami           = var.ami["nfs"]
  instance_type = var.instance_type["nfs"]
  depends_on    = [aws_instance.k8s_master]
  # Gán profile đã tạo ở trên vào đây
  iam_instance_profile = aws_iam_instance_profile.k8s_node_ebs_profile_1.name
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
  subnet_id = data.aws_subnet.dattran_private_subnet.id
  tags = {
    Name = "k8s_nfs"
  }
  key_name        = aws_key_pair.k8s.key_name
  security_groups = [aws_security_group.k8s_nfs.id]
  # 

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("k8s.pem")
    host        = self.private_ip
    #bastion host
    bastion_host        = aws_instance.k8s_nginx_lb.public_ip
    bastion_user        = "ubuntu"
    bastion_private_key = file("k8s.pem")
  }
  # delay by remote exec
  provisioner "remote-exec" {
    inline = [
      "sleep 60"
    ]
  }
  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook -i '${self.private_ip},' installNFS.yaml \
      --private-key k8s.pem \
      --user ubuntu \
      --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i k8s.pem -o StrictHostKeyChecking=no -W %h:%p ubuntu@${aws_instance.k8s_master.public_ip}"'
    EOT
  }
}


#load balancer



# Target Group của Application Load Balancer để nhóm các resource chịu tải
# Được thiết lập cấu hình chạy giao thức HTTP/port 80. Lắng nghe và kiểm tra tình trạng kết nối.
resource "aws_lb_target_group" "k8s_tg_lb" { // Target Group A
  name     = "k8s-tg-lb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.dattran_vpc.id
  depends_on = [aws_instance.k8s_master,
    aws_instance.k8s_worker,
    aws_instance.k8s_nginx_lb,
    aws_instance.k8s_nfs
  ]
}
# Gắn (Attach) các EC2 instance thuộc Kubernetes Worker Node vào Target Group
# Hướng HTTP traffic đến NodePort (port 32222 - Ingress Service) của các Worker Node để vào cluster.
resource "aws_lb_target_group_attachment" "tg_attachment_lb" {
  count            = var.worker_count # Dùng luôn count cho đồng bộ với lúc tạo instance
  target_group_arn = aws_lb_target_group.k8s_tg_lb.arn
  target_id        = aws_instance.k8s_worker[count.index].id
  port             = 32222 # Đảm bảo Ingress Controller trên worker đang map đúng port này
}

# Cấu hình Listener cho Load Balancer
# Đóng vai trò lắng nghe request ở port 80 (HTTP) và định tuyến (forward) traffic toàn bộ vào Target Group ở trên.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.k8s_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_tg_lb.arn
  }
}

# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.k8s_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate.k8s_cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.k8s_tg_lb.arn
#   }
# }

# Thiết lập AWS Application Load Balancer (Layer 7) làm cổng mạng Ingress chính của hệ thống từ Internet ngoài
# Gắn vào public subnets và liên kết với Security Group cho phép traffic từ mọi nơi.
resource "aws_lb" "k8s_alb" {
  name               = "k8s-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.k8s_nginx_lb.id] # Dùng chung SG hoặc tạo mới
  subnets = [data.aws_subnet.dattran_subnet.id, data.aws_subnet.dattran_subnet-1.id,
    data.aws_subnet.dattran_subnet_public_alb.id,
  ]

  tags = {
    Name = "k8s-main-alb"
  }
}
