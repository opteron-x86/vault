output "vpc_id_target" {
  value = aws_vpc.vpc_target.id
}

output "vpc_id_attacker" {
  value = aws_vpc.vpc_attacker.id
}

output "public_subnet_attacker" {
  value = aws_subnet.public_subnet_attacker.id
}

output "public_subnet_target" {
  value = aws_subnet.public_subnet_target.id
}

output "public_rt_attacker" {
  value = aws_route_table.new_rt_attacker.id
}

output "public_rt_target" {
  value = aws_route_table.route_table_target.id
}

output "cidr_block_attacker" {
  value = aws_vpc.vpc_attacker.cidr_block
}

output "cidr_block_target" {
  value = aws_vpc.vpc_target.cidr_block
}
