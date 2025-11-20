resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_password" "vnc_password" {
  length  = 12
  special = false
}

resource "random_password" "caldera_admin" {
  length  = 16
  special = true
}

locals {
  lab_name = "${var.lab_prefix}-caldera"
  common_tags = merge(var.default_tags, {
    Lab          = "caldera"
    Difficulty   = "1"
    AutoShutdown = "8hours"
  })
  instance_type = var.instance_type
}

module "vpc" {
  source = "../modules/lab-vpc"

  name_prefix       = var.lab_prefix
  vpc_cidr          = "10.0.0.0/16"
  aws_region        = var.aws_region
  allowed_ssh_cidrs = var.allowed_source_ips
  
  tags = local.common_tags
}

resource "aws_security_group" "remote_desktop" {
  name        = "${local.lab_name}-rdp-${random_string.suffix.result}"
  description = "Allow RDP and VNC access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.allowed_source_ips
  }

  ingress {
    description = "VNC"
    from_port   = 5901
    to_port     = 5901
    protocol    = "tcp"
    cidr_blocks = var.allowed_source_ips
  }

  ingress {
    description = "Caldera web interface"
    from_port   = 8888
    to_port     = 8888
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
    Name = "${local.lab_name}-rdp"
  })
}

resource "aws_instance" "caldera" {
  ami                    = module.ami.ubuntu_24_04_id
  instance_type          = local.instance_type
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [
    module.vpc.ssh_security_group_id,
    aws_security_group.remote_desktop.id
  ]
  key_name = var.ssh_key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    vnc_password    = random_password.vnc_password.result
    caldera_admin   = random_password.caldera_admin.result
  }))

  tags = merge(local.common_tags, {
    Name         = "${local.lab_name}-server"
    AutoShutdown = "8hours"
  })
  
  lifecycle {
    ignore_changes = [ami]
  }
}