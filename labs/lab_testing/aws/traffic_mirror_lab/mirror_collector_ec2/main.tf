data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "collector_sg" {
  name        = "collector-instance-sg"
  vpc_id      = var.mirror_vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "VXLAN traffic"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "All traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    mission = "cte"
  }
}

resource "aws_instance" "collector_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = var.mirror_subnet_id
  key_name      = var.mirror_vpc_id

  vpc_security_group_ids = [aws_security_group.collector_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y tcpdump
              echo "Traffic collector instance ready" > /var/log/collector-status.log
              EOF

  tags = {
    mission = "cte"
  }
}

