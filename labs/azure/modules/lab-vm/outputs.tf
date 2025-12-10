output "vm_id" {
  description = "VM ID"
  value       = var.os_type == "linux" ? azurerm_linux_virtual_machine.vm[0].id : azurerm_windows_virtual_machine.vm[0].id
}

output "vm_name" {
  description = "VM name"
  value       = var.name
}

output "private_ip" {
  description = "Private IP address"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "public_ip" {
  description = "Public IP address"
  value       = var.assign_public_ip ? azurerm_public_ip.vm[0].ip_address : null
}

output "network_interface_id" {
  description = "Network interface ID"
  value       = azurerm_network_interface.vm.id
}

output "identity_principal_id" {
  description = "System-assigned identity principal ID"
  value = var.enable_system_identity ? (
    var.os_type == "linux" ? azurerm_linux_virtual_machine.vm[0].identity[0].principal_id : azurerm_windows_virtual_machine.vm[0].identity[0].principal_id
  ) : null
}

output "os_type" {
  description = "Operating system type"
  value       = var.os_type
}