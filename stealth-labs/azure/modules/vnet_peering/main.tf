resource "azurerm_virtual_network_peering" "attacker_to_target" {
  name                      = var.peering_name
  resource_group_name       = var.resource_group_name
  virtual_network_name      = var.vnet_name_attacker
  remote_virtual_network_id = var.vnet_id_target

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "target_to_attacker" {
  name                      = "${var.peering_name}-reverse"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = var.vnet_name_target
  remote_virtual_network_id = var.vnet_id_attacker

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
