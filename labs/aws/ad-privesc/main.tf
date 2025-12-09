resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_password" "dsrm_password" {
  length  = 16
  special = true
}

resource "random_password" "admin_password" {
  length  = 16
  special = true
}

resource "random_password" "lowpriv_password" {
  length  = 12
  special = false
}

locals {
  lab_name = "${var.lab_prefix}-${random_string.suffix.result}"
  common_tags = merge(var.default_tags, {
    Lab          = "ad-privesc"
    Difficulty   = "4"
    AutoShutdown = "4hours"
  })
}

module "vpc" {
  source = "../modules/lab-vpc"

  name_prefix       = var.lab_prefix
  vpc_cidr          = "10.0.0.0/16"
  aws_region        = var.aws_region
  allowed_ssh_cidrs = var.allowed_source_ips

  tags = local.common_tags
}

resource "aws_security_group" "dc" {
  name        = "${local.lab_name}-dc"
  description = "Domain Controller access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "RDP from allowed IPs"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_source_ips
  }

  ingress {
    description = "AD traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-dc-sg"
  })
}

resource "aws_security_group" "workstation" {
  name        = "${local.lab_name}-ws"
  description = "Workstation access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "RDP from allowed IPs"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_source_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-ws-sg"
  })
}

resource "aws_instance" "dc" {
  ami                    = module.ami.windows_server_2022_id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.dc.id]
  key_name               = var.ssh_key_name

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data_base64 = base64encode(templatefile("${path.module}/setup.ps1", {
    domain_name      = var.domain_name
    domain_netbios   = var.domain_netbios
    dsrm_password    = random_password.dsrm_password.result
    admin_password   = random_password.admin_password.result
    lowpriv_password = random_password.lowpriv_password.result
  }))

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-dc"
  })

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }
}

resource "aws_instance" "workstation" {
  ami                    = module.ami.windows_server_2022_id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.workstation.id]
  key_name               = var.ssh_key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data_base64 = base64encode(templatefile("${path.module}/workstation.ps1", {
    domain_name      = var.domain_name
    domain_netbios   = var.domain_netbios
    dc_ip            = aws_instance.dc.private_ip
    admin_password   = random_password.admin_password.result
  }))

  tags = merge(local.common_tags, {
    Name = "${local.lab_name}-ws01"
  })

  depends_on = [aws_instance.dc]

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }
}