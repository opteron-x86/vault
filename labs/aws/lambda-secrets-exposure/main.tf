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
  }
  backend "local" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = var.default_tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  lab_name = "${var.lab_prefix}-lambda-secrets"
  common_tags = merge(var.default_tags, {
    Lab          = "lambda-secrets-exposure"
    Difficulty   = "3"
    AutoShutdown = "true"
  })
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${local.lab_name}-lambda-role"

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

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${local.lab_name}-secrets-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws-us-gov:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.lab_name}-db-creds-${random_string.suffix.result}"
  description             = "Database credentials for production RDS instance"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = "Pr0d_DB_P@ssw0rd_${random_string.suffix.result}"
    engine   = "postgres"
    host     = aws_db_instance.target_db.address
    port     = 5432
    dbname   = "production"
  })
}

resource "aws_lambda_function" "api_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.lab_name}-api-handler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30

  environment {
    variables = {
      SECRET_ARN       = aws_secretsmanager_secret.db_credentials.arn
      DB_HOST          = aws_db_instance.target_db.address
      DB_NAME          = "production"
      API_KEY          = "sk_live_${random_string.suffix.result}_insecure"
      DEBUG_MODE       = "true"
      INTERNAL_API_URL = "https://internal.example.com/api"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-function"
  })
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "${local.lab_name}-api"
  protocol_type = "HTTP"

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-api-gateway"
  })
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.lambda_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /status"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_security_group" "rds" {
  name        = "${local.lab_name}-rds-sg"
  description = "Allow PostgreSQL access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL from anywhere (intentionally insecure for lab)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-rds-sg"
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.lab_name}-db-subnet"
  subnet_ids = module.vpc.public_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-db-subnet-group"
  })
}

resource "aws_db_instance" "target_db" {
  identifier           = "${local.lab_name}-db-${random_string.suffix.result}"
  engine               = "postgres"
  engine_version       = "15.5"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  db_name              = "production"
  username             = "admin"
  password             = "Pr0d_DB_P@ssw0rd_${random_string.suffix.result}"
  skip_final_snapshot  = true
  publicly_accessible  = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-postgres-db"
  })
}

resource "null_resource" "init_database" {
  depends_on = [aws_db_instance.target_db]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 60
      PGPASSWORD='Pr0d_DB_P@ssw0rd_${random_string.suffix.result}' psql -h ${aws_db_instance.target_db.address} -U admin -d production -c "
        CREATE TABLE IF NOT EXISTS customer_records (
          id SERIAL PRIMARY KEY,
          customer_name VARCHAR(255),
          email VARCHAR(255),
          api_key VARCHAR(255),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        INSERT INTO customer_records (customer_name, email, api_key) VALUES
          ('Acme Corporation', 'admin@acme.corp', 'ak_acme_${random_string.suffix.result}'),
          ('TechStart Inc', 'info@techstart.io', 'ak_tech_${random_string.suffix.result}'),
          ('Global Industries', 'contact@global.com', 'FLAG{lambda_env_vars_to_secrets_manager_to_rds_${random_string.suffix.result}}');
      "
    EOT
  }
}

module "vpc" {
  source = "../modules/lab-vpc"

  name_prefix         = local.lab_name
  vpc_cidr            = "10.0.0.0/16"
  az_count            = 2
  aws_region          = var.aws_region
  allowed_ssh_cidrs   = var.allowed_source_ips
  create_ssh_sg       = false
  create_web_sg       = false
  enable_s3_endpoint  = false
  tags                = local.common_tags
}