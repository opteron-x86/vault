output "vnet_id_attacker" {
  value = azurerm_virtual_network.vnet_attacker.id
}

output "attacker_subnet_id" {
  value = azurerm_subnet.public_subnet_attacker.id
}

output "vnet_id_target" {
  value = azurerm_virtual_network.vnet_target.id
}

output "target_subnet_id" {
  value = azurerm_subnet.public_subnet_target.id
}
