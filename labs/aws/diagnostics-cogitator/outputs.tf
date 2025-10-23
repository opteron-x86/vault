output "webapp_url" {
  description = "URL of the vulnerable web application"
  value       = "http://${aws_instance.cogitator_vm.public_ip}:8081"
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${aws_instance.cogitator_vm.public_ip}"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.cogitator_vm.id
}

output "s3_bucket" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.data_bucket.id
}

output "ebs_volume_id" {
  description = "Detached EBS volume ID"
  value       = aws_ebs_volume.target_volume.id
}

output "dynamodb_table" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.data_repository.name
}

output "primary_role_arn" {
  description = "Primary EC2 instance role ARN"
  value       = aws_iam_role.cogitator_ec2_role.arn
}

output "secondary_role_arn" {
  description = "Secondary assumable role ARN"
  value       = aws_iam_role.logis_role.arn
}

output "attack_hint" {
  description = "Starting point for exploitation"
  value       = "Begin by exploring the diagnostic web application on port 8081"
}