provider "azurerm" {
  features {}
}

# Define the selected location
variable "selected_location" {
  default = "East US"
}

resource "random_id" "attacker_vpc_name" {
  byte_length = 4
  prefix      = "external-vnet-"
}

resource "random_id" "target_vpc_name" {
  byte_length = 4
  prefix      = "internal-vnet-"
}

resource "random_integer" "attacker_cidr_block" {
  min = 0
  max = 255
}

resource "random_integer" "target_cidr_block" {
  min = 0
  max = 255
}

locals {
  attacker_cidr_block = "10.${random_integer.attacker_cidr_block.result}.0.0/16"
  attacker_subnet     = "10.${random_integer.attacker_cidr_block.result}.0.0/24"
  target_cidr_block   = "10.${random_integer.target_cidr_block.result}.0.0/16"
  target_subnet       = "10.${random_integer.target_cidr_block.result}.0.0/24"
}

resource "azurerm_resource_group" "main" {
  name     = "main-resources"
  location = var.selected_location
}

module "vnet" {
  source = "../modules/vnet"

  resource_group_name   = azurerm_resource_group.main.name
  location              = var.selected_location
  attacker_cidr_block   = local.attacker_cidr_block
  attacker_subnet       = local.attacker_subnet
  attacker_vnet_name    = random_id.attacker_vpc_name.hex
  target_cidr_block     = local.target_cidr_block
  target_subnet         = local.target_subnet
  target_vnet_name      = random_id.target_vpc_name.hex
}

module "vnet_peering" {
  source = "../modules/vnet_peering"
  
  resource_group_name   = azurerm_resource_group.main.name
  peering_name          = "external-to-internal-peering"
  vnet_id_attacker      = module.vnet.vnet_id_attacker
  vnet_id_target        = module.vnet.vnet_id_target
  attacker_cidr_block   = module.vnet.attacker_cidr_block
  target_cidr_block     = module.vnet.target_cidr_block
}

# Generate a random integer for the VM names
resource "random_integer" "lab_name_suffix" {
  min = 10
  max = 99
}

# Storage account and container for app templates
resource "azurerm_storage_account" "flask_app_storage" {
  name                     = "${var.lab_name}appstorage"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.selected_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "flask_app_container" {
  name                  = "app-templates"
  storage_account_name  = azurerm_storage_account.flask_app_storage.name
  container_access_type = "private"
}

# Upload files to the storage container
resource "azurerm_storage_blob" "web_templates" {
  for_each = fileset("${path.module}/templates", "*")

  name                   = each.value
  storage_account_name   = azurerm_storage_account.flask_app_storage.name
  storage_container_name = azurerm_storage_container.flask_app_container.name
  type                   = "Block"
  source                 = "${path.module}/templates/${each.value}"
}

resource "azurerm_role_assignment" "flask_app_storage_role" {
  principal_id           = azurerm_user_assigned_identity.canteen_identity.principal_id
  role_definition_name   = "Storage Blob Data Contributor"
  scope                  = azurerm_storage_account.flask_app_storage.id
}

# VM configuration
module "vm" {
  source = "../modules/vm"

  lab_name                = var.lab_name
  location                = var.selected_location
  resource_group_name     = azurerm_resource_group.main.name

  # Attacker Kali VM
  vm_name_attacker        = "black-cat-${random_integer.lab_name_suffix.result}"
  vm_size_attacker        = "Standard_B2s"
  subnet_id_attacker      = module.vnet.attacker_subnet_id
  vnet_id_attacker        = module.vnet.vnet_id_attacker
  security_group_attacker = module.security_group_attacker.security_group_id
  disk_size_attacker      = 64

  # Target Ubuntu VM
  vm_name_target          = "white-cat-${random_integer.lab_name_suffix.result}"
  vm_size_target          = "Standard_B1s"
  subnet_id_target        = module.vnet.target_subnet_id
  vnet_id_target          = module.vnet.vnet_id_target
  security_group_target   = module.security_group_target.security_group_id
  disk_size_target        = 8
  user_data               = data.template_file.userdata.rendered
  identity_ids            = [azurerm_user_assigned_identity.canteen_identity.id]
}

# User-assigned managed identity for VM access
resource "azurerm_user_assigned_identity" "canteen_identity" {
  name                = "${var.lab_name}_canteen_identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.selected_location
}

data "template_file" "userdata" {
  template = file("${path.module}/userdata.tpl")

  vars = {
    workshop_user_username = module.iam_workshop_user.username
    workshop_user_password = module.iam_workshop_user.password
    signin_url             = module.iam_workshop_user.signin_url
    flask_app_storage_name = azurerm_storage_account.flask_app_storage.name
    flask_app_container_name = azurerm_storage_container.flask_app_container.name
  }
}
