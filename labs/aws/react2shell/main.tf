# React2Shell CVE-2025-55182 Exploitation Lab
# Attack Chain: RSC Deserialization RCE → IMDS Credential Extraction → S3/Secrets Manager Exfiltration
# Difficulty: 5
# Estimated Time: 60-90 minutes

locals {
  common_tags = {
    Environment  = "lab"
    Destroyable  = "true"
    Scenario     = "react2shell"
    AutoShutdown = "4hours"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_password" "flag_secret" {
  length  = 32
  special = false
}

resource "random_password" "api_key" {
  length  = 40
  special = false
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../modules/lab-vpc"

  name_prefix       = var.lab_prefix
  vpc_cidr          = "10.0.0.0/16"
  aws_region        = var.aws_region
  allowed_ssh_cidrs = var.allowed_source_ips
  
  create_web_sg     = true
  allowed_web_cidrs = var.allowed_source_ips
  web_ports         = [3000]
  
  tags = local.common_tags
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "webapp_role" {
  name = "${var.lab_prefix}-webapp-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "webapp_permissions" {
  name = "${var.lab_prefix}-webapp-policy"
  role = aws_iam_role.webapp_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
      },
      {
        Sid    = "SecretsAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.app_config.arn
      },
      {
        Sid    = "SSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.lab_prefix}/*"
      }
    ]
  })
}

data "aws_partition" "current" {}

resource "aws_iam_instance_profile" "webapp" {
  name = "${var.lab_prefix}-webapp-profile-${random_string.suffix.result}"
  role = aws_iam_role.webapp_role.name
}

# S3 Bucket for Application Data
resource "aws_s3_bucket" "app_data" {
  bucket        = "${var.lab_prefix}-appdata-${random_string.suffix.result}"
  force_destroy = true
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "customer_data" {
  bucket  = aws_s3_bucket.app_data.id
  key     = "exports/customer_database.csv"
  content = <<-EOT
    customer_id,name,email,ssn,credit_card
    1001,John Smith,john.smith@example.com,123-45-6789,4532-XXXX-XXXX-1234
    1002,Jane Doe,jane.doe@example.com,987-65-4321,5412-XXXX-XXXX-5678
    1003,Bob Wilson,bob.wilson@example.com,456-78-9012,6011-XXXX-XXXX-9012
  EOT
}

resource "aws_s3_object" "flag" {
  bucket  = aws_s3_bucket.app_data.id
  key     = "internal/flag.txt"
  content = "FLAG{react2shell_s3_exfiltration_${random_string.suffix.result}}"
}

resource "aws_s3_object" "api_keys" {
  bucket  = aws_s3_bucket.app_data.id
  key     = "config/api_keys.json"
  content = jsonencode({
    stripe_secret_key     = "sk_live_${random_password.api_key.result}"
    sendgrid_api_key      = "SG.${random_password.api_key.result}"
    database_connection   = "postgresql://admin:${random_password.flag_secret.result}@db.internal:5432/production"
  })
}

# Secrets Manager
resource "aws_secretsmanager_secret" "app_config" {
  name                    = "${var.lab_prefix}-app-config-${random_string.suffix.result}"
  recovery_window_in_days = 0
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    admin_password = random_password.flag_secret.result
    jwt_secret     = "FLAG{react2shell_secrets_manager_${random_string.suffix.result}}"
    db_password    = random_password.api_key.result
  })
}

# SSM Parameters
resource "aws_ssm_parameter" "hint" {
  name  = "/${var.lab_prefix}/webapp/config"
  type  = "String"
  value = jsonencode({
    s3_bucket    = aws_s3_bucket.app_data.id
    secrets_arn  = aws_secretsmanager_secret.app_config.arn
    hint         = "Check /exports/ and /internal/ paths"
  })
  tags = local.common_tags
}

# EC2 Instance
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "webapp" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [module.vpc.ssh_sg_id, module.vpc.web_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.webapp.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"  # IMDSv1 enabled for lab exploitation
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    nextjs_version = "16.0.6"
  }))

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-react2shell-webapp"
  })
}