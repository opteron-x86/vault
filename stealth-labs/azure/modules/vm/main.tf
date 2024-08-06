resource "azurerm_linux_virtual_machine" "attacker_vm" {
  name                  = var.attacker_vm_name
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.instance_type_attacker
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.attacker_vm_nic.id]
  disable_password_authentication = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.volume_size_attacker
  }

  source_image_reference {
    publisher = "kali-linux"
    offer     = "kali"
    sku       = "kali"
    version   = "latest"
  }

  tags = {
    Name = var.attacker_vm_name
  }
}

resource "tls_private_key" "target_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurerm_ssh_public_key" "target_key_pair" {
  name                = "target-key-pair"
  resource_group_name = var.resource_group_name
  location            = var.location
  public_key          = tls_private_key.target_key.public_key_openssh
}

resource "azurerm_linux_virtual_machine" "target_vm" {
  name                  = var.target_vm_name
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.instance_type_target
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.target_vm_nic.id]
  disable_password_authentication = false
  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.target_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.volume_size_target
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = var.user_data

  tags = {
    Name = var.target_vm_name
  }

  identity {
    type = "UserAssigned"
    identity_ids = [var.identity_ids]
  }
}

resource "azurerm_managed_disk" "target_disk" {
  name                 = "target-disk-${var.lab_name}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 8  # Adjust size as needed
}

resource "azurerm_virtual_machine_data_disk_attachment" "target_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.target_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.target_vm.id
  lun                = 0
  caching            = "ReadWrite"
}
