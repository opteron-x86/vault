output "trail_arn" {
  description = "CloudTrail ARN"
  value       = local.use_shared ? data.aws_cloudtrail.shared[0].arn : aws_cloudtrail.main[0].arn
}

output "trail_name" {
  description = "CloudTrail name"
  value       = local.use_shared ? data.aws_cloudtrail.shared[0].name : aws_cloudtrail.main[0].name
}

output "s3_bucket_name" {
  description = "S3 bucket containing CloudTrail logs"
  value       = local.use_shared ? var.shared_cloudtrail_bucket : aws_s3_bucket.logs[0].id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = local.use_shared ? "arn:aws-us-gov:s3:::${var.shared_cloudtrail_bucket}" : aws_s3_bucket.logs[0].arn
}

output "log_query_commands" {
  description = "Commands for querying CloudTrail logs"
  value = {
    list_logs = "aws s3 ls s3://${local.use_shared ? var.shared_cloudtrail_bucket : aws_s3_bucket.logs[0].id}/AWSLogs/"
    download  = "aws s3 cp s3://${local.use_shared ? var.shared_cloudtrail_bucket : aws_s3_bucket.logs[0].id}/AWSLogs/ . --recursive"
    query     = "gunzip *.json.gz && jq '.Records[] | select(.eventName == \"EVENT_NAME\")' *.json"
  }
}