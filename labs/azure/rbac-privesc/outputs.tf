output "service_principal_client_id" {
  description = "Service principal application (client) ID"
  value       = azuread_application.developer.client_id
}

output "service_principal_client_secret" {
  description = "Service principal client secret"
  value       = azuread_service_principal_password.developer.value
  sensitive   = true
}

output "tenant_id" {
  description = "Azure AD tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Azure subscription ID"
  value       = data.azurerm_subscription.current.subscription_id
}

output "resource_group_name" {
  description = "Resource group containing lab resources"
  value       = azurerm_resource_group.lab.name
}

output "storage_account_name" {
  description = "Storage account containing protected data"
  value       = azurerm_storage_account.protected.name
}

output "key_vault_name" {
  description = "Key Vault containing hints"
  value       = azurerm_key_vault.lab.name
}

output "setup_instructions" {
  description = "Instructions for configuring Azure CLI"
  value       = <<-EOT
Login with service principal credentials:

az cloud set --name AzureUSGovernment
az login --service-principal \
  --username ${azuread_application.developer.client_id} \
  --password ${azuread_service_principal_password.developer.value} \
  --tenant ${data.azurerm_client_config.current.tenant_id}

To view client secret after apply:
terraform output -raw service_principal_client_secret

Start by enumerating your RBAC permissions:
az role assignment list --assignee ${azuread_application.developer.client_id}
az role definition list --custom-role-only true
az storage account list
EOT
}

output "attack_chain_hint" {
  description = "Starting point for the lab"
  value       = "Begin by understanding what RBAC roles and permissions your service principal has. What can you assign?"
}