resource "aws_instance" "attacker_vm" {
  ami                         = var.ami_attacker_01
  instance_type               = var.instance_type_attacker
  subnet_id                   = var.subnet_id_attacker
  vpc_security_group_ids      = [var.security_group_attacker]
  availability_zone           = var.availability_zone
  associate_public_ip_address = true

  tags = {
    Name = var.attacker_vm_name
  }

  root_block_device {
    volume_size = var.volume_size_attacker
  }
}

resource "tls_private_key" "target_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "target_key_pair" {
  key_name   = "target-key-pair"
  public_key = tls_private_key.target_key.public_key_openssh
}

resource "aws_instance" "target_vm" {
  ami                         = var.ami_target_01
  instance_type               = var.instance_type_target
  key_name                    = aws_key_pair.target_key_pair.key_name
  subnet_id                   = var.subnet_id_target
  vpc_security_group_ids      = [var.security_group_target]
  associate_public_ip_address = true
  availability_zone           = var.availability_zone
  user_data                   = var.user_data

  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  tags = {
    Name = var.target_vm_name
  }

  root_block_device {
    volume_size = var.volume_size_target
  }
}

# Target EBS Volume (created dynamically per workspace)
resource "aws_ebs_volume" "target_volume" {
  availability_zone = var.availability_zone
  size              = 8  # Adjust size as needed
  type              = "gp3"
  tags = {
    Name = "target-volume-${var.lab_name}"
  }
}

# Volume Attachment (attached dynamically to target instance)
resource "aws_volume_attachment" "target_ebs_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.target_volume.id
  instance_id = aws_instance.target_vm.id
  depends_on  = [aws_instance.target_vm] 
}
