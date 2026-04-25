resource "aws_security_group" "k8s_nfs" {
  name        = "k8s_nfs"
  description = "k8s nfs"
  vpc_id      = data.aws_vpc.dattran_vpc.id

  tags = {
    Name = "k8s_nfs"
  }
}
# allow all traffic from VPN security group
resource "aws_vpc_security_group_ingress_rule" "allow_all_traffic_nfs_vpn" {
  security_group_id            = aws_security_group.k8s_nfs.id
  referenced_security_group_id = data.aws_security_group.k8s_vpn.id
  #cidr_ipv6         = "::/0"
  ip_protocol = "-1"
}

# allow all traffic from master security group
resource "aws_vpc_security_group_ingress_rule" "allow_all_traffic_nfs_master" {
  security_group_id            = aws_security_group.k8s_nfs.id
  referenced_security_group_id = aws_security_group.k8s_master.id
  #cidr_ipv6         = "::/0"
  ip_protocol = "-1"

}
resource "aws_vpc_security_group_ingress_rule" "allow_all_traffic_nfs_worker" {
  security_group_id            = aws_security_group.k8s_nfs.id
  referenced_security_group_id = aws_security_group.k8s_worker.id
  #cidr_ipv6         = "::/0"
  ip_protocol = "-1"

}

resource "aws_vpc_security_group_ingress_rule" "allow_all_inbound" {
  security_group_id = aws_security_group.k8s_nfs.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_nfs" {
  security_group_id = aws_security_group.k8s_nfs.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}

#k8s nginx lb
resource "aws_security_group" "k8s_nginx_lb" {
  name        = "k8s_nginx_lb_sg"
  description = "k8s nginx lb sg"
  vpc_id      = data.aws_vpc.dattran_vpc.id

  tags = {
    Name = "k8s_nginx_lb_sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "SSH_nginx_lb" {
  security_group_id = aws_security_group.k8s_nginx_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}
resource "aws_vpc_security_group_ingress_rule" "Rancher_HTTPS_nginx_lb" {
  security_group_id = aws_security_group.k8s_nginx_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 444
  ip_protocol = "tcp"
  to_port     = 444
}
resource "aws_vpc_security_group_ingress_rule" "nodePort" {
  security_group_id = aws_security_group.k8s_nginx_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 30000
  ip_protocol = "tcp"
  to_port     = 32767
}
resource "aws_vpc_security_group_ingress_rule" "kube_api_6443" {
  security_group_id = aws_security_group.k8s_nginx_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6443
  ip_protocol = "tcp"
  to_port     = 6443
}
#allow 9991 of jenkins
resource "aws_vpc_security_group_ingress_rule" "allow_jenkins" {
  security_group_id = aws_security_group.k8s_nginx_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 9991
  ip_protocol = "tcp"
  to_port     = 9991
}
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.k8s_nginx_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.k8s_nginx_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}
# egress allow all
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_nginx_lb" {
  security_group_id = aws_security_group.k8s_nginx_lb.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}

# k8s master
resource "aws_security_group" "k8s_master" {
  name        = "k8s_master_sg"
  description = "k8s master sg"
  vpc_id      = data.aws_vpc.dattran_vpc.id

  tags = {
    Name = "k8s_master_sg"
  }
}


resource "aws_vpc_security_group_ingress_rule" "SSH" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "Rancher_HTTPS" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 444
  ip_protocol = "tcp"
  to_port     = 444
}
# resource "aws_vpc_security_group_ingress_rule" "Rancher_HTTP" {
#   security_group_id = aws_security_group.k8s_master.id
#   cidr_ipv4         = "0.0.0.0/0"
#   #cidr_ipv6         = "::/0"
#   from_port   = 81
#   ip_protocol = "tcp"
#   to_port     = 81
# }

resource "aws_vpc_security_group_ingress_rule" "api_server" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6443
  ip_protocol = "tcp"
  to_port     = 6443
}

resource "aws_vpc_security_group_ingress_rule" "ETCD" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 2379
  ip_protocol = "tcp"
  to_port     = 2380
}

