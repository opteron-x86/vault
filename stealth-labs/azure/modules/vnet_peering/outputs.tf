output "peering_id_attacker_to_target" {
  value = azurerm_virtual_network_peering.attacker_to_target.id
}

output "peering_id_target_to_attacker" {
  value = azurerm_virtual_network_peering.target_to_attacker.id
}
