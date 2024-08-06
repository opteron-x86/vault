# Attacker VNet resources
resource "azurerm_virtual_network" "vnet_attacker" {
  name                = var.vpc_name_attacker
  address_space       = [var.cidr_block_attacker]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    Name = var.vpc_name_attacker
  }
}

resource "azurerm_subnet" "public_subnet_attacker" {
  name                 = "${var.vpc_name_attacker}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_attacker.name
  address_prefixes     = [var.public_subnet_attacker]
}

resource "azurerm_public_ip" "attacker" {
  name                = "${var.vpc_name_attacker}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "attacker" {
  name                = "${var.vpc_name_attacker}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet_attacker.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.attacker.id
  }
}

resource "azurerm_network_security_group" "attacker" {
  name                = "${var.vpc_name_attacker}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowInternetOutBound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "attacker" {
  network_interface_id      = azurerm_network_interface.attacker.id
  network_security_group_id = azurerm_network_security_group.attacker.id
}

# Target VNet resources
resource "azurerm_virtual_network" "vnet_target" {
  name                = var.vpc_name_target
  address_space       = [var.cidr_block_target]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    Name = var.vpc_name_target
  }
}

resource "azurerm_subnet" "public_subnet_target" {
  name                 = "${var.vpc_name_target}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_target.name
  address_prefixes     = [var.public_subnet_target]
}

resource "azurerm_public_ip" "target" {
  name                = "${var.vpc_name_target}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "target" {
  name                = "${var.vpc_name_target}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnet_target.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.target.id
  }
}

resource "azurerm_network_security_group" "target" {
  name                = "${var.vpc_name_target}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowInternetOutBound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "target" {
  network_interface_id      = azurerm_network_interface.target.id
  network_security_group_id = azurerm_network_security_group.target.id
}
