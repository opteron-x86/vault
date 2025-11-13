resource "aws_ec2_traffic_mirror_filter" "mirror_filter" {
  description = "Mirror all traffic"

  tags = {
    mission = "cte"
  }
}

resource "aws_ec2_traffic_mirror_target" "collector_target" {
  network_interface_id = var.collector_instance_primary_interface_id

  tags = {
    mission = "cte"
  }
}

resource "aws_ec2_traffic_mirror_filter_rule" "ingress_rule" {
  description              = "Capture all ingress traffic"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.mirror_filter.id
  destination_cidr_block   = "0.0.0.0/0"
  source_cidr_block        = "0.0.0.0/0"
  rule_number              = 100
  rule_action              = "accept"
  traffic_direction        = "ingress"
  protocol                 = 0
}

resource "aws_ec2_traffic_mirror_filter_rule" "egress_rule" {
  description              = "Capture all egress traffic"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.mirror_filter.id
  destination_cidr_block   = "0.0.0.0/0"
  source_cidr_block        = "0.0.0.0/0"
  rule_number              = 100
  rule_action              = "accept"
  traffic_direction        = "egress"
  protocol                 = 0
}

resource "aws_ec2_traffic_mirror_session" "mirror_session" {
  description              = "Mirror session for target instance"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.mirror_filter.id
  traffic_mirror_target_id = aws_ec2_traffic_mirror_target.collector_target.id
  network_interface_id     = var.target_instance_primary_interface_id
  session_number           = 1

  tags = {
    mission = "cte"
  }
}

