# Azure RBAC Privilege Escalation Lab
# Attack Chain: Service Principal → Custom Role Discovery → Role Assignment → Storage Access
# Difficulty: Easy-Medium
# Estimated Time: 30-45 minutes

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  backend "local" {}
}

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

provider "azuread" {
  environment = "usgovernment"
}

locals {
  common_tags = {
    Environment  = "lab"
    Destroyable  = "true"
    Scenario     = "rbac-privilege-escalation"
    AutoShutdown = "24hours"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "lab" {
  name     = "${var.lab_prefix}-rg-${random_string.suffix.result}"
  location = var.azure_region
  tags     = local.common_tags
}

resource "azuread_application" "developer" {
  display_name = "${var.lab_prefix}-developer-${random_string.suffix.result}"
  owners       = [data.azurerm_client_config.current.object_id]
  tags         = ["lab", "developer-access"]
}

resource "azuread_service_principal" "developer" {
  client_id = azuread_application.developer.client_id
  owners    = [data.azurerm_client_config.current.object_id]
  tags      = ["lab", "developer-access"]
}

resource "azuread_service_principal_password" "developer" {
  service_principal_id = azuread_service_principal.developer.id
  end_date_relative    = "8760h"
}

resource "azurerm_role_definition" "developer_base" {
  name        = "${var.lab_prefix}-developer-base-${random_string.suffix.result}"
  scope       = data.azurerm_subscription.current.id
  description = "Base permissions for application developers"

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.KeyVault/vaults/read",
      "Microsoft.KeyVault/vaults/secrets/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

resource "azurerm_role_definition" "developer_self_manage" {
  name        = "${var.lab_prefix}-developer-self-service-${random_string.suffix.result}"
  scope       = data.azurerm_subscription.current.id
  description = "Self-service role management for developers"

  permissions {
    actions = [
      "Microsoft.Authorization/roleDefinitions/read",
      "Microsoft.Authorization/roleAssignments/read",
      "Microsoft.Authorization/roleAssignments/write",
      "Microsoft.Authorization/roleAssignments/delete"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id
  ]
}

resource "azurerm_role_assignment" "developer_base" {
  scope              = azurerm_resource_group.lab.id
  role_definition_id = azurerm_role_definition.developer_base.role_definition_resource_id
  principal_id       = azuread_service_principal.developer.object_id
}

resource "azurerm_role_assignment" "developer_self_manage" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.developer_self_manage.role_definition_resource_id
  principal_id       = azuread_service_principal.developer.object_id
}

resource "azurerm_storage_account" "protected" {
  name                     = "${var.lab_prefix}protected${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = merge(local.common_tags, {
    DataClassification = "Confidential"
    Owner              = "Security Team"
  })
}

resource "azurerm_storage_container" "financial" {
  name                  = "financial-data"
  storage_account_name  = azurerm_storage_account.protected.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "revenue" {
  name                   = "q4-2024-revenue.csv"
  storage_account_name   = azurerm_storage_account.protected.name
  storage_container_name = azurerm_storage_container.financial.name
  type                   = "Block"
  source_content = <<-EOT
department,revenue,expenses,profit_margin
Engineering,2500000,1800000,28.0
Sales,3200000,900000,71.9
Marketing,800000,750000,6.3
Operations,1500000,1200000,20.0
FLAG{azure_rbac_privilege_escalation_successful},999999999,0,100.0
EOT
}

resource "azurerm_storage_container" "secrets" {
  name                  = "secrets"
  storage_account_name  = azurerm_storage_account.protected.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "credentials" {
  name                   = "production-credentials.json"
  storage_account_name   = azurerm_storage_account.protected.name
  storage_container_name = azurerm_storage_container.secrets.name
  type                   = "Block"
  source_content = jsonencode({
    database = {
      host     = "prod-sql.usgovcloudapi.net"
      username = "sqladmin"
      password = "P@ssw0rd_Pr0d_2024!"
    }
    api_keys = {
      storage_connection = azurerm_storage_account.protected.primary_connection_string
      key_vault_url      = "https://prod-kv.vault.usgovcloudapi.net/"
    }
  })
}

data "azurerm_client_config" "deployer" {}

resource "azurerm_key_vault" "lab" {
  name                       = "${var.lab_prefix}-kv-${random_string.suffix.result}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.deployer.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azuread_service_principal.developer.object_id

    secret_permissions = [
      "Get", "List"
    ]
  }

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "storage_hint" {
  name         = "protected-storage-account"
  value        = azurerm_storage_account.protected.name
  key_vault_id = azurerm_key_vault.lab.id

  depends_on = [azurerm_key_vault.lab]
}

resource "azurerm_key_vault_secret" "security_note" {
  name         = "security-review-notes"
  value        = "TODO: Review custom RBAC roles for developers. Self-service role may be too broad. Need to restrict roleAssignments/write to specific scopes."
  key_vault_id = azurerm_key_vault.lab.id

  depends_on = [azurerm_key_vault.lab]
}