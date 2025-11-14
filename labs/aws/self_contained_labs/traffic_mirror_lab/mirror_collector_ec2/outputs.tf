output "collector_instance_public_ip" {
  value = aws_instance.collector_instance.public_ip
}

output "collector_instance_private_ip" {
  value = aws_instance.collector_instance.private_ip
}

output "collector_instance_primary_network_interface_id" {
  value = aws_instance.collector_instance.primary_network_interface_id
}