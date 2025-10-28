variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "location_short" { type = string }
variable "tags" { type = map(string) }
variable "private_endpoint_subnet_id" { type = string }
variable "vnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }

data "azurerm_private_dns_zone" "storage_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "storage_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.resource_group_name
}

locals {
  # Storage account names must be globally unique and lowercase
  function_storage_name = "stfn${var.project_name}${var.environment}${var.location_short}001"
  data_storage_name     = "stda${var.project_name}${var.environment}${var.location_short}001"
}

# Storage Account for Azure Functions
resource "azurerm_storage_account" "function" {
  name                     = substr(replace(local.function_storage_name, "-", ""), 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "ZRS" # Zone-redundant for high availability
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
  
  # Security settings
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true # Required for Function App
  
  # Advanced threat protection
  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }

  # Network rules
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = []
  }

  tags = var.tags
}

# Private Endpoint for Function Storage - Blob
resource "azurerm_private_endpoint" "function_blob" {
  name                = "pe-${substr(replace(local.function_storage_name, "-", ""), 0, 24)}-blob"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${substr(replace(local.function_storage_name, "-", ""), 0, 24)}-blob"
    private_connection_resource_id = azurerm_storage_account.function.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "pdz-group-blob"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.storage_blob.id]
  }
}

# Private Endpoint for Function Storage - File
resource "azurerm_private_endpoint" "function_file" {
  name                = "pe-${substr(replace(local.function_storage_name, "-", ""), 0, 24)}-file"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${substr(replace(local.function_storage_name, "-", ""), 0, 24)}-file"
    private_connection_resource_id = azurerm_storage_account.function.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "pdz-group-file"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.storage_file.id]
  }
}

# Diagnostic settings for Function Storage
resource "azurerm_monitor_diagnostic_setting" "function_storage" {
  name                       = "diag-${substr(replace(local.function_storage_name, "-", ""), 0, 24)}"
  target_resource_id         = azurerm_storage_account.function.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}

# Storage Account for Application Data
resource "azurerm_storage_account" "data" {
  name                     = substr(replace(local.data_storage_name, "-", ""), 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GZRS" # Geo-zone-redundant for DR
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
  
  # Security settings
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # Use managed identity
  
  # Identity for cross-region replication
  identity {
    type = "SystemAssigned"
  }
  
  # Advanced threat protection
  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    
    delete_retention_policy {
      days = 90
    }
    
    container_delete_retention_policy {
      days = 90
    }
    
    # Immutability for compliance
    last_access_time_enabled = true
  }

  # Network rules
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = []
  }

  tags = var.tags
}

# Private Endpoint for Data Storage - Blob
resource "azurerm_private_endpoint" "data_blob" {
  name                = "pe-${substr(replace(local.data_storage_name, "-", ""), 0, 24)}-blob"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${substr(replace(local.data_storage_name, "-", ""), 0, 24)}-blob"
    private_connection_resource_id = azurerm_storage_account.data.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "pdz-group-blob"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.storage_blob.id]
  }
}

# Diagnostic settings for Data Storage
resource "azurerm_monitor_diagnostic_setting" "data_storage" {
  name                       = "diag-${substr(replace(local.data_storage_name, "-", ""), 0, 24)}"
  target_resource_id         = azurerm_storage_account.data.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}

# Lifecycle Management Policy for Data Storage
resource "azurerm_storage_management_policy" "data" {
  storage_account_id = azurerm_storage_account.data.id

  rule {
    name    = "archiveOldData"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 90
        tier_to_archive_after_days_since_modification_greater_than = 365
      }
      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }
    }
  }
}

# Outputs
output "function_storage_account_id" {
  value = azurerm_storage_account.function.id
}

output "function_storage_account_name" {
  value = azurerm_storage_account.function.name
}

output "function_storage_primary_access_key" {
  value     = azurerm_storage_account.function.primary_access_key
  sensitive = true
}

output "function_storage_primary_connection_string" {
  value     = azurerm_storage_account.function.primary_connection_string
  sensitive = true
}

output "data_storage_account_id" {
  value = azurerm_storage_account.data.id
}

output "data_storage_account_name" {
  value = azurerm_storage_account.data.name
}