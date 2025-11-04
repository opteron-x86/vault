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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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
    Scenario     = "ebs-snapshot-exposure"
    AutoShutdown = "24hours"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

data "aws_caller_identity" "current" {}

resource "random_password" "db_password" {
  length  = 20
  special = true
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "api_key" {
  length  = 40
  special = false
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_iam_user" "limited_user" {
  name          = "${var.lab_prefix}-snapshot-analyst-${random_string.suffix.result}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-snapshot-analyst"
    Role = "Security Analyst"
  })
}

resource "aws_iam_access_key" "limited_user" {
  user = aws_iam_user.limited_user.name
}

resource "aws_iam_user_policy" "snapshot_permissions" {
  name = "${var.lab_prefix}-snapshot-enum-policy"
  user = aws_iam_user.limited_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SnapshotEnumeration"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeInstances",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Sid    = "VolumeOperations"
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DeleteVolume"
        ]
        Resource = "*"
      },
      {
        Sid    = "VolumeTags"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws-us-gov:ec2:*:*:volume/*"
      }
    ]
  })
}

resource "aws_instance" "temp_data_host" {
  ami           = "ami-0320614f158c301d8"
  instance_type = "t3.micro"
  
  availability_zone = "${var.aws_region}a"

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/sensitive_data.sh", {
    db_password = random_password.db_password.result
    jwt_secret  = random_password.jwt_secret.result
    api_key     = random_password.api_key.result
    ssh_private = tls_private_key.ssh_key.private_key_pem
    ssh_public  = tls_private_key.ssh_key.public_key_openssh
  }))

  tags = merge(local.common_tags, {
    Name = "${var.lab_prefix}-decommissioned-server"
  })
}

resource "time_sleep" "wait_for_userdata" {
  depends_on      = [aws_instance.temp_data_host]
  create_duration = "90s"
}

resource "aws_ebs_snapshot" "exposed_snapshot" {
  volume_id   = aws_instance.temp_data_host.root_block_device[0].volume_id
  description = "Backup snapshot from decommissioned production server - ${var.lab_prefix}"

  tags = merge(local.common_tags, {
    Name        = "${var.lab_prefix}-prod-backup-${formatdate("YYYY-MM-DD", timestamp())}"
    Server      = "web-prod-01"
    BackupType  = "final-decomm"
    Department  = "IT Operations"
  })

  depends_on = [time_sleep.wait_for_userdata]
}

resource "aws_snapshot_create_volume_permission" "public_snapshot" {
  snapshot_id = aws_ebs_snapshot.exposed_snapshot.id
  group       = "all"
}

resource "null_resource" "cleanup_instance" {
  depends_on = [aws_ebs_snapshot.exposed_snapshot]

  provisioner "local-exec" {
    command = "sleep 10"
  }
}