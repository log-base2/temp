variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "location_short" { type = string }
variable "tags" { type = map(string) }
variable "function_subnet_id" { type = string }
variable "storage_account_name" { type = string }
variable "storage_account_primary_access_key" { type = string }
variable "application_insights_connection_string" { type = string }
variable "key_vault_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "function_app_settings" { type = map(string) }
variable "function_app_sku" { type = string }

data "azurerm_client_config" "current" {}

locals {
  app_service_plan_name = "asp-${var.project_name}-${var.environment}-${var.location_short}-001"
  function_app_name     = "func-${var.project_name}-${var.environment}-${var.location_short}-001"
}

# App Service Plan (Premium for VNet integration)
resource "azurerm_service_plan" "main" {
  name                = local.app_service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.function_app_sku
  
  # Zone redundancy for high availability
  zone_balancing_enabled = var.environment == "prod" ? true : false
  
  tags = var.tags
}

# Managed Identity for Function App
resource "azurerm_user_assigned_identity" "function" {
  name                = "id-${local.function_app_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Grant Function App access to Key Vault
resource "azurerm_role_assignment" "function_key_vault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
}

# Linux Function App
resource "azurerm_linux_function_app" "main" {
  name                       = local.function_app_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_primary_access_key
  
  # Managed Identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.function.id]
  }
  
  # VNet Integration
  virtual_network_subnet_id = var.function_subnet_id
  
  # Security settings
  https_only                    = true
  public_network_access_enabled = true # Can be false if using private endpoint
  
  site_config {
    always_on                              = true
    http2_enabled                          = true
    ftps_state                             = "Disabled"
    minimum_tls_version                    = "1.2"
    vnet_route_all_enabled                 = true
    application_insights_connection_string = var.application_insights_connection_string
    
    # Runtime configuration
    application_stack {
      # Adjust based on your runtime
      dotnet_version              = "8.0" # or use python_version, node_version, java_version
      use_dotnet_isolated_runtime = true
    }
    
    # CORS settings
    cors {
      allowed_origins     = []
      support_credentials = false
    }
    
    # IP restrictions can be added here for additional security
    ip_restriction {
      action     = "Deny"
      priority   = 2147483647
      name       = "DenyAll"
      ip_address = "0.0.0.0/0"
    }
  }
  
  # Application settings
  app_settings = merge(
    {
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.application_insights_connection_string
      "AzureWebJobsStorage__accountName"      = var.storage_account_name
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_name};AccountKey=${var.storage_account_primary_access_key};EndpointSuffix=core.windows.net"
      "WEBSITE_CONTENTSHARE"                  = "${local.function_app_name}-content"
      "WEBSITE_ENABLE_SYNC_UPDATE_SITE"       = "true"
      "WEBSITE_RUN_FROM_PACKAGE"              = "1"
      "FUNCTIONS_EXTENSION_VERSION"           = "~4"
      "AZURE_CLIENT_ID"                       = azurerm_user_assigned_identity.function.client_id
      "KEY_VAULT_URI"                         = replace(var.key_vault_id, "/.*/", "")
      "ENVIRONMENT"                           = var.environment
      "SCM_DO_BUILD_DURING_DEPLOYMENT"        = "false"
    },
    var.function_app_settings
  )
  
  tags = var.tags
  
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_CONTENTSHARE"],
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"]
    ]
  }
}

# Diagnostic settings for Function App
resource "azurerm_monitor_diagnostic_setting" "function_app" {
  name                       = "diag-${local.function_app_name}"
  target_resource_id         = azurerm_linux_function_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Autoscale settings
resource "azurerm_monitor_autoscale_setting" "function_app" {
  name                = "autoscale-${local.function_app_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.main.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = 2
      minimum = var.environment == "prod" ? 2 : 1
      maximum = var.environment == "prod" ? 10 : 5
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
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
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
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

# Outputs
output "function_app_id" {
  value = azurerm_linux_function_app.main.id
}

output "function_app_name" {
  value = azurerm_linux_function_app.main.name
}

output "function_app_default_hostname" {
  value = azurerm_linux_function_app.main.default_hostname
}

output "function_app_identity_principal_id" {
  value = azurerm_user_assigned_identity.function.principal_id
}

output "function_app_identity_client_id" {
  value = azurerm_user_assigned_identity.function.client_id
}

output "app_service_plan_id" {
  value = azurerm_service_plan.main.id
}