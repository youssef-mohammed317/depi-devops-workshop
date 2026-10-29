variable "name" {
  type        = string
  description = "Name of the EC2 instance"
}

variable "key_name" {
  type        = string
  description = "Name of the existing AWS Key Pair to use for SSH access"
}

variable "my_ip" {
  type        = string
  description = "Your public IP address for security group rules"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "Type of EC2 instance to launch"
}

variable "app_port" {
  type        = number
  description = "Port number for the application server"
  default     = 5000
}