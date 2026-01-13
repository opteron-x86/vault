resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "random_password" "dsrm_password" {
  length  = 16
  special = true
}

resource "random_password" "admin_password" {
  length  = 16
  special = true
}

resource "random_password" "lowpriv_password" {
  length  = 12
  special = false
}

locals {
  lab_name = "${var.lab_prefix}-${random_string.suffix.result}"
  common_tags = {
    Lab          = "ad-privesc"
    Difficulty   = "4"
    AutoShutdown = "4hours"
    Environment  = "lab"
    Destroyable  = "true"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "lab" {
  name     = "${local.lab_name}-rg"
  location = var.azure_region
  tags     = local.common_tags
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

resource "azurerm_network_security_group" "dc" {
  name                = "${local.lab_name}-dc-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.allowed_source_ips
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AD-Internal"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = module.vnet.vnet_cidr
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "workstation" {
  name                = "${local.lab_name}-ws-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.allowed_source_ips
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_public_ip" "dc" {
  name                = "${local.lab_name}-dc-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "dc" {
  name                = "${local.lab_name}-dc-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.vnet.public_subnet_ids[0]
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(module.vnet.vnet_cidr, 10)
    public_ip_address_id          = azurerm_public_ip.dc.id
  }

  tags = local.common_tags
}

resource "azurerm_network_interface_security_group_association" "dc" {
  network_interface_id      = azurerm_network_interface.dc.id
  network_security_group_id = azurerm_network_security_group.dc.id
}

resource "azurerm_windows_virtual_machine" "dc" {
  name                = "${local.lab_name}-dc"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result
  network_interface_ids = [azurerm_network_interface.dc.id]

  os_disk {
    name                 = "${local.lab_name}-dc-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = module.images.windows_server_2022.publisher
    offer     = module.images.windows_server_2022.offer
    sku       = module.images.windows_server_2022.sku
    version   = module.images.windows_server_2022.version
  }

  custom_data = base64encode(templatefile("${path.module}/setup.ps1", {
    domain_name      = var.domain_name
    domain_netbios   = var.domain_netbios
    dsrm_password    = random_password.dsrm_password.result
    admin_password   = random_password.admin_password.result
    lowpriv_password = random_password.lowpriv_password.result
  }))

  tags = local.common_tags

  lifecycle {
    ignore_changes = [custom_data]
  }
}

resource "azurerm_virtual_machine_extension" "dc_setup" {
  name                 = "dc-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -EncodedCommand ${base64encode(templatefile("${path.module}/setup.ps1", {
      domain_name      = var.domain_name
      domain_netbios   = var.domain_netbios
      dsrm_password    = random_password.dsrm_password.result
      admin_password   = random_password.admin_password.result
      lowpriv_password = random_password.lowpriv_password.result
    }))}"
  })

  tags = local.common_tags
}

resource "azurerm_public_ip" "workstation" {
  name                = "${local.lab_name}-ws-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "workstation" {
  name                = "${local.lab_name}-ws-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.vnet.public_subnet_ids[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.workstation.id
  }

  dns_servers = [azurerm_network_interface.dc.private_ip_address]

  tags = local.common_tags
}

resource "azurerm_network_interface_security_group_association" "workstation" {
  network_interface_id      = azurerm_network_interface.workstation.id
  network_security_group_id = azurerm_network_security_group.workstation.id
}

resource "azurerm_windows_virtual_machine" "workstation" {
  name                = "${local.lab_name}-ws01"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  admin_password      = random_password.admin_password.result
  network_interface_ids = [azurerm_network_interface.workstation.id]

  os_disk {
    name                 = "${local.lab_name}-ws-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = module.images.windows_server_2022.publisher
    offer     = module.images.windows_server_2022.offer
    sku       = module.images.windows_server_2022.sku
    version   = module.images.windows_server_2022.version
  }

  tags = local.common_tags

  depends_on = [azurerm_virtual_machine_extension.dc_setup]

  lifecycle {
    ignore_changes = [custom_data]
  }
}

resource "azurerm_virtual_machine_extension" "workstation_setup" {
  name                 = "ws-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.workstation.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -EncodedCommand ${base64encode(templatefile("${path.module}/workstation.ps1", {
      domain_name    = var.domain_name
      domain_netbios = var.domain_netbios
      dc_ip          = azurerm_network_interface.dc.private_ip_address
      admin_password = random_password.admin_password.result
    }))}"
  })

  tags = local.common_tags

  depends_on = [azurerm_virtual_machine_extension.dc_setup]
}