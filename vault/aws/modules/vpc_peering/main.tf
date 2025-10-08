resource "aws_vpc_peering_connection" "this" {
  vpc_id        = var.vpc_id_attacker
  peer_vpc_id   = var.vpc_id_target
  auto_accept   = true

  tags = {
    Name = var.peering_name
  }
}

resource "aws_route" "attacker_to_target" {
  route_table_id            = var.public_rt_attacker
  destination_cidr_block    = var.cidr_block_target
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "target_to_attacker" {
  route_table_id            = var.public_rt_target
  destination_cidr_block    = var.cidr_block_attacker
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
