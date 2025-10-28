variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "location_short" { type = string }
variable "tags" { type = map(string) }
variable "vnet_address_space" { type = list(string) }
variable "subnet_function_address" { type = list(string) }
variable "subnet_container_address" { type = list(string) }
variable "subnet_private_endpoint_address" { type = list(string) }
variable "subnet_gateway_address" { type = list(string) }
variable "enable_ddos_protection" { type = bool }

locals {
  vnet_name = "vnet-${var.project_name}-${var.environment}-${var.location_short}-001"
}

# DDoS Protection Plan (for production medical device compliance)
resource "azurerm_network_ddos_protection_plan" "main" {
  count               = var.enable_ddos_protection ? 1 : 0
  name                = "ddos-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  tags                = var.tags

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.main[0].id
      enable = true
    }
  }
}

# Network Security Group for Function Apps
resource "azurerm_network_security_group" "function" {
  name                = "nsg-function-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # Allow outbound to Azure services
  security_rule {
    name                       = "AllowAzureServicesOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "445"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
  }

  # Deny all inbound by default (Functions are outbound only)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Security Group for Container Apps
resource "azurerm_network_security_group" "container" {
  name                = "nsg-container-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # Allow Container Apps infrastructure traffic
  security_rule {
    name                       = "AllowContainerAppsInfraInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureCloud"
    destination_address_prefix = "*"
  }

  # Allow HTTPS inbound
  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Security Group for Private Endpoints
resource "azurerm_network_security_group" "private_endpoint" {
  name                = "nsg-pe-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # Allow inbound from VNet
  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# Subnet for Function Apps
resource "azurerm_subnet" "function" {
  name                 = "snet-function-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_function_address

  delegation {
    name = "function-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action"
      ]
    }
  }

  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.Web"
  ]
}

resource "azurerm_subnet_network_security_group_association" "function" {
  subnet_id                 = azurerm_subnet.function.id
  network_security_group_id = azurerm_network_security_group.function.id
}

# Subnet for Container Apps
resource "azurerm_subnet" "container" {
  name                 = "snet-container-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_container_address

  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault"
  ]
}

resource "azurerm_subnet_network_security_group_association" "container" {
  subnet_id                 = azurerm_subnet.container.id
  network_security_group_id = azurerm_network_security_group.container.id
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "private_endpoint" {
  name                 = "snet-pe-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_private_endpoint_address
}

resource "azurerm_subnet_network_security_group_association" "private_endpoint" {
  subnet_id                 = azurerm_subnet.private_endpoint.id
  network_security_group_id = azurerm_network_security_group.private_endpoint.id
}

# Subnet for Application Gateway (future use)
resource "azurerm_subnet" "gateway" {
  name                 = "snet-gateway-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_gateway_address
}

# NAT Gateway for secure outbound traffic
resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  name                = "ng-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "function" {
  subnet_id      = azurerm_subnet.function.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# Private DNS Zones for Private Endpoints
resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "vnet-link-kv"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_blob" {
  name                  = "vnet-link-blob"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage_blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "storage_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_file" {
  name                  = "vnet-link-file"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage_file.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# Outputs
output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "function_subnet_id" {
  value = azurerm_subnet.function.id
}

output "container_subnet_id" {
  value = azurerm_subnet.container.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoint.id
}

output "gateway_subnet_id" {
  value = azurerm_subnet.gateway.id
}

output "private_dns_zone_key_vault_id" {
  value = azurerm_private_dns_zone.key_vault.id
}

output "private_dns_zone_storage_blob_id" {
  value = azurerm_private_dns_zone.storage_blob.id
}

output "private_dns_zone_storage_file_id" {
  value = azurerm_private_dns_zone.storage_file.id
}