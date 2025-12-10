resource "azurerm_public_ip" "vm" {
  count = var.assign_public_ip ? 1 : 0

  name                = "${var.name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_network_interface" "vm" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.vm[0].id : null
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "vm" {
  count = var.associate_nsg ? 1 : 0

  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = var.network_security_group_id
}

resource "azurerm_linux_virtual_machine" "vm" {
  count = var.os_type == "linux" ? 1 : 0

  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = var.ssh_public_key != null
  admin_password                  = var.ssh_public_key == null ? var.admin_password : null
  network_interface_ids           = [azurerm_network_interface.vm.id]
  custom_data                     = var.custom_data

  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_key != null ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }

  os_disk {
    name                 = "${var.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.source_image.publisher
    offer     = var.source_image.offer
    sku       = var.source_image.sku
    version   = var.source_image.version
  }

  dynamic "identity" {
    for_each = var.enable_system_identity || length(var.user_assigned_identity_ids) > 0 ? [1] : []
    content {
      type         = var.enable_system_identity && length(var.user_assigned_identity_ids) > 0 ? "SystemAssigned, UserAssigned" : var.enable_system_identity ? "SystemAssigned" : "UserAssigned"
      identity_ids = length(var.user_assigned_identity_ids) > 0 ? var.user_assigned_identity_ids : null
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [custom_data]
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  count = var.os_type == "windows" ? 1 : 0

  name                  = var.name
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.vm.id]
  custom_data           = var.custom_data

  os_disk {
    name                 = "${var.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.source_image.publisher
    offer     = var.source_image.offer
    sku       = var.source_image.sku
    version   = var.source_image.version
  }

  dynamic "identity" {
    for_each = var.enable_system_identity || length(var.user_assigned_identity_ids) > 0 ? [1] : []
    content {
      type         = var.enable_system_identity && length(var.user_assigned_identity_ids) > 0 ? "SystemAssigned, UserAssigned" : var.enable_system_identity ? "SystemAssigned" : "UserAssigned"
      identity_ids = length(var.user_assigned_identity_ids) > 0 ? var.user_assigned_identity_ids : null
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [custom_data]
  }
}