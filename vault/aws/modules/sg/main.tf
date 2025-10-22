resource "aws_security_group" "this" {
  name        = "${var.vpc_id}-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.vpc_id}"

  # SSH for Admin
  dynamic "ingress" {
    for_each = var.admin_ip != null ? [var.admin_ip] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value] 
    }
  }

  # VNC for User
  dynamic "ingress" {
    for_each = var.user_ip != null ? [var.user_ip] : []
    content {
      from_port   = 8081
      to_port     = 8081
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # Allow all traffic from specified CIDR blocks
  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
