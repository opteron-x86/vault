data "azurerm_platform_image" "ubuntu_22_04" {
  location  = var.location
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-gen2"
}

data "azurerm_platform_image" "ubuntu_24_04" {
  location  = var.location
  publisher = "Canonical"
  offer     = "ubuntu-24_04-lts"
  sku       = "server"
}

data "azurerm_platform_image" "windows_server_2022" {
  location  = var.location
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2022-datacenter-g2"
}

data "azurerm_platform_image" "windows_server_2019" {
  location  = var.location
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2019-datacenter-gensecond"
}

data "azurerm_platform_image" "debian_12" {
  location  = var.location
  publisher = "Debian"
  offer     = "debian-12"
  sku       = "12-gen2"
}

data "azurerm_platform_image" "rhel_9" {
  location  = var.location
  publisher = "RedHat"
  offer     = "RHEL"
  sku       = "9-lvm-gen2"
}