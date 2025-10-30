variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "location_short" { type = string }
variable "region_name" { type = string }
variable "tags" { type = map(string) }
variable "app_service_subnet_id" { type = string }
variable "sku_name" { type = string }
variable "zone_balancing_enabled" { type = bool }
variable "availability_zones" { type = list(string) }
variable "application_insights_connection_string" { type = string }
variable "key_vault_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "app_settings" { type = map(string) }

data "azurerm_client_config" "current" {}

locals {
  app_service_plan_name = "asp-${var.project_name}-${var.environment}-${var.location_short}-001"
  app_service_name      = "app-${var.project_name}-${var.environment}-${var.location_short}-001"
}

# App Service Plan with Zone Redundancy
resource "azurerm_service_plan" "main" {
  name                   = local.app_service_plan_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  os_type                = "Linux"  # Change to "Windows" if needed
  sku_name               = var.sku_name
  zone_balancing_enabled = var.zone_balancing_enabled
  
  tags = var.tags
}

# Managed Identity for App Service
resource "azurerm_user_assigned_identity" "app_service" {
  name                = "id-${local.app_service_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Grant App Service access to Key Vault
resource "azurerm_role_assignment" "app_service_key_vault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app_service.principal_id
}

# Linux App Service
resource "azurerm_linux_web_app" "main" {
  name                      = local.app_service_name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  service_plan_id           = azurerm_service_plan.main.id
  virtual_network_subnet_id = var.app_service_subnet_id
  https_only                = true
  
  # Zone redundancy
  zone_redundant = var.zone_balancing_enabled
  
  # Managed Identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_service.id]
  }
  
  site_config {
    always_on                              = true
    http2_enabled                          = true
    ftps_state                             = "Disabled"
    minimum_tls_version                    = "1.2"
    vnet_route_all_enabled                 = true
    application_insights_connection_string = var.application_insights_connection_string
    
    # Runtime configuration - adjust based on your application
    application_stack {
      dotnet_version = "8.0"  # or use python_version, node_version, java_version
    }
    
    # Health check endpoint (required for Traffic Manager)
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 2
    
    # CORS settings
    cors {
      allowed_origins     = []
      support_credentials = false
    }
  }
  
  # Application settings
  app_settings = merge(
    {
      "APPLICATIONINSIGHTS_CONNECTION_STRING"  = var.application_insights_connection_string
      "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
      "WEBSITE_ENABLE_SYNC_UPDATE_SITE"        = "true"
      "WEBSITE_RUN_FROM_PACKAGE"               = "1"
      "AZURE_CLIENT_ID"                        = azurerm_user_assigned_identity.app_service.client_id
      "KEY_VAULT_URI"                          = replace(var.key_vault_id, "/.*//", "https://") # Extract URI from ID
      "ENVIRONMENT"                            = var.environment
      "REGION"                                 = var.region_name
      "SCM_DO_BUILD_DURING_DEPLOYMENT"         = "false"
    },
    var.app_settings
  )
  
  # Connection strings can be added if needed
  # connection_string {
  #   name  = "Database"
  #   type  = "SQLAzure"
  #   value = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/connection-string/)"
  # }
  
  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
    
    application_logs {
      file_system_level = "Information"
    }
    
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }
  
  tags = var.tags
  
  lifecycle {
    ignore_changes = [
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"]
    ]
  }
}

# Diagnostic settings for App Service
resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-${local.app_service_name}"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  enabled_log {
    category = "AppServicePlatformLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Autoscale settings
resource "azurerm_monitor_autoscale_setting" "app_service" {
  name                = "autoscale-${local.app_service_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.main.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = length(var.availability_zones)  # One instance per zone
      minimum = length(var.availability_zones)  # Minimum one per zone
      maximum = length(var.availability_zones) * 5  # Max 5 instances per zone
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "3"  # Scale 3 at a time (one per zone)
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "3"  # Scale down 3 at a time (one per zone)
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "MemoryPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "3"
        cooldown  = "PT5M"
      }
    }
  }
}

# Outputs
output "app_service_id" {
  value = azurerm_linux_web_app.main.id
}

output "app_service_name" {
  value = azurerm_linux_web_app.main.name
}

output "app_service_default_hostname" {
  value = azurerm_linux_web_app.main.default_hostname
}

output "app_service_identity_principal_id" {
  value = azurerm_user_assigned_identity.app_service.principal_id
}

output "app_service_identity_client_id" {
  value = azurerm_user_assigned_identity.app_service.client_id
}

output "app_service_plan_id" {
  value = azurerm_service_plan.main.id
}