resource "aws_vpc_security_group_ingress_rule" "weavenet_tcp" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6783
  ip_protocol = "tcp"
  to_port     = 6783
}
resource "aws_vpc_security_group_ingress_rule" "flannel_UDP_VXLAN" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8472
  ip_protocol = "udp"
  to_port     = 8472
}
resource "aws_vpc_security_group_ingress_rule" "flannel_UDP_BE" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8285
  ip_protocol = "udp"
  to_port     = 8285
}
# resource "aws_vpc_security_group_ingress_rule" "rancher_444" {
#   security_group_id = aws_security_group.k8s_master.id
#   cidr_ipv4         = "0.0.0.0/0"
#   #cidr_ipv6         = "::/0"
#   from_port   = 444
#   ip_protocol = "tcp"
#   to_port     = 444
# }
resource "aws_vpc_security_group_ingress_rule" "rancher_81" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 81
  ip_protocol = "tcp"
  to_port     = 81
}


resource "aws_vpc_security_group_ingress_rule" "weavenet_udp" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6784
  ip_protocol = "udp"
  to_port     = 6784
}

resource "aws_vpc_security_group_ingress_rule" "kubelet_and_control_plane" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 10248
  ip_protocol = "tcp"
  to_port     = 10260
}

resource "aws_vpc_security_group_ingress_rule" "NodePort_Service" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 30000
  ip_protocol = "tcp"
  to_port     = 32767
}

resource "aws_vpc_security_group_ingress_rule" "HTTP" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "HTTPS" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "HTTP_8080" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8080
  ip_protocol = "tcp"
  to_port     = 8080
}
resource "aws_vpc_security_group_ingress_rule" "internal_traffic_master" {
  security_group_id            = aws_security_group.k8s_master.id
  referenced_security_group_id = aws_security_group.k8s_nginx_lb.id
  # cidr_ipv4                    = "10.0.0.0/16"
  #cidr_ipv6         = "::/0"
  from_port   = 0
  ip_protocol = "tcp"
  to_port     = 65535
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_master" {
  security_group_id = aws_security_group.k8s_master.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  ip_protocol = "-1" # semantically equivalent to all ports
}


#worker
resource "aws_security_group" "k8s_worker" {
  name        = "k8s_worker_sg"
  description = "k8s worker sg"
  vpc_id      = data.aws_vpc.dattran_vpc.id

  tags = {
    Name = "k8s_worker_sg"
  }
}

#allow all traffic from nginx lb security group

resource "aws_vpc_security_group_ingress_rule" "internal_traffic_worker" {
  security_group_id            = aws_security_group.k8s_worker.id
  referenced_security_group_id = aws_security_group.k8s_nginx_lb.id
  # cidr_ipv4                    = "10.0.0.0/16"
  #cidr_ipv6         = "::/0"
  from_port   = 0
  ip_protocol = "tcp"
  to_port     = 65535
}
resource "aws_vpc_security_group_ingress_rule" "flannel_UDP_VXLAN_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8472
  ip_protocol = "udp"
  to_port     = 8472
}
resource "aws_vpc_security_group_ingress_rule" "flannel_UDP_BE_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8285
  ip_protocol = "udp"
  to_port     = 8285
}
resource "aws_vpc_security_group_ingress_rule" "SSH_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "api_server_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6443
  ip_protocol = "tcp"
  to_port     = 6443
}

resource "aws_vpc_security_group_ingress_rule" "ETCD_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 2379
  ip_protocol = "tcp"
  to_port     = 2380
}

resource "aws_vpc_security_group_ingress_rule" "weavenet_tcp_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6783
  ip_protocol = "tcp"
  to_port     = 6783
}

resource "aws_vpc_security_group_ingress_rule" "weavenet_udp_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 6784
  ip_protocol = "udp"
  to_port     = 6784
}

resource "aws_vpc_security_group_ingress_rule" "kubelet_and_control_plane_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 10248
  ip_protocol = "tcp"
  to_port     = 10260
}

resource "aws_vpc_security_group_ingress_rule" "NodePort_Service_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 30000
  ip_protocol = "tcp"
  to_port     = 32767
}

resource "aws_vpc_security_group_ingress_rule" "HTTP_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "HTTPS_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "HTTP_8080_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 8080
  ip_protocol = "tcp"
  to_port     = 8080
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_worker" {
  security_group_id = aws_security_group.k8s_worker.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#NFS server
resource "aws_security_group" "nfs" {
  name        = "nfs_sg"
  description = "nfs sg"
  vpc_id      = data.aws_vpc.dattran_vpc.id

  tags = {
    Name = "nfs_sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "NFS_server" {
  security_group_id = aws_security_group.nfs.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_ipv6         = "::/0"
  from_port   = 2049
  ip_protocol = "tcp"
  to_port     = 2049
}

