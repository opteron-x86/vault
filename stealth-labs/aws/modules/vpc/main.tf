# Attacker VPC resources
resource "aws_vpc" "vpc_attacker" {
  cidr_block           = var.cidr_block_attacker
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name_attacker
  }
}

resource "aws_subnet" "public_subnet_attacker" {
  vpc_id     = aws_vpc.vpc_attacker.id
  cidr_block = var.public_subnet_attacker
  availability_zone      = var.availability_zone
}

resource "aws_internet_gateway" "igw_attacker" {
  vpc_id = aws_vpc.vpc_attacker.id
}

resource "aws_route_table" "new_rt_attacker" {
  vpc_id = aws_vpc.vpc_attacker.id
}

resource "aws_route" "route_external" {
  route_table_id         = aws_route_table.new_rt_attacker.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_attacker.id
}

resource "aws_route_table_association" "subnet_assoc_for_vpc_attacker" {
  subnet_id      = aws_subnet.public_subnet_attacker.id
  route_table_id = aws_route_table.new_rt_attacker.id
}

# Target VPC resources
resource "aws_vpc" "vpc_target" {
  cidr_block           = var.cidr_block_target
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name_target
  }
}

resource "aws_subnet" "public_subnet_target" {
  vpc_id     = aws_vpc.vpc_target.id
  cidr_block = var.public_subnet_target
  availability_zone      = var.availability_zone
}

resource "aws_internet_gateway" "igw_target" {
  vpc_id = aws_vpc.vpc_target.id
}

resource "aws_route_table" "route_table_target" {
  vpc_id = aws_vpc.vpc_target.id
}

resource "aws_route" "route_table_target_route" {
  route_table_id         = aws_route_table.route_table_target.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_target.id
}

resource "aws_route_table_association" "subnet_assoc_for_vpc_target" {
  subnet_id      = aws_subnet.public_subnet_target.id
  route_table_id = aws_route_table.route_table_target.id
}