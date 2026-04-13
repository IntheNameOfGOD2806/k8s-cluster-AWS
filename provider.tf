terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.21.0"
    }
  }
}

provider "aws" {
  region = var.region
  #   deprecated from terraform 4.x
  #   profile = "default"
}