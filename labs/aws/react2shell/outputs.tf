output "webapp_url" {
  description = "Vulnerable Next.js application URL"
  value       = "http://${aws_instance.webapp.public_ip}:3000"
}

output "webapp_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.webapp.public_ip
}

output "instance_role" {
  description = "IAM role attached to instance"
  value       = aws_iam_role.webapp_role.name
}

output "s3_bucket" {
  description = "S3 bucket containing sensitive data"
  value       = aws_s3_bucket.app_data.id
}

output "secrets_arn" {
  description = "Secrets Manager secret ARN"
  value       = aws_secretsmanager_secret.app_config.arn
}

output "ssm_parameter" {
  description = "SSM parameter with resource hints"
  value       = aws_ssm_parameter.hint.name
}

output "attack_entry" {
  description = "Initial attack vector"
  value       = "POST to http://${aws_instance.webapp.public_ip}:3000 with RSC Flight payload"
}

output "cve_reference" {
  description = "CVE identifier"
  value       = "CVE-2025-55182 (React2Shell)"
}