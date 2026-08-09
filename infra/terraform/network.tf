resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  name_prefix = "${var.project}-${var.environment}"
}

data "azurerm_resource_group" "main" {
  name = var.existing_resource_group_name
}

data "azurerm_virtual_network" "main" {
  name                = var.existing_vnet_name
  resource_group_name = coalesce(var.existing_vnet_resource_group_name, data.azurerm_resource_group.main.name)
}

resource "azurerm_subnet" "frontend" {
  name                 = "snet-frontend-${local.name_prefix}"
  resource_group_name  = data.azurerm_virtual_network.main.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  address_prefixes     = var.frontend_subnet_prefix
}

resource "azurerm_subnet" "backend" {
  name                 = "snet-backend-${local.name_prefix}"
  resource_group_name  = data.azurerm_virtual_network.main.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  address_prefixes     = var.backend_subnet_prefix
}

# --- Frontend NSG: only 80 from the Internet, plus the ports Azure needs for LB health probes ---
resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-frontend-${local.name_prefix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  tags                = var.tags

  security_rule {
    name                       = "Allow-HTTP-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-AzureLoadBalancer-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

# --- Backend NSG: only 8000 from the frontend subnet, no direct Internet exposure ---
resource "azurerm_network_security_group" "backend" {
  name                = "nsg-backend-${local.name_prefix}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  tags                = var.tags

  security_rule {
    name                       = "Allow-Frontend-Subnet-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = var.frontend_subnet_prefix[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-AzureLoadBalancer-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "frontend" {
  subnet_id                 = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend.id
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}
