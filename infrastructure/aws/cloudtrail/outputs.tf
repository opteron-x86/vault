output "trail_name" {
  description = "CloudTrail trail name (use in common-aws.tfvars)"
  value       = aws_cloudtrail.vault_master.name
}

output "trail_arn" {
  description = "CloudTrail trail ARN"
  value       = aws_cloudtrail.vault_master.arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for CloudTrail logs (use in common-aws.tfvars)"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.cloudtrail_logs.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name (if enabled)"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.cloudtrail[0].name : null
}

output "configuration_snippet" {
  description = "Add this to your config/common-aws.tfvars"
  value       = <<-EOT
    
    # ===================================
    # Shared CloudTrail Configuration
    # ===================================
    shared_cloudtrail_name   = "${aws_cloudtrail.vault_master.name}"
    shared_cloudtrail_bucket = "${aws_s3_bucket.cloudtrail_logs.id}"
    use_shared_cloudtrail    = true
    
  EOT
}