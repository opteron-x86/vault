output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/healthcheck"
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.vulnerable_api.function_name
}

output "secret_name" {
  description = "Secrets Manager secret name"
  value       = aws_secretsmanager_secret.db_creds.name
}

output "s3_bucket_name" {
  description = "S3 bucket containing sensitive data"
  value       = aws_s3_bucket.sensitive_data.id
}

output "s3_data_path" {
  description = "Path to sensitive data in S3"
  value       = "s3://${aws_s3_bucket.sensitive_data.id}/confidential/customer_data.txt"
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_exec.arn
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "test_command" {
  description = "Test command to verify API is working"
  value       = <<-EOT
    curl -X POST ${aws_apigatewayv2_api.http_api.api_endpoint}/healthcheck \
      -H "Content-Type: application/json" \
      -d '{"hostname": "example.com"}'
  EOT
}

output "attack_chain_hint" {
  description = "Starting point for the lab"
  value       = "Begin by testing the health check API. Look for command injection vulnerabilities."
}