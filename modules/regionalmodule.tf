variable "environment" { type = string }
variable "project_name" { type = string }
variable "location" { type = string }
variable "location_short" { type = string }
variable "region_name" { type = string }
variable "tags" { type = map(string) }
variable "vnet_address_space" { type = list(string) }
variable "subnet_app_service_address" { type = list(string) }
variable "subnet_private_endpoint_address" { type = list(string) }
variable "subnet_gateway_address" { type = list(string) }
variable "app_service_sku_name" { type = string }
variable "availability_zones" { type = list(string) }
variable "app_service_settings" { type = map(string) }
variable "key_vault_admin_object_ids" { type = list(string) }
variable "log_retention_days" { type = number }
variable "alert_email_addresses" { type = list(string) }
variable "global_resource_group_name" { type = string }

data "azurerm_client_config" "current" {}

locals {
  resource_group_name = "rg-${var.project_name}-${var.environment}-${var.location_short}-001"
  regional_tags = merge(
    var.tags,
    {
      Region = var.region_name
    }
  )
}

# Regional Resource Group
resource "azurerm_resource_group" "regional" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.regional_tags
}

# Networking Module
module "networking" {
  source = "../networking-regional"
  
  resource_group_name             = azurerm_resource_group.regional.name
  location                        = azurerm_resource_group.regional.location
  environment                     = var.environment
  project_name                    = var.project_name
  location_short                  = var.location_short
  region_name                     = var.region_name
  tags                            = local.regional_tags
  vnet_address_space              = var.vnet_address_space
  subnet_app_service_address      = var.subnet_app_service_address
  subnet_private_endpoint_address = var.subnet_private_endpoint_address
  subnet_gateway_address          = var.subnet_gateway_address
}

# Monitoring Module
module "monitoring" {
  source = "../monitoring"
  
  resource_group_name   = azurerm_resource_group.regional.name
  location              = azurerm_resource_group.regional.location
  environment           = var.environment
  project_name          = var.project_name
  location_short        = var.location_short
  tags                  = local.regional_tags
  retention_in_days     = var.log_retention_days
  alert_email_addresses = var.alert_email_addresses
}

# Security Module
module "security" {
  source = "../security"
  
  resource_group_name        = azurerm_resource_group.regional.name
  location                   = azurerm_resource_group.regional.location
  environment                = var.environment
  project_name               = var.project_name
  location_short             = var.location_short
  tags                       = local.regional_tags
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  vnet_id                    = module.networking.vnet_id
  key_vault_admin_object_ids = var.key_vault_admin_object_ids
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

# Storage Module
module "storage" {
  source = "../storage"
  
  resource_group_name        = azurerm_resource_group.regional.name
  location                   = azurerm_resource_group.regional.location
  environment                = var.environment
  project_name               = var.project_name
  location_short             = var.location_short
  tags                       = local.regional_tags
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  vnet_id                    = module.networking.vnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

# App Service Module
module "app_service" {
  source = "../app-service"
  
  resource_group_name                = azurerm_resource_group.regional.name
  location                           = azurerm_resource_group.regional.location
  environment                        = var.environment
  project_name                       = var.project_name
  location_short                     = var.location_short
  region_name                        = var.region_name
  tags                               = local.regional_tags
  app_service_subnet_id              = module.networking.app_service_subnet_id
  sku_name                           = var.app_service_sku_name
  zone_balancing_enabled             = true
  availability_zones                 = var.availability_zones
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  key_vault_id                       = module.security.key_vault_id
  log_analytics_workspace_id         = module.monitoring.log_analytics_workspace_id
  app_settings                       = var.app_service_settings
}

# Application Gateway (Load Balancer) Module
module "app_gateway" {
  source = "../application-gateway"
  
  resource_group_name        = azurerm_resource_group.regional.name
  location                   = azurerm_resource_group.regional.location
  environment                = var.environment
  project_name               = var.project_name
  location_short             = var.location_short
  region_name                = var.region_name
  tags                       = local.regional_tags
  gateway_subnet_id          = module.networking.gateway_subnet_id
  app_service_fqdn           = module.app_service.app_service_default_hostname
  key_vault_id               = module.security.key_vault_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  availability_zones         = var.availability_zones
}

# Policy Module
module "policy" {
  source = "../policy"
  
  resource_group_id = azurerm_resource_group.regional.id
  environment       = var.environment
  location          = var.location
}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.regional.name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "app_service_name" {
  value = module.app_service.app_service_name
}

output "app_service_default_hostname" {
  value = module.app_service.app_service_default_hostname
}

output "app_service_identity_principal_id" {
  value = module.app_service.app_service_identity_principal_id
}

output "app_gateway_public_ip_id" {
  value = module.app_gateway.public_ip_id
}

output "app_gateway_public_ip_address" {
  value = module.app_gateway.public_ip_address
}

output "app_gateway_fqdn" {
  value = module.app_gateway.public_ip_fqdn
}

output "key_vault_name" {
  value = module.security.key_vault_name
}

output "key_vault_uri" {
  value = module.security.key_vault_uri
}

output "application_insights_id" {
  value = module.monitoring.application_insights_id
}

output "application_insights_instrumentation_key" {
  value     = module.monitoring.application_insights_instrumentation_key
  sensitive = true
}

output "application_insights_connection_string" {
  value     = module.monitoring.application_insights_connection_string
  sensitive = true
}

output "log_analytics_workspace_id" {
  value = module.monitoring.log_analytics_workspace_id
}