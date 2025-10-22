# Outputs
output "webapp_url" {
  description = "URL of the vulnerable web application"
  value       = "http://${aws_instance.webapp.public_ip}:8080"
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${aws_instance.webapp.public_ip}"
}

output "target_bucket" {
  description = "S3 bucket containing sensitive data"
  value       = aws_s3_bucket.sensitive_data.id
}

output "instance_id" {
  description = "EC2 instance ID for debugging"
  value       = aws_instance.webapp.id
}

output "attack_chain_hint" {
  description = "Starting point for the lab"
  value       = "Begin by exploring the URL Inspector service on port 8080"
}