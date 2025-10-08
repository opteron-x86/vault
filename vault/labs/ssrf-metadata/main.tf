# SSRF to Data Exfiltration Lab
# Attack Chain: Web App SSRF → IMDSv1 → Role Credentials → S3 Access
# Difficulty: Easy-Medium
# Estimated Time: 45-60 minutes

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
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# IAM resources
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

# Application logs policy - appears legitimate
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
        # Overly permissive for "debugging purposes"
        Resource = "arn:aws-us-gov:s3:::${var.lab_prefix}-*/*"
      },
      {
        Sid    = "S3ListBuckets"  
        Effect = "Allow"
        Action = "s3:ListBucket"
        # Developer convenience - list any lab bucket
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
        # Config parameters for application
        Resource = "*"
      },
      {
        Sid    = "AssumeRoleAccess"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        # Developer left this too permissive for debugging
        Resource = "arn:aws-us-gov:iam::*:role/${var.lab_prefix}-*"
      }
    ]
  })
}

# Additional role for privilege escalation path
resource "aws_iam_role" "data_processor" {
  name = "${var.lab_prefix}-data-processor-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        # Misconfigured - allows any principal in the account
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

# Network resources
resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-public-subnet"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "webapp" {
  name        = "${var.lab_prefix}-webapp-sg"
  description = "Security group for vulnerable web application"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "HTTP from allowed IPs"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_source_ips
  }

  ingress {
    description = "SSH for management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_source_ips
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-webapp-sg"
  })
}

# Compute resources
resource "aws_instance" "webapp" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = local.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.webapp.id]
  iam_instance_profile   = aws_iam_instance_profile.webapp.name
  key_name               = var.ssh_key_name

  # Intentionally using IMDSv1 for metadata service exploitation
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"  # IMDSv1 enabled
    http_put_response_hop_limit = 2          # Allows container access
  }

  user_data = base64encode(<<-EOT
#!/bin/bash
dnf update -y
dnf install -y python3 python3-pip at

# Install Python packages
pip3 install flask requests boto3

# Create vulnerable web app with SSRF
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
        # Vulnerable SSRF - no input validation
        response = requests.get(url, timeout=5)
        return jsonify({
            'url': url,
            'status_code': response.status_code,
            'content_preview': response.text[:2000]  # Increased for full token
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    return 'OK'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PYAPP

# Create systemd service
cat > /etc/systemd/system/webapp.service << 'SYSD'
[Unit]
Description=Vulnerable Web Application
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

# Plant hint in logs for discovery
echo "Configuration note: Data processor role ARN: ${aws_iam_role.data_processor.arn}" >> /var/log/application-setup.log

# Enable at daemon for auto-shutdown
systemctl enable atd
systemctl start atd

# Auto-shutdown after 4 hours for cost control
echo "sudo shutdown -h +240" | at now
EOT
)

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-webapp"
    AutoShutdown = "4hours"
  })
  
  # Prevent accidental long-running instances
  lifecycle {
    ignore_changes = [ami]
  }
}

# Storage resources
resource "aws_s3_bucket" "sensitive_data" {
  bucket        = "${var.lab_prefix}-sensitive-data-${random_string.suffix.result}"
  force_destroy = true  # Ensures clean terraform destroy

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-sensitive-data"
    DataClassification = "Internal"
  })
}

resource "aws_s3_bucket_versioning" "sensitive_data" {
  bucket = aws_s3_bucket.sensitive_data.id
  versioning_configuration {
    status = "Disabled"
  }
}

# Block public access but allow authenticated AWS access
resource "aws_s3_bucket_public_access_block" "sensitive_data" {
  bucket = aws_s3_bucket.sensitive_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Plant target data
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
      stripe_key = "sk_live_simulated_key_do_not_use"
      db_password = "SuperSecretPassword123!"
      api_endpoint = "https://internal-api.example.com"
    }
  })
}

# Parameter Store for additional credential discovery
resource "aws_ssm_parameter" "data_role_hint" {
  name  = "/${var.lab_prefix}/config/data_processor_role"
  type  = "String"
  value = aws_iam_role.data_processor.arn
  
  tags = merge(local.common_tags, {
    Purpose = "Batch processing role for ETL jobs"
  })
}
