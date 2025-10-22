output "attacker_vm_private_ip" {
  value = aws_instance.attacker_vm.private_ip
}

output "attacker_vm_public_ip" {
  value = aws_instance.attacker_vm.public_ip
}

output "target_vm_private_ip" {
  value = aws_instance.target_vm.private_ip
}

output "target_vm_public_ip" {
  value = aws_instance.target_vm.public_ip
}

output "target_private_key" {
  value     = tls_private_key.target_key.private_key_pem
  sensitive = true
}

output "target_instance_id" {
  value = aws_instance.target_vm.id
}

# Output the EBS Volume ID
output "target_volume_id" {
  value       = aws_ebs_volume.target_volume.id
  description = "The ID of the EBS volume attached to the target instance"
}