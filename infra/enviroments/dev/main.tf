terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "ec2" {
  source = "../../modules/ec2"

  name     = "depi-dev"
  key_name = var.key_name
  my_ip    = var.my_ip
}