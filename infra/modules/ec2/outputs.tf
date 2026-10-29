output "public_ip" {
  value       = aws_instance.server.public_ip
  description = "Public IP address of the EC2 instance"
}