output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.lambda_api.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.api_handler.function_name
}

output "secret_arn" {
  description = "Secrets Manager secret ARN"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.target_db.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.target_db.db_name
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.target_db.port
}

output "attack_start" {
  description = "Initial enumeration target"
  value       = "${aws_apigatewayv2_api.lambda_api.api_endpoint}/status"
}

output "lab_instructions" {
  description = "Quick start instructions"
  sensitive = true
  value       = <<-EOT
    
    === Lambda Function Secrets Exposure Lab ===
    
    1. Enumerate API Gateway endpoints:
       curl ${aws_apigatewayv2_api.lambda_api.api_endpoint}/status
       curl ${aws_apigatewayv2_api.lambda_api.api_endpoint}/health
    
    2. Look for exposed configuration in debug mode
    
    3. Extract Secrets Manager ARN and retrieve credentials
    
    4. Connect to RDS database using recovered credentials
    
    Attack Chain: API Gateway → Lambda env vars → Secrets Manager → RDS credentials → Database access
    
    EOT
}

output "attack_chain_overview" {
  description = "High-level attack path"
  value       = "API Gateway → Lambda Environment Variables → Secrets Manager ARN → Database Credentials → RDS Access → Flag Extraction"
}