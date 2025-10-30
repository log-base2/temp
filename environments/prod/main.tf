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
  environment    = "prod"
  project_name   = var.project_name
  
  # Define regions for deployment
  regions = {
    primary = {
      location       = var.primary_region
      location_short = var.primary_region_short
      priority       = 1
    }
    secondary = {
      location       = var.secondary_region
      location_short = var.secondary_region_short
      priority       = 2
    }
  }
  
  common_tags = {
    Environment        = local.environment
    Project           = local.project_name
    ManagedBy         = "Terraform"
    ComplianceLevel   = "Medical-Device"
    DataClassification = "HealthData"
    CostCenter        = var.cost_center
  }
}

# Global Resource Group for Traffic Manager
resource "azurerm_resource_group" "global" {
  name     = "rg-${local.project_name}-${local.environment}-global-001"
  location = local.regions.primary.location
  tags     = local.common_tags
}

# Deploy Regional Infrastructure
module "region" {
  source   = "../../modules/regional-deployment"
  for_each = local.regions
  
  environment        = local.environment
  project_name       = local.project_name
  location           = each.value.location
  location_short     = each.value.location_short
  region_name        = each.key
  tags               = local.common_tags
  
  # Networking
  vnet_address_space              = var.regional_vnet_address_spaces[each.key]
  subnet_app_service_address      = var.regional_subnet_app_service[each.key]
  subnet_private_endpoint_address = var.regional_subnet_private_endpoint[each.key]
  subnet_gateway_address          = var.regional_subnet_gateway[each.key]
  
  # App Service
  app_service_sku_name            = var.app_service_sku_name
  availability_zones              = var.availability_zones
  app_service_settings            = var.app_service_settings
  
  # Security
  key_vault_admin_object_ids = var.key_vault_admin_object_ids
  
  # Monitoring
  log_retention_days     = var.log_retention_days
  alert_email_addresses  = var.alert_email_addresses
  
  # Global resources for linking
  global_resource_group_name = azurerm_resource_group.global.name
}

# Traffic Manager for Cross-Region Load Balancing
module "traffic_manager" {
  source = "../../modules/traffic-manager"
  
  environment              = local.environment
  project_name             = local.project_name
  resource_group_name      = azurerm_resource_group.global.name
  tags                     = local.common_tags
  
  # Regional endpoints
  regional_endpoints = {
    for region_key, region in module.region : region_key => {
      target_resource_id = region.app_gateway_public_ip_id
      priority           = local.regions[region_key].priority
      location           = local.regions[region_key].location
    }
  }
  
  traffic_routing_method = var.traffic_routing_method
  monitor_protocol       = var.traffic_manager_monitor_protocol
  monitor_port           = var.traffic_manager_monitor_port
  monitor_path           = var.traffic_manager_monitor_path
}

# Global Monitoring Dashboard
resource "azurerm_portal_dashboard" "global" {
  name                = "dash-${local.project_name}-${local.environment}-global"
  resource_group_name = azurerm_resource_group.global.name
  location            = azurerm_resource_group.global.location
  tags                = local.common_tags
  
  dashboard_properties = templatefile("${path.module}/dashboard.tpl.json", {
    primary_app_insights_id   = module.region["primary"].application_insights_id
    secondary_app_insights_id = module.region["secondary"].application_insights_id
    traffic_manager_id        = module.traffic_manager.traffic_manager_profile_id
  })
}

# Outputs
output "traffic_manager_fqdn" {
  value       = module.traffic_manager.traffic_manager_fqdn
  description = "The FQDN of the Traffic Manager profile - use this as your application endpoint"
}

output "primary_region" {
  value = {
    resource_group_name       = module.region["primary"].resource_group_name
    app_service_name          = module.region["primary"].app_service_name
    app_service_default_hostname = module.region["primary"].app_service_default_hostname
    app_gateway_public_ip     = module.region["primary"].app_gateway_public_ip_address
    key_vault_name            = module.region["primary"].key_vault_name
  }
  description = "Primary region infrastructure outputs"
}

output "secondary_region" {
  value = {
    resource_group_name       = module.region["secondary"].resource_group_name
    app_service_name          = module.region["secondary"].app_service_name
    app_service_default_hostname = module.region["secondary"].app_service_default_hostname
    app_gateway_public_ip     = module.region["secondary"].app_gateway_public_ip_address
    key_vault_name            = module.region["secondary"].key_vault_name
  }
  description = "Secondary region infrastructure outputs"
}

output "deployment_endpoints" {
  value = {
    for region_key, region in module.region : region_key => {
      app_service_name = region.app_service_name
      deployment_url   = "https://${region.app_service_default_hostname}"
    }
  }
  description = "App Service names and URLs for each region for deployment"
}

output "application_insights" {
  value = {
    for region_key, region in module.region : region_key => {
      instrumentation_key = region.application_insights_instrumentation_key
      connection_string   = region.application_insights_connection_string
    }
  }
  sensitive   = true
  description = "Application Insights details per region"
}