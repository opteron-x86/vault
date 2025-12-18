output "vnet_id" {
  description = "VNet ID"
  value       = azurerm_virtual_network.lab.id
}

output "vnet_name" {
  description = "VNet name"
  value       = azurerm_virtual_network.lab.name
}

output "vnet_cidr" {
  description = "VNet address space"
  value       = azurerm_virtual_network.lab.address_space[0]
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = azurerm_subnet.public[*].id
}

output "public_subnet_names" {
  description = "Public subnet names"
  value       = azurerm_subnet.public[*].name
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = var.enable_private_subnets ? azurerm_subnet.private[*].id : []
}

output "private_subnet_names" {
  description = "Private subnet names"
  value       = var.enable_private_subnets ? azurerm_subnet.private[*].name : []
}

output "nat_gateway_id" {
  description = "NAT gateway ID"
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.lab[0].id : null
}

output "ssh_nsg_id" {
  description = "SSH NSG ID"
  value       = var.create_ssh_nsg ? azurerm_network_security_group.ssh[0].id : null
}

output "rdp_nsg_id" {
  description = "RDP NSG ID"
  value       = var.create_rdp_nsg ? azurerm_network_security_group.rdp[0].id : null
}

output "web_nsg_id" {
  description = "Web NSG ID"
  value       = var.create_web_nsg ? azurerm_network_security_group.web[0].id : null
}