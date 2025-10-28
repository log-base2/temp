variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "location_short" { type = string }
variable "tags" { type = map(string) }
variable "tenant_id" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "vnet_id" { type = string }
variable "key_vault_admin_object_ids" { type = list(string) }
variable "log_analytics_workspace_id" { type = string }

data "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

locals {
  key_vault_name = "kv-${var.project_name}-${var.environment}-${var.location_short}"
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                       = local.key_vault_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = var.tenant_id
  sku_name                   = "premium" # HSM-backed keys for medical device
  soft_delete_retention_days = 90
  purge_protection_enabled   = true # Critical for compliance - prevents permanent deletion
  
  # Network rules - deny public access
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  # Enable audit logging
  enable_rbac_authorization = true

  tags = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-${local.key_vault_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "pdz-group-kv"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.key_vault.id]
  }
}

# RBAC role assignments for Key Vault administrators
resource "azurerm_role_assignment" "key_vault_admin" {
  count                = length(var.key_vault_admin_object_ids)
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.key_vault_admin_object_ids[count.index]
}

# Diagnostic settings for Key Vault
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-${local.key_vault_name}"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# User Assigned Managed Identity for applications
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Grant the managed identity access to Key Vault
resource "azurerm_role_assignment" "app_key_vault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Outputs
output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.app.id
}

output "managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.app.principal_id
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.app.client_id
}