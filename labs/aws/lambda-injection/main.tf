# Lambda Code Injection Lab
# Attack Chain: API Gateway → Lambda Command Injection → Environment Credentials → Secrets Manager → S3 Exfiltration
# Difficulty: Medium
# Estimated Time: 60-90 minutes

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
  backend "local" {}
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Environment  = "lab"
    Destroyable  = "true"
    Scenario     = "lambda-code-injection"
    AutoShutdown = "4hours"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

data "aws_caller_identity" "current" {}

# S3 bucket with sensitive data
resource "aws_s3_bucket" "sensitive_data" {
  bucket = "${var.lab_prefix}-sensitive-data-${random_string.suffix.result}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "sensitive_data" {
  bucket                  = aws_s3_bucket.sensitive_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "flag" {
  bucket  = aws_s3_bucket.sensitive_data.id
  key     = "confidential/customer_data.txt"
  content = <<-EOT
    ======================================
    CONFIDENTIAL CUSTOMER DATABASE
    ======================================
    
    Customer ID: C-${random_string.suffix.result}
    Name: John Doe
    SSN: 123-45-6789
    Credit Card: 4532-****-****-7890
    Account Balance: $1,250,000
    
    Customer ID: C-${random_string.suffix.result}-2
    Name: Jane Smith
    SSN: 987-65-4321
    Credit Card: 5412-****-****-3456
    Account Balance: $890,500
    
    ======================================
    FLAG: LAMBDA_INJECTION_COMPLETE
    ======================================
  EOT
  tags    = local.common_tags
}

# Secrets Manager secret
resource "aws_secretsmanager_secret" "db_creds" {
  name                    = "${var.lab_prefix}-database-credentials-${random_string.suffix.result}"
  description             = "Database credentials for production"
  recovery_window_in_days = 0
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    username     = "admin"
    password     = "SuperSecure${random_string.suffix.result}!"
    database     = "customers"
    host         = "prod-db.internal.company.com"
    port         = 5432
    s3_bucket    = aws_s3_bucket.sensitive_data.id
    s3_data_path = "confidential/customer_data.txt"
  })
}

# Lambda IAM role
resource "aws_iam_role" "lambda_exec" {
  name = "${var.lab_prefix}-lambda-exec-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.lab_prefix}-lambda-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws-us-gov:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_creds.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sensitive_data.arn,
          "${aws_s3_bucket.sensitive_data.arn}/*"
        ]
      }
    ]
  })
}

# Lambda function with vulnerable code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<-EOT
import json
import os
import subprocess
import boto3

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))
        hostname = body.get('hostname', 'example.com')
        
        # VULNERABILITY: Command injection via subprocess
        # Intended to ping a hostname for health checks
        result = subprocess.run(
            f"ping -c 1 {hostname}",
            shell=True,
            capture_output=True,
            text=True,
            timeout=5
        )
        
        response = {
            'status': 'success',
            'hostname': hostname,
            'ping_result': result.stdout,
            'exit_code': result.returncode
        }
        
        return {
            'statusCode': 200,
            'body': json.dumps(response),
            'headers': {
                'Content-Type': 'application/json',
                'X-Service-Version': '1.0'
            }
        }
        
    except subprocess.TimeoutExpired:
        return {
            'statusCode': 408,
            'body': json.dumps({'error': 'Request timeout'}),
            'headers': {'Content-Type': 'application/json'}
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': {'Content-Type': 'application/json'}
        }
EOT
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "vulnerable_api" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.lab_prefix}-health-checker-${random_string.suffix.result}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.13"

  timeout          = 10

  environment {
    variables = {
      DB_SECRET_NAME = aws_secretsmanager_secret.db_creds.name
      SERVICE_NAME   = "health-checker"
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.vulnerable_api.function_name}"
  retention_in_days = 1
  tags              = local.common_tags
}

# API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.lab_prefix}-api-${random_string.suffix.result}"
  protocol_type = "HTTP"
  description   = "Health check API for internal services"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.vulnerable_api.invoke_arn
}

resource "aws_apigatewayv2_route" "post_healthcheck" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /healthcheck"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "get_healthcheck" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /healthcheck"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vulnerable_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}