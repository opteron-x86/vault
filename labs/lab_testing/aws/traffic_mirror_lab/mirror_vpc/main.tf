resource "aws_vpc" "mirror_vpc" {
  cidr_block           = "192.168.0.0/16"

  tags = {
    mission = "cte"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.mirror_vpc.id
  cidr_block = "192.168.1.0/24"

  tags = {
    mission = "cte"
  }
}

resource "aws_internet_gateway" "vpc_gateway" {
  vpc_id = aws_vpc.mirror_vpc.id

  tags = {
    mission = "cte"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.mirror_vpc.id

  tags = {
    mission = "cte"
  }
}

resource "aws_route" "rt_route" {
  route_table_id            = aws_route_table.route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.vpc_gateway.id
}

resource "aws_route_table_association" "subnet_assoc_for_vpc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}

