# Fetch the existing VPC by its Name tag
data "aws_vpc" "dattran_vpc" {
  filter {
    name   = "tag:Name"
    values = ["dattran-vpc"]
  }
}

# Fetch the existing Subnet within that VPC
data "aws_subnet" "dattran_subnet" {
  filter {
    name   = "tag:Name"
    values = ["public-subnet"]
  }
  vpc_id = data.aws_vpc.dattran_vpc.id
}
data "aws_subnet" "dattran_subnet-1" {
  filter {
    name   = "tag:Name"
    values = ["public-subnet-1"]
  }
  vpc_id = data.aws_vpc.dattran_vpc.id
}
data "aws_subnet" "dattran_subnet_public_alb" {
  filter {
    name   = "tag:Name"
    values = ["public-subnet-forALB"]
  }
  vpc_id = data.aws_vpc.dattran_vpc.id
}
data "aws_subnet" "dattran_private_subnet" {
  filter {
    name   = "tag:Name"
    values = ["private-subnet-1(real)"]
  }
  vpc_id = data.aws_vpc.dattran_vpc.id
}

data "aws_security_group" "k8s_vpn" {
  filter {
    name   = "tag:Name"
    values = ["k8s-vpn-sg"]
  }
  vpc_id = data.aws_vpc.dattran_vpc.id
}
# File: lb.tf (hoặc dán vào file hiện tại)

