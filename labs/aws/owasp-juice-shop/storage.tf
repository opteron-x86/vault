resource "random_password" "db_password" {
  length  = 24
  special = true
}

resource "random_password" "admin_token" {
  length  = 32
  special = false
}

resource "aws_s3_bucket" "juice_data" {
  bucket        = "${var.lab_prefix}-data-${random_string.suffix.result}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name               = "${var.lab_prefix}-data"
    DataClassification = "Internal"
  })
}

resource "aws_s3_bucket_versioning" "juice_data" {
  bucket = aws_s3_bucket.juice_data.id
  
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "juice_data" {
  bucket = aws_s3_bucket.juice_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "customer_orders" {
  bucket  = aws_s3_bucket.juice_data.id
  key     = "orders/customer_orders.json"
  content = jsonencode({
    orders = [
      {
        order_id     = "ORD-1001"
        customer     = "john.smith@example.com"
        total        = 45.99
        credit_card  = "4532-****-****-1234"
        status       = "delivered"
      },
      {
        order_id     = "ORD-1002"
        customer     = "sarah.jones@example.com"
        total        = 89.50
        credit_card  = "5123-****-****-5678"
        status       = "processing"
      },
      {
        order_id     = "FLAG-ORDER"
        customer     = "admin@juice-sh.op"
        total        = 99999.99
        credit_card  = "0000-0000-0000-0000"
        status       = "FLAG{juice_shop_s3_exfiltration_complete}"
      }
    ]
  })
}

resource "aws_s3_object" "backup_data" {
  bucket  = aws_s3_bucket.juice_data.id
  key     = "backups/db_backup_latest.sql"
  content = <<-EOT
-- Juice Shop Database Backup
-- Generated: 2025-11-18

-- Users table
INSERT INTO users VALUES (1, 'admin@juice-sh.op', 'admin123', 'admin');
INSERT INTO users VALUES (2, 'jim@juice-sh.op', 'ncc-1701', 'customer');
INSERT INTO users VALUES (3, 'bender@juice-sh.op', 'OhG0dPlease1nsertLiquor!', 'customer');

-- Payment methods
INSERT INTO cards VALUES (1, '4532-****-****-1234', 'John Smith', 1);
INSERT INTO cards VALUES (2, '5123-****-****-5678', 'Sarah Jones', 2);

-- Sensitive config
UPDATE config SET value = 'FLAG{sql_backup_discovered}' WHERE key = 'secret_flag';
EOT
}

resource "aws_secretsmanager_secret" "juice_config" {
  name                    = "${var.lab_prefix}-config-${random_string.suffix.result}"
  recovery_window_in_days = 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "juice_config" {
  secret_id = aws_secretsmanager_secret.juice_config.id
  secret_string = jsonencode({
    db_host      = "localhost"
    db_port      = 5432
    db_name      = "juiceshop"
    db_user      = "juiceadmin"
    db_password  = random_password.db_password.result
    admin_token  = random_password.admin_token.result
    s3_bucket    = aws_s3_bucket.juice_data.id
    api_key      = "juice_api_key_${random_string.suffix.result}"
    jwt_secret   = "juice_jwt_secret_${random_string.suffix.result}"
  })
}

resource "aws_ssm_parameter" "juice_bucket_hint" {
  name  = "/${var.lab_prefix}/config/data_bucket"
  type  = "String"
  value = aws_s3_bucket.juice_data.id
  
  tags = merge(local.common_tags, {
    Purpose = "S3 bucket for application data"
  })
}

resource "aws_ssm_parameter" "juice_secrets_hint" {
  name  = "/${var.lab_prefix}/config/secrets_arn"
  type  = "String"
  value = aws_secretsmanager_secret.juice_config.arn
  
  tags = merge(local.common_tags, {
    Purpose = "Secrets Manager configuration"
  })
}