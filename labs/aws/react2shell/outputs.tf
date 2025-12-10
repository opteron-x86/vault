output "app_url" {
  description = "Application URL"
  value       = "http://${aws_instance.app_server.public_ip}:3000"
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = var.ssh_key_name != "" ? "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${aws_instance.app_server.public_ip}" : "SSH key not configured"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}

output "instance_role" {
  description = "Instance IAM role"
  value       = aws_iam_role.app_role.name
}

output "s3_bucket" {
  description = "Application data bucket"
  value       = aws_s3_bucket.app_data.id
}

output "secrets_arn" {
  description = "Secrets Manager ARN"
  value       = aws_secretsmanager_secret.app_config.arn
}

output "attack_surface" {
  description = "Initial attack entry point"
  value       = "Next.js 16.0.6 application with App Router at http://${aws_instance.app_server.public_ip}:3000"
}

output "attack_chain" {
  description = "Attack path overview"
  value       = "React2Shell RCE → Environment Discovery → Metadata Credentials → S3 Exfiltration"
}