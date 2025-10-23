# Cogitator Exploit Lab
# Attack Chain: Command Injection → Privesc → EBS Discovery → IAM Escalation → Data Exfiltration
# Difficulty: Medium
# Estimated Time: 90-120 minutes

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

locals {
  common_tags = {
    Environment  = "lab"
    Destroyable  = "true"
    Scenario     = "cogitator-exploit"
    AutoShutdown = "4hours"
  }
  
  instance_type = "t3.micro"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC Module
module "vpc" {
  source = "../modules/lab-vpc"

  name_prefix       = var.lab_prefix
  vpc_cidr          = "10.0.0.0/16"
  aws_region        = var.aws_region
  allowed_ssh_cidrs = var.allowed_source_ips
  
  create_web_sg     = true
  allowed_web_cidrs = var.allowed_source_ips
  web_ports         = [8081]
  
  tags = local.common_tags
}

# IAM Role for EC2 Instance (Primary)
resource "aws_iam_role" "cogitator_ec2_role" {
  name = "${var.lab_prefix}-ec2-role-${random_string.suffix.result}"

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

resource "aws_iam_role_policy" "cogitator_permissions" {
  name = "${var.lab_prefix}-base-policy"
  role = aws_iam_role.cogitator_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      },
      {
        Sid    = "EBSVolumeAccess"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Sid      = "AssumeSecondaryRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.logis_role.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cogitator_profile" {
  name = "${var.lab_prefix}-profile-${random_string.suffix.result}"
  role = aws_iam_role.cogitator_ec2_role.name
}

# Secondary IAM Role (Assumable)
resource "aws_iam_role" "logis_role" {
  name = "${var.lab_prefix}-logis-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.cogitator_ec2_role.arn
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "logis_permissions" {
  name = "${var.lab_prefix}-logis-policy"
  role = aws_iam_role.logis_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMPolicyManagement"
        Effect = "Allow"
        Action = [
          "iam:ListAttachedRolePolicies",
          "iam:GetPolicy",
          "iam:ListPolicies",
          "iam:GetPolicyVersion",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:CreatePolicy",
          "iam:AttachRolePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# S3 Bucket
resource "aws_s3_bucket" "data_bucket" {
  bucket        = "${var.lab_prefix}-data-${random_string.suffix.result}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-data"
  })
}

resource "aws_s3_bucket_versioning" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload Flask app templates to S3
resource "aws_s3_object" "templates" {
  for_each = fileset("${path.module}/templates", "*.html")

  bucket  = aws_s3_bucket.data_bucket.id
  key     = each.value
  source  = "${path.module}/templates/${each.value}"
  etag    = filemd5("${path.module}/templates/${each.value}")
}

resource "aws_s3_object" "flag1" {
  bucket  = aws_s3_bucket.data_bucket.id
  key     = "config/system-manifest.txt"
  content = <<-EOT
=== COGITATOR SYSTEM MANIFEST ===
Instance ID: PRIME-9X-${var.lab_prefix}
Operating Protocols: ACTIVE
Security Classification: MAGENTA

System Components:
- Core Processing Unit: Ubuntu 22.04 LTS
- Network Interface: Flask Diagnostic Service
- Storage Array: EBS Volume Configuration
- Authentication: IAM Role-Based Access

FLAG{initial_access_s3_enumeration_complete}

Maintenance Notes:
- Weekly backup protocols active
- Log rotation configured
- Volume snapshots stored offsite
- Secondary access role: ${var.lab_prefix}-logis-role
EOT
}

# DynamoDB Table
resource "aws_dynamodb_table" "data_repository" {
  name           = "${var.lab_prefix}-DataRelicRepository-${random_string.suffix.result}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "RecordID"

  attribute {
    name = "RecordID"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name               = "${var.lab_prefix}-data-repository"
    DataClassification = "Confidential"
  })
}

# EBS Volume for forensics
resource "aws_ebs_volume" "target_volume" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 8
  type              = "gp3"
  
  tags = merge(local.common_tags, {
    Name   = "${var.lab_prefix}-evidence-volume"
    Status = "detached"
  })
}

# Temporary attachment during setup only
resource "aws_volume_attachment" "setup_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.target_volume.id
  instance_id = aws_instance.cogitator_vm.id

  # Force detachment after setup
  stop_instance_before_detaching = false
}

# EC2 Instance
resource "aws_instance" "cogitator_vm" {
  ami                    = data.aws_ami.ubuntu_22.id
  instance_type          = local.instance_type
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [
    module.vpc.ssh_security_group_id,
    module.vpc.web_security_group_id
  ]
  iam_instance_profile   = aws_iam_instance_profile.cogitator_profile.name
  key_name               = var.ssh_key_name
  availability_zone      = data.aws_availability_zones.available.names[0]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  user_data = templatefile("${path.module}/userdata.tpl", {
    lab_name             = var.lab_prefix
    bucket_name          = aws_s3_bucket.data_bucket.bucket
    volume_id            = aws_ebs_volume.target_volume.id
    logis_role_arn       = aws_iam_role.logis_role.arn
    dynamodb_table       = aws_dynamodb_table.data_repository.name
  })

  tags = merge(local.common_tags, {
    Name         = "${var.lab_prefix}-lab"
    AutoShutdown = "4hours"
  })
  
  lifecycle {
    ignore_changes = [ami, user_data]
  }
}