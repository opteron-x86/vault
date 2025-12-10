output "ubuntu_22_04" {
  description = "Ubuntu 22.04 LTS image reference"
  value = {
    publisher = data.azurerm_platform_image.ubuntu_22_04.publisher
    offer     = data.azurerm_platform_image.ubuntu_22_04.offer
    sku       = data.azurerm_platform_image.ubuntu_22_04.sku
    version   = data.azurerm_platform_image.ubuntu_22_04.version
  }
}

output "ubuntu_24_04" {
  description = "Ubuntu 24.04 LTS image reference"
  value = {
    publisher = data.azurerm_platform_image.ubuntu_24_04.publisher
    offer     = data.azurerm_platform_image.ubuntu_24_04.offer
    sku       = data.azurerm_platform_image.ubuntu_24_04.sku
    version   = data.azurerm_platform_image.ubuntu_24_04.version
  }
}

output "windows_server_2022" {
  description = "Windows Server 2022 image reference"
  value = {
    publisher = data.azurerm_platform_image.windows_server_2022.publisher
    offer     = data.azurerm_platform_image.windows_server_2022.offer
    sku       = data.azurerm_platform_image.windows_server_2022.sku
    version   = data.azurerm_platform_image.windows_server_2022.version
  }
}

output "windows_server_2019" {
  description = "Windows Server 2019 image reference"
  value = {
    publisher = data.azurerm_platform_image.windows_server_2019.publisher
    offer     = data.azurerm_platform_image.windows_server_2019.offer
    sku       = data.azurerm_platform_image.windows_server_2019.sku
    version   = data.azurerm_platform_image.windows_server_2019.version
  }
}

output "debian_12" {
  description = "Debian 12 image reference"
  value = {
    publisher = data.azurerm_platform_image.debian_12.publisher
    offer     = data.azurerm_platform_image.debian_12.offer
    sku       = data.azurerm_platform_image.debian_12.sku
    version   = data.azurerm_platform_image.debian_12.version
  }
}

output "rhel_9" {
  description = "RHEL 9 image reference"
  value = {
    publisher = data.azurerm_platform_image.rhel_9.publisher
    offer     = data.azurerm_platform_image.rhel_9.offer
    sku       = data.azurerm_platform_image.rhel_9.sku
    version   = data.azurerm_platform_image.rhel_9.version
  }
}