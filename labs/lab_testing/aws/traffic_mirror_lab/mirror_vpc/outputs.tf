output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "mirror_vpc_id" {
  value = aws_vpc.mirror_vpc.id
}

output "mirror_vpc_cidr" {
  value = aws_vpc.mirror_vpc.cidr_block
}