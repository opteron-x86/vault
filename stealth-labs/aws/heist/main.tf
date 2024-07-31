provider "random" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Fetch the first available AZ in the region
data "aws_availability_zones" "available" {}

# Define the selected AZ (can also be hardcoded)
variable "selected_az" {
  default = "us-east-2a"
  #default = data.aws_availability_zones.available.names[0]
}

resource "random_id" "attacker_vpc_name" {
  byte_length = 4
  prefix      = "external-vpc-"
}

resource "random_id" "target_vpc_name" {
  byte_length = 4
  prefix      = "internal-vpc-"
}

resource "random_integer" "attacker_cidr_block" {
  min = 0
  max = 255
}

resource "random_integer" "target_cidr_block" {
  min = 0
  max = 255
}

locals {
  attacker_cidr_block = "10.${random_integer.attacker_cidr_block.result}.0.0/16"
  attacker_subnet     = "10.${random_integer.attacker_cidr_block.result}.0.0/24"
  target_cidr_block   = "10.${random_integer.target_cidr_block.result}.0.0/16"
  target_subnet       = "10.${random_integer.target_cidr_block.result}.0.0/24"
}


module "vpc" {
  source = "../modules/vpc"

  cidr_block_attacker    = local.attacker_cidr_block
  public_subnet_attacker = local.attacker_subnet
  vpc_name_attacker      = random_id.attacker_vpc_name.hex
  cidr_block_target      = local.target_cidr_block
  public_subnet_target   = local.target_subnet
  availability_zone      = var.selected_az
  vpc_name_target        = random_id.target_vpc_name.hex
}

module "vpc_peering" {
  source = "../modules/vpc_peering"
  peering_name         = "external-to-internal-peering"
  vpc_id_attacker = module.vpc.vpc_id_attacker
  vpc_id_target   = module.vpc.vpc_id_target
  cidr_block_attacker  = module.vpc.cidr_block_attacker
  cidr_block_target    = module.vpc.cidr_block_target
  public_rt_attacker   = module.vpc.public_rt_attacker
  public_rt_target     = module.vpc.public_rt_target
}

module "security_group_attacker" {
  source = "../modules/sg"

  vpc_id              = module.vpc.vpc_id_attacker
  allowed_cidr_blocks = ["${var.user_ip}","${var.admin_ip}", module.vpc.cidr_block_target]
  user_ip    = var.user_ip
  admin_ip   = var.admin_ip
}

module "security_group_target" {
  source = "../modules/sg"

  vpc_id              = module.vpc.vpc_id_target
  allowed_cidr_blocks = [module.vpc.cidr_block_attacker]
  user_ip    = var.user_ip
  admin_ip   = var.admin_ip
}

# Generate a random integer for the VM names
resource "random_integer" "lab_name_suffix" {
  min = 10
  max = 99
} 

resource "aws_s3_bucket" "techtalks_bucket" {
  bucket = "${var.lab_name}-techtalks-bucket"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_object" "web_templates" {
  for_each = fileset("${path.module}/templates", "*")

  bucket = aws_s3_bucket.techtalks_bucket.bucket
  key    = each.value
  source = "${path.module}/templates/${each.value}"
}

resource "aws_iam_role" "techtalks_ec2_role" {
  name = "${var.lab_name}_techtalks_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "techtalks_access_policy" {
  name        = "${var.lab_name}_techtalks_access_policy"
  description = "Allow Canteen Lab to access the S3 bucket amd EBS volumes"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws-us-gov:s3:::${var.lab_name}-techtalks-bucket",
                "arn:aws-us-gov:s3:::${var.lab_name}-techtalks-bucket/*"
            ]
        },
      {
        "Effect": "Allow",
        "Action": [
          "ec2:DescribeVolumes",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeInstances"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ec2:CreateVolume",
          "ec2:DeleteVolume"
        ],
        "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.techtalks_ec2_role.name
  policy_arn = aws_iam_policy.techtalks_access_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.techtalks_ec2_role.name
}

# Get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*22.04*amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "vm" {
  source = "../modules/vm"

  lab_name              = var.lab_name
  # Attacker Kali VM
  ami_attacker_01       = var.kali_ami
  instance_type_attacker = "t3.medium"
  subnet_id_attacker    = module.vpc.public_subnet_attacker
  vpc_id_attacker       = module.vpc.vpc_id_attacker
  security_group_attacker = module.security_group_attacker.security_group_id
  attacker_vm_name      = "black-cat-${random_integer.lab_name_suffix.result}"
  volume_size_attacker  = 30

  # Target Ubuntu VM
  ami_target_01       = data.aws_ami.ubuntu.id
  instance_type_target = "t3.micro"
  subnet_id_target    = module.vpc.public_subnet_target
  vpc_id_target       = module.vpc.vpc_id_target
  security_group_target = module.security_group_target.security_group_id
  target_vm_name      = "white-cat-${random_integer.lab_name_suffix.result}"
  volume_size_target  = 8
  user_data           = data.template_file.userdata.rendered 
  availability_zone   = var.selected_az
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  create_target_volume = var.create_target_volume
}

data "template_file" "userdata" {
  template = file("${path.module}/userdata.tpl")

  vars = {
    techtalks_bucket_name  = aws_s3_bucket.techtalks_bucket.bucket
    }
}