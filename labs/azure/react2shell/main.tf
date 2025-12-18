# React2Shell Lab (CVE-2025-55182) - Azure
# Attack Chain: RSC Deserialization RCE → Credential Discovery → IMDS Token → Blob Exfiltration
# Difficulty: 4
# Estimated Time: 45-60 minutes

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  environment = "usgovernment"
}

locals {
  common_tags = {
    Environment  = "lab"
    Destroyable  = "true"
    Scenario     = "react2shell"
    AutoShutdown = "4hours"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_password" "api_key" {
  length  = 32
  special = false
}

resource "random_password" "db_password" {
  length  = 20
  special = true
}

resource "random_password" "admin_password" {
  length  = 16
  special = true
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "lab" {
  name     = "${var.lab_prefix}-rg-${random_string.suffix.result}"
  location = var.azure_region
  tags     = local.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "lab" {
  count = var.enable_logging ? 1 : 0

  name                = "${var.lab_prefix}-logs-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# Storage Account Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "storage" {
  count = var.enable_logging ? 1 : 0

  name                       = "storage-diagnostics"
  target_resource_id         = "${azurerm_storage_account.app_data.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab[0].id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}

# Key Vault Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  count = var.enable_logging ? 1 : 0

  name                       = "keyvault-diagnostics"
  target_resource_id         = azurerm_key_vault.app_config.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab[0].id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# NSG Flow Logs
resource "azurerm_network_watcher" "lab" {
  count = var.enable_logging ? 1 : 0

  name                = "${var.lab_prefix}-nw-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.common_tags
}

resource "azurerm_storage_account" "flow_logs" {
  count = var.enable_logging ? 1 : 0

  name                     = "${replace(var.lab_prefix, "-", "")}flow${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.common_tags
}

resource "azurerm_network_watcher_flow_log" "nsg" {
  count = var.enable_logging ? 1 : 0

  network_watcher_name = azurerm_network_watcher.lab[0].name
  resource_group_name  = azurerm_resource_group.lab.name
  name                 = "${var.lab_prefix}-flowlog"

  network_security_group_id = azurerm_network_security_group.app.id
  storage_account_id        = azurerm_storage_account.flow_logs[0].id
  enabled                   = true
  version                   = 2

  retention_policy {
    enabled = true
    days    = 7
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.lab[0].workspace_id
    workspace_region      = azurerm_log_analytics_workspace.lab[0].location
    workspace_resource_id = azurerm_log_analytics_workspace.lab[0].id
    interval_in_minutes   = 10
  }
}

module "images" {
  source   = "../modules/image-lookup"
  location = var.azure_region
}

module "vnet" {
  source = "../modules/lab-vnet"

  name_prefix         = var.lab_prefix
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  vnet_cidr           = "10.0.0.0/16"

  create_ssh_nsg = false
  create_rdp_nsg = false
  create_web_nsg = false

  tags = local.common_tags
}

resource "azurerm_network_security_group" "app" {
  name                = "${var.lab_prefix}-app-nsg-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_source_ips
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Web"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefixes    = var.allowed_source_ips
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# User-Assigned Managed Identity for VM
resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "${var.lab_prefix}-identity-${random_string.suffix.result}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.common_tags
}

# Storage Account with sensitive data
resource "azurerm_storage_account" "app_data" {
  name                     = "${replace(var.lab_prefix, "-", "")}data${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = local.common_tags
}

resource "azurerm_storage_container" "exports" {
  name                  = "exports"
  storage_account_name  = azurerm_storage_account.app_data.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "config" {
  name                  = "config"
  storage_account_name  = azurerm_storage_account.app_data.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "customer_data" {
  name                   = "customers.csv"
  storage_account_name   = azurerm_storage_account.app_data.name
  storage_container_name = azurerm_storage_container.exports.name
  type                   = "Block"
  source_content         = <<-CSV
id,name,email,plan,card_last_four
1001,Marcus Chen,m.chen@techcorp.io,enterprise,4532
1002,Sarah Williams,s.williams@finserv.com,professional,8876
1003,James Rodriguez,j.rod@startup.dev,enterprise,2341
1004,Emily Zhang,e.zhang@bigcorp.net,enterprise,9902
FLAG{azure_blob_customer_data_exfiltrated}
CSV
}

resource "azurerm_storage_blob" "api_keys" {
  name                   = "api-keys.json"
  storage_account_name   = azurerm_storage_account.app_data.name
  storage_container_name = azurerm_storage_container.config.name
  type                   = "Block"
  source_content = jsonencode({
    stripe_live    = "sk_live_${random_password.api_key.result}"
    sendgrid       = "SG.${random_string.suffix.result}.fake"
    internal_token = "FLAG{sensitive_api_keys_exposed}"
  })
}

# Role assignment for blob access
resource "azurerm_role_assignment" "blob_reader" {
  scope                = azurerm_storage_account.app_data.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

# Key Vault with secrets
resource "azurerm_key_vault" "app_config" {
  name                       = "${var.lab_prefix}-kv-${random_string.suffix.result}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.app_identity.principal_id

    secret_permissions = ["Get", "List"]
  }

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  value        = "postgresql://app:${random_password.db_password.result}@db.internal:5432/production"
  key_vault_id = azurerm_key_vault.app_config.id
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = random_password.api_key.result
  key_vault_id = azurerm_key_vault.app_config.id
}

resource "azurerm_key_vault_secret" "admin_api_key" {
  name         = "admin-api-key"
  value        = "FLAG{key_vault_secrets_accessed}"
  key_vault_id = azurerm_key_vault.app_config.id
}

resource "azurerm_key_vault_secret" "deployment_notes" {
  name         = "deployment-notes"
  value        = "Production deployment uses Next.js 16.0.6 with App Router. Customer data synced to storage account: ${azurerm_storage_account.app_data.name}"
  key_vault_id = azurerm_key_vault.app_config.id
}

# VM running vulnerable Next.js
module "app_server" {
  source = "../modules/lab-vm"

  name                = "${var.lab_prefix}-server-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  subnet_id           = module.vnet.public_subnet_ids[0]
  vm_size             = var.vm_size

  os_type      = "linux"
  source_image = module.images.ubuntu_22_04

  admin_username = "azureuser"
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : null
  admin_password = var.ssh_public_key == "" ? (var.admin_password != "" ? var.admin_password : random_password.admin_password.result) : null

  associate_nsg              = true
  network_security_group_id  = azurerm_network_security_group.app.id
  user_assigned_identity_ids = [azurerm_user_assigned_identity.app_identity.id]

  custom_data = base64encode(templatefile("${path.module}/user_data.sh", {
    storage_account = azurerm_storage_account.app_data.name
    key_vault_name  = azurerm_key_vault.app_config.name
    api_key         = random_password.api_key.result
    shutdown_hours  = var.auto_shutdown_hours
    client_id       = azurerm_user_assigned_identity.app_identity.client_id
  }))

  os_disk_size_gb = 30

  tags = local.common_tags
}