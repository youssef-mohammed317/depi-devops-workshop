variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "eu-west-1"
}

variable "key_name" {
  type        = string
  description = "Name of the existing AWS Key Pair to use for SSH access"
}

variable "my_ip" {
  type        = string
  description = "Your public IP address for security group rules"
}