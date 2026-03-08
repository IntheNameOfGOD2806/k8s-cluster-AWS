variable "ami" {
  type = map(string)
  default = {
    "master"   = "ami-00d8fc944fb171e29"
    "worker"   = "ami-00d8fc944fb171e29"
    "nginx_lb" = "ami-00d8fc944fb171e29"
    "nfs"      = "ami-00d8fc944fb171e29"
  }
}

variable "instance_type" {
  type = map(string)
  default = {
    "master"   = "t2.medium"
    "worker"   = "t2.medium"
    "nginx_lb" = "t2.medium"
    "nfs"      = "t2.medium"
  }
}

variable "worker_count" {
  type    = number
  default = 2
}
variable "nfs_count" {
  type    = number
  default = 3
}

variable "region" {
  default = "ap-southeast-1"
}
