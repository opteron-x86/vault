# Outputs from the vnet module
output "vnet_id_target" {
  value = module.vnet.vnet_id_target
}

output "vnet_id_attacker" {
  value = module.vnet.vnet_id_attacker
}

output "subnet_id_attacker" {
  value = module.vnet.attacker_subnet_id
}

output "subnet_id_target" {
  value = module.vnet.target_subnet_id
}

output "cidr_block_attacker" {
  value = module.vnet.attacker_cidr_block
}

output "cidr_block_target" {
  value = module.vnet.target_cidr_block
}

# Outputs from the vm module
output "attacker_vm_private_ip" {
  value = module.vm.attacker_vm_private_ip
}

output "attacker_vm_public_ip" {
  value = module.vm.attacker_vm_public_ip
}

output "target_vm_private_ip" {
  value = module.vm.target_vm_private_ip
}

output "target_vm_public_ip" {
  value = module.vm.target_vm_public_ip
}

output "target_private_key" {
  value     = module.vm.target_private_key
  sensitive = true
}

output "iam_workshop_user_username" {
  value = module.iam_workshop_user.username
}

output "signin_url" {
  value = module.iam_workshop_user.signin_url
}

output "iam_workshop_user_password" {
  value = module.iam_workshop_user.password
}

output "user_ip" {
  value = var.user_ip
}

output "admin_ip" {
  value = var.admin_ip
}

output "lab_name" {
  value = var.lab_name
}

output "flask_app_storage_name" {
  value       = azurerm_storage_account.flask_app_storage.name
  description = "The name of the dynamically generated Storage Account"
}

output "flask_app_container_name" {
  value       = azurerm_storage_container.flask_app_container.name
  description = "The name of the dynamically generated Storage Container"
}
