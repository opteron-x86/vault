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

locals {
  common_tags = {
    Environment  = "development"
    Destroyable  = "true"
    Application  = "url-inspector"
    AutoShutdown = "4hours"
  }
  target_ami = "ami-0320614f158c301d8" # AWS GovCloud Amazon Linux 2023
  instance_type = var.instance_type
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
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
  web_ports         = [8080]
  
  tags = local.common_tags
}

resource "aws_iam_role" "webapp_instance" {
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

resource "aws_iam_role_policy" "webapp_logging" {
  name = "${var.lab_prefix}-logging-policy"
  role = aws_iam_role.webapp_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws-us-gov:logs:${var.aws_region}:*:*"
      },
      {
        Sid    = "S3LogAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws-us-gov:s3:::${var.lab_prefix}-*/*"
      },
      {
        Sid      = "S3ListBuckets"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws-us-gov:s3:::${var.lab_prefix}-*"
      },
      {
        Sid    = "SSMConfigAccess"
        Effect = "Allow"
        Action = [
          "ssm:DescribeParameters",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      },
      {
        Sid      = "AssumeRoleAccess"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws-us-gov:iam::*:role/${var.lab_prefix}-*"
      }
    ]
  })
}

resource "aws_iam_role" "data_processor" {
  name = "${var.lab_prefix}-data-processor-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws-us-gov:iam::${data.aws_caller_identity.current.account_id}:root"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "data_processor_s3" {
  name = "${var.lab_prefix}-data-access"
  role = aws_iam_role.data_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.sensitive_data.arn,
        "${aws_s3_bucket.sensitive_data.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "webapp" {
  name = "${var.lab_prefix}-webapp-profile-${random_string.suffix.result}"
  role = aws_iam_role.webapp_instance.name
}

resource "aws_security_group" "webapp_custom" {
  name        = "${var.lab_prefix}-webapp-custom"
  description = "Additional webapp security rules"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-webapp-custom"
  })
}

resource "aws_instance" "webapp" {
  ami                    = local.target_ami
  instance_type          = local.instance_type
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [
    module.vpc.ssh_security_group_id,
    module.vpc.web_security_group_id
  ]
  iam_instance_profile = aws_iam_instance_profile.webapp.name
  key_name             = var.ssh_key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(<<-EOT
#!/bin/bash
dnf update -y
dnf install -y python3 python3-pip at

pip3 install flask requests boto3

cat > /home/ec2-user/app.py << 'PYAPP'
from flask import Flask, request, jsonify
import requests
import boto3

app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <h1>URL Inspector Service</h1>
    <p>Internal tool for checking URL accessibility</p>
    <form action="/check" method="get">
        <input type="text" name="url" placeholder="Enter URL to check" size="50">
        <input type="submit" value="Check URL">
    </form>
    '''

@app.route('/check')
def check_url():
    url = request.args.get('url')
    if not url:
        return jsonify({'error': 'No URL provided'}), 400
    
    try:
        response = requests.get(url, timeout=5)
        return jsonify({
            'url': url,
            'status_code': response.status_code,
            'content_preview': response.text[:2000]
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    return 'OK'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PYAPP

cat > /etc/systemd/system/webapp.service << 'SYSD'
[Unit]
Description=URL Inspector Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/python3 /home/ec2-user/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SYSD

systemctl daemon-reload
systemctl enable webapp
systemctl start webapp

echo "Configuration note: Data processor role ARN: ${aws_iam_role.data_processor.arn}" >> /var/log/application-setup.log

systemctl enable atd
systemctl start atd
echo "sudo shutdown -h +240" | at now
EOT
)

  tags = merge(local.common_tags, {
    Name         = "${var.lab_prefix}-webapp"
    AutoShutdown = "4hours"
  })
  
  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_s3_bucket" "sensitive_data" {
  bucket        = "${var.lab_prefix}-customer-data-${random_string.suffix.result}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name               = "${var.lab_prefix}-customer-data"
    DataClassification = "Internal"
  })
}

resource "aws_s3_bucket_versioning" "sensitive_data" {
  bucket = aws_s3_bucket.sensitive_data.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "sensitive_data" {
  bucket = aws_s3_bucket.sensitive_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "customer_data" {
  bucket  = aws_s3_bucket.sensitive_data.id
  key     = "customers/customer_database.csv"
  content = <<-EOT
customer_id,name,email,credit_card_last4,account_balance
1001,John Smith,jsmith@example.com,4532,15430.50
1002,Sarah Johnson,sjohnson@example.com,8921,8750.00
1003,Michael Brown,mbrown@example.com,3467,22100.75
1004,Emma Wilson,ewilson@example.com,9823,5600.25
1005,FLAG{metadata_service_to_role_escalation_complete},flag@example.com,0000,999999.99
EOT
}

resource "aws_s3_object" "api_keys" {
  bucket  = aws_s3_bucket.sensitive_data.id
  key     = "config/api_keys.json"
  content = jsonencode({
    production = {
      stripe_key  = "sk_live_simulated_key_do_not_use"
      db_password = "SuperSecretPassword123!"
      api_endpoint = "https://internal-api.example.com"
    }
  })
}

resource "aws_ssm_parameter" "data_role_hint" {
  name  = "/${var.lab_prefix}/config/data_processor_role"
  type  = "String"
  value = aws_iam_role.data_processor.arn
  
  tags = merge(local.common_tags, {
    Purpose = "Batch processing role for ETL jobs"
  })
}

module "audit_logging" {
  source = "../modules/audit-logging"
  
  name_prefix = var.lab_prefix
  suffix      = random_string.suffix.result
  
  data_resources = [{
    type   = "AWS::S3::Object"
    values = ["${aws_s3_bucket.sensitive_data.arn}/*"]
  }]
  
  tags = local.common_tags
}