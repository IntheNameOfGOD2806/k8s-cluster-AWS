# 1. Tạo IAM Role
resource "aws_iam_role" "k8s_node_role" {
  name = "k8s-node-ebs-role"

  # Cho phép các dịch vụ EC2 "mượn" (assume) Role này
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# 2. Đính kèm Policy chuẩn của AWS cho EBS CSI Driver
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.k8s_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# 3. Tạo Instance Profile (Cái này là cầu nối giữa Role và EC2)
resource "aws_iam_instance_profile" "k8s_node_profile" {
  name = "k8s-node-profile"
  role = aws_iam_role.k8s_node_role.name
}
