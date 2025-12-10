output "app_url" {
  description = "Application URL"
  value       = "http://${module.app_server.public_ip}:3000"
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh azureuser@${module.app_server.public_ip}"
}

output "vm_name" {
  description = "VM name"
  value       = module.app_server.vm_name
}

output "resource_group" {
  description = "Resource group name"
  value       = azurerm_resource_group.lab.name
}

output "managed_identity_client_id" {
  description = "Managed identity client ID"
  value       = azurerm_user_assigned_identity.app_identity.client_id
}

output "storage_account" {
  description = "Storage account name"
  value       = azurerm_storage_account.app_data.name
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.app_config.name
}

output "admin_password" {
  description = "Admin password (if SSH key not provided)"
  value       = var.ssh_public_key == "" ? (var.admin_password != "" ? var.admin_password : random_password.admin_password.result) : "SSH key authentication configured"
  sensitive   = true
}

output "attack_surface" {
  description = "Initial attack entry point"
  value       = "Next.js 16.0.6 application with App Router at http://${module.app_server.public_ip}:3000"
}

output "attack_chain" {
  description = "Attack path overview"
  value       = "React2Shell RCE → Environment Discovery → IMDS Token → Blob Storage Exfiltration"
}

output "setup_instructions" {
  description = "Instructions for accessing the lab"
  value       = <<-EOT
Application URL: http://${module.app_server.public_ip}:3000

SSH Access: ssh azureuser@${module.app_server.public_ip}

To view admin password (if using password auth):
terraform output -raw admin_password

Begin by identifying the vulnerable Next.js application and exploiting CVE-2025-55182.
EOT
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = var.enable_logging ? azurerm_log_analytics_workspace.lab[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name"
  value       = var.enable_logging ? azurerm_log_analytics_workspace.lab[0].name : null
}