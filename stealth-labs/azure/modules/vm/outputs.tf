output "attacker_vm_private_ip" {
  value = azurerm_linux_virtual_machine.attacker_vm.private_ip_address
}

output "attacker_vm_public_ip" {
  value = azurerm_linux_virtual_machine.attacker_vm.public_ip_address
}

output "target_vm_private_ip" {
  value = azurerm_linux_virtual_machine.target_vm.private_ip_address
}

output "target_vm_public_ip" {
  value = azurerm_linux_virtual_machine.target_vm.public_ip_address
}

output "target_private_key" {
  value     = tls_private_key.target_key.private_key_pem
  sensitive = true
}
