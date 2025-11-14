output "target_instance_public_ip" {
  value       = aws_instance.target_instance.public_ip
}

output "target_instance_private_ip" {
  value       = aws_instance.target_instance.private_ip
}

output "target_instance_primary_network_interface_id" {
  value       = aws_instance.target_instance.primary_network_interface_id
}