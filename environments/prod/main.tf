terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-prod"
    storage_account_name = "sttfstateprod001"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azuread" {}

# Data sources
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Local variables
locals {
  environment         = "prod"
  location            = var.location
  location_short      = var.location_short
  project_name        = var.project_name
  common_tags = {
    Environment        = local.environment
    Project           = local.project_name
    ManagedBy         = "Terraform"
    ComplianceLevel   = "Medical-Device"
    DataClassification = "HealthData"
    CostCenter        = var.cost_center
  }
  
  # Naming convention: {resource-type}-{project}-{environment}-{region}-{instance}
  resource_group_name = "rg-${local.project_name}-${local.environment}-${local.location_short}-001"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags
}

# Networking Module
module "networking" {
  source = "../../modules/networking"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  environment        = local.environment
  project_name       = local.project_name
  location_short     = local.location_short
  tags               = local.common_tags
  
  vnet_address_space           = var.vnet_address_space
  subnet_function_address      = var.subnet_function_address
  subnet_container_address     = var.subnet_container_address
  subnet_private_endpoint_address = var.subnet_private_endpoint_address
  subnet_gateway_address       = var.subnet_gateway_address
  
  enable_ddos_protection = var.enable_ddos_protection
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  environment        = local.environment
  project_name       = local.project_name
  location_short     = local.location_short
  tags               = local.common_tags
  
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id   = module.networking.private_endpoint_subnet_id
  vnet_id                      = module.networking.vnet_id
  
  key_vault_admin_object_ids   = var.key_vault_admin_object_ids
  log_analytics_workspace_id   = module.monitoring.log_analytics_workspace_id
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  environment        = local.environment
  project_name       = local.project_name
  location_short     = local.location_short
  tags               = local.common_tags
  
  retention_in_days = var.log_retention_days
  alert_email_addresses = var.alert_email_addresses
}

# Storage Module (for Function App and general storage needs)
module "storage" {
  source = "../../modules/storage"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  environment        = local.environment
  project_name       = local.project_name
  location_short     = local.location_short
  tags               = local.common_tags
  
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  vnet_id                    = module.networking.vnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

# Azure Functions Module
module "azure_functions" {
  source = "../../modules/azure-functions"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  environment        = local.environment
  project_name       = local.project_name
  location_short     = local.location_short
  tags               = local.common_tags
  
  function_subnet_id              = module.networking.function_subnet_id
  storage_account_name            = module.storage.function_storage_account_name
  storage_account_primary_access_key = module.storage.function_storage_primary_access_key
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  key_vault_id                    = module.security.key_vault_id
  log_analytics_workspace_id      = module.monitoring.log_analytics_workspace_id
  
  function_app_settings = var.function_app_settings
  function_app_sku      = var.function_app_sku
}

# Container Apps Module (optional - can be enabled/disabled)
module "container_apps" {
  source = "../../modules/container-apps"
  count  = var.enable_container_apps ? 1 : 0
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  environment        = local.environment
  project_name       = local.project_name
  location_short     = local.location_short
  tags               = local.common_tags
  
  container_subnet_id                     = module.networking.container_subnet_id
  log_analytics_workspace_id              = module.monitoring.log_analytics_workspace_id
  application_insights_connection_string  = module.monitoring.application_insights_connection_string
  key_vault_id                            = module.security.key_vault_id
  
  container_apps = var.container_apps
}

# Azure Policy Assignments
module "policy" {
  source = "../../modules/policy"
  
  resource_group_id = azurerm_resource_group.main.id
  environment       = local.environment
  location          = local.location
}

# Outputs
output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "The name of the resource group"
}

output "vnet_id" {
  value       = module.networking.vnet_id
  description = "The ID of the virtual network"
}

output "key_vault_name" {
  value       = module.security.key_vault_name
  description = "The name of the Key Vault"
}

output "key_vault_uri" {
  value       = module.security.key_vault_uri
  description = "The URI of the Key Vault"
}

output "function_app_name" {
  value       = module.azure_functions.function_app_name
  description = "The name of the Function App"
}

output "function_app_default_hostname" {
  value       = module.azure_functions.function_app_default_hostname
  description = "The default hostname of the Function App"
}

output "function_app_identity_principal_id" {
  value       = module.azure_functions.function_app_identity_principal_id
  description = "The principal ID of the Function App managed identity"
}

output "container_app_fqdns" {
  value       = var.enable_container_apps ? module.container_apps[0].container_app_fqdns : {}
  description = "The FQDNs of the Container Apps"
}

output "application_insights_instrumentation_key" {
  value       = module.monitoring.application_insights_instrumentation_key
  description = "Application Insights instrumentation key"
  sensitive   = true
}

output "application_insights_connection_string" {
  value       = module.monitoring.application_insights_connection_string
  description = "Application Insights connection string"
  sensitive   = true
}

output "log_analytics_workspace_id" {
  value       = module.monitoring.log_analytics_workspace_id
  description = "The ID of the Log Analytics workspace"
}