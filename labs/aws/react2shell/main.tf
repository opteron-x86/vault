# React2Shell Lab (CVE-2025-55182)
# Attack Chain: RSC Deserialization RCE → Credential Discovery → IAM Enumeration → S3 Exfiltration
# Difficulty: 4
# Estimated Time: 45-60 minutes

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

resource "random_password" "api_key" {
  length  = 32
  special = false
}

resource "random_password" "db_password" {
  length  = 20
  special = true
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

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

module "vpc" {
  source = "../modules/lab-vpc"

  name_prefix       = var.lab_prefix
  vpc_cidr          = "192.168.0.0/24"
  aws_region        = var.aws_region
  allowed_ssh_cidrs = var.allowed_source_ips

  create_web_sg     = true
  allowed_web_cidrs = var.allowed_source_ips
  web_ports         = [3000]

  tags = local.common_tags
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "app_role" {
  name = "${var.lab_prefix}-app-role-${random_string.suffix.result}"

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

resource "aws_iam_role_policy" "app_permissions" {
  name = "${var.lab_prefix}-app-policy"
  role = aws_iam_role.app_role.id

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
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.app_config.arn
      },
      {
        Sid    = "SSMRead"
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

resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.lab_prefix}-profile-${random_string.suffix.result}"
  role = aws_iam_role.app_role.name
}

# S3 Bucket with sensitive data
resource "aws_s3_bucket" "app_data" {
  bucket        = "${var.lab_prefix}-data-${random_string.suffix.result}"
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
  key     = "exports/customers.csv"
  content = <<-CSV
id,name,email,plan,card_last_four
1001,Marcus Chen,m.chen@techcorp.io,enterprise,4532
1002,Sarah Williams,s.williams@finserv.com,professional,8876
1003,James Rodriguez,j.rod@startup.dev,enterprise,2341
1004,Emily Zhang,e.zhang@bigcorp.net,enterprise,9902
FLAG{s3_customer_data_exfiltrated}
CSV
  tags    = local.common_tags
}

resource "aws_s3_object" "api_keys" {
  bucket  = aws_s3_bucket.app_data.id
  key     = "config/api-keys.json"
  content = jsonencode({
    stripe_live    = "sk_live_${random_password.api_key.result}"
    sendgrid       = "SG.${random_string.suffix.result}.fake"
    internal_token = "FLAG{sensitive_api_keys_exposed}"
  })
  tags = local.common_tags
}

# Secrets Manager
resource "aws_secretsmanager_secret" "app_config" {
  name                    = "${var.lab_prefix}/app-config-${random_string.suffix.result}"
  recovery_window_in_days = 0
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    database_url   = "postgresql://app:${random_password.db_password.result}@db.internal:5432/production"
    jwt_secret     = random_password.api_key.result
    admin_api_key  = "FLAG{secrets_manager_accessed}"
    encryption_key = base64encode(random_password.api_key.result)
  })
}

# SSM Parameter with hints
resource "aws_ssm_parameter" "app_hint" {
  name  = "/${var.lab_prefix}/deployment-notes"
  type  = "String"
  value = "Production deployment uses Next.js 16.0.6 with App Router. Customer data synced to S3 bucket: ${aws_s3_bucket.app_data.id}"
  tags  = local.common_tags
}

# EC2 Instance running vulnerable Next.js
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [module.vpc.ssh_security_group_id, module.vpc.web_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.app_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    s3_bucket      = aws_s3_bucket.app_data.id
    secrets_arn    = aws_secretsmanager_secret.app_config.arn
    api_key        = random_password.api_key.result
    shutdown_hours = var.auto_shutdown_hours
  }))

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-server"
  })
}