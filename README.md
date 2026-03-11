# Hướng dẫn Provision Cụm Kubernetes (K8s) bằng Terraform & Ansible

Repository này chứa mã nguồn để tự động hóa việc khởi tạo một cụm Kubernetes High Availability (HA) trên AWS EC2, kết hợp với Nginx Load Balancer, NFS Server và AWS Application Load Balancer.

## 🏗️ Kiến Trúc Hệ Thống

Cụm K8s bao gồm:

- **1x Nginx Load Balancer (Bastion Host):** Đóng vai trò là cổng vào (entry point), đồng thời phân phối lưu lượng TCP (port 6443) đến các Master nodes.
- **2x Master Nodes (Control Plane):** Thiết lập HA bằng `kubeadm`.
- **3x Worker Nodes:** Chạy các workloads của ứng dụng.
- **2x NFS Server:** Cung cấp giải pháp lưu trữ tập trung cho các Pod (Persistent Volumes).
- **1x AWS ALB:** Phân phối lưu lượng HTTP/HTTPS đến các Worker nodes.


Trước khi bắt đầu, hãy đảm bảo máy của bạn đã cài đặt:

1. **Terraform** (>= 1.0.0)
2. **Ansible**
3. **AWS CLI** (đã cấu hình `aws configure`)
4. **SSH Key:** Cần có file private key `k8s.pem` trong thư mục gốc để Terraform/Ansible có thể truy cập các instance.

## 🛠️ Các Bước Thực Hiện

### 1. Chuẩn bị Key Pair

 private key:

```bash
chmod 400 k8s.pem
```

### 2. Cấu hình Biến (Variables)

 file `var.tf`

- `region`: Vùng triển khai (mặc định: `ap-southeast-1`).
- `worker_count`: Số lượng Worker nodes.
- `ami`: ID của Ubuntu AMI tương ứng với region.
- `instance_type`: Cấu hình hardware cho từng loại node.

### 3. Khởi tạo Terraform

```bash
terraform init
```

### 4. Kiểm tra và Triển khai

Kiểm tra các tài nguyên sẽ được tạo:

```bash
terraform plan
```

Tiến hành triển khai
```bash
terraform apply -auto-approve
```

##  Sau khi triển khai thành công

### Lấy Kubeconfig

Sau khi `terraform apply` hoàn tất, Ansible sẽ tự động fetch file `admin.conf` từ Master node về máy local của bạn. Bạn có thể kiểm tra trạng thái cụm bằng:

```bash
export KUBECONFIG=./admin.conf
kubectl get nodes
```

### Truy cập Rancher (Nếu được enable)

Nếu playbook `installRancher.yaml` được chạy, bạn có thể truy cập Rancher UI qua IP của Master node để quản lý cụm qua giao diện web.

### File Browser & Jenkins

Hệ thống cũng hỗ trợ cài đặt sẵn:

- **File Browser:** Quản lý file trên server qua web.
- **Jenkins:** Công cụ CI/CD (cần uncomment trong `main.tf` nếu muốn cài đặt).

## ⚠️ Lưu ý quan trọng

- **Security Groups:** Mọi rule bảo mật đã được định nghĩa trong `security_groups.tf`. Hãy cẩn trọng khi mở rộng các port ra internet.
- **Bastion Host:** Nginx LB node được sử dụng làm Bastion host để Terraform/Ansible có thể nhảy vào các node trong subnet riêng (private subnet).
- **Scripts:** Các script `master.sh`, `worker.sh` chứa logic setup core của K8s. Đừng xóa chúng vì Terraform sẽ upload chúng lên các instance khi khởi tạo.

## 🧹 Hủy tài nguyên

Để xóa toàn bộ hạ tầng đã tạo nhằm tránh phát sinh chi phí:

```bash
terraform destroy -auto-approve
```
