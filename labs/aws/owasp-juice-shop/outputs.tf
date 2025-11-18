output "juice_shop_url" {
  description = "OWASP Juice Shop application URL"
  value       = "http://${aws_instance.juice_shop.public_ip}:3000"
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${aws_instance.juice_shop.public_ip}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.juice_shop.id
}

output "instance_role" {
  description = "IAM role attached to the instance"
  value       = aws_iam_role.juice_shop_instance.name
}

output "data_bucket" {
  description = "S3 bucket containing application data"
  value       = aws_s3_bucket.juice_data.id
}

output "secrets_arn" {
  description = "Secrets Manager ARN"
  value       = aws_secretsmanager_secret.juice_config.arn
}

output "admin_token" {
  description = "Admin API token"
  value       = random_password.admin_token.result
  sensitive   = true
}

output "attack_chain_hint" {
  description = "Starting point for the lab"
  value       = "Access Juice Shop on port 3000 and explore the application for vulnerabilities"
}