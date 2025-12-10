resource "azurerm_virtual_network" "lab" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vnet"
  })
}

resource "azurerm_subnet" "public" {
  count = var.subnet_count

  name                 = "${var.name_prefix}-public-${count.index}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, count.index)]
}

resource "azurerm_subnet" "private" {
  count = var.enable_private_subnets ? var.subnet_count : 0

  name                 = "${var.name_prefix}-private-${count.index}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, count.index + 100)]
}

resource "azurerm_public_ip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "${var.name_prefix}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_nat_gateway" "lab" {
  count = var.enable_nat_gateway ? 1 : 0

  name                = "${var.name_prefix}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"

  tags = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "lab" {
  count = var.enable_nat_gateway ? 1 : 0

  nat_gateway_id       = azurerm_nat_gateway.lab[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  count = var.enable_nat_gateway && var.enable_private_subnets ? var.subnet_count : 0

  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.lab[0].id
}

resource "azurerm_network_security_group" "ssh" {
  count = var.create_ssh_nsg ? 1 : 0

  name                = "${var.name_prefix}-ssh-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_ssh_cidrs
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ssh-nsg"
  })
}

resource "azurerm_network_security_group" "rdp" {
  count = var.create_rdp_nsg ? 1 : 0

  name                = "${var.name_prefix}-rdp-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.allowed_rdp_cidrs
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "WinRM-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefixes    = var.allowed_rdp_cidrs
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "WinRM-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefixes    = var.allowed_rdp_cidrs
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rdp-nsg"
  })
}

resource "azurerm_network_security_group" "web" {
  count = var.create_web_nsg ? 1 : 0

  name                = "${var.name_prefix}-web-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = { for idx, port in var.web_ports : idx => port }
    content {
      name                       = "Port-${security_rule.value}"
      priority                   = 100 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value)
      source_address_prefixes    = var.allowed_web_cidrs
      destination_address_prefix = "*"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-web-nsg"
  })
}