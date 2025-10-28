variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "location_short" { type = string }
variable "tags" { type = map(string) }
variable "retention_in_days" { type = number }
variable "alert_email_addresses" { type = list(string) }

locals {
  log_analytics_name      = "log-${var.project_name}-${var.environment}-${var.location_short}-001"
  app_insights_name       = "appi-${var.project_name}-${var.environment}-${var.location_short}-001"
  action_group_name       = "ag-${var.project_name}-${var.environment}-${var.location_short}-001"
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days # 7+ years for medical device compliance
  tags                = var.tags

  # Enable data export for long-term archival
  daily_quota_gb = -1 # Unlimited
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = local.app_insights_name
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
  retention_in_days   = var.retention_in_days
  tags                = var.tags

  # Disable sampling for complete audit trail
  sampling_percentage = 100
}

# Action Group for Alerts
resource "azurerm_monitor_action_group" "main" {
  name                = local.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = var.environment
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_email_addresses
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# Alert: High Error Rate
resource "azurerm_monitor_metric_alert" "high_error_rate" {
  name                = "alert-high-error-rate-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when error rate exceeds threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "exceptions/count"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Alert: High Response Time
resource "azurerm_monitor_metric_alert" "high_response_time" {
  name                = "alert-high-response-time-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when response time exceeds threshold"
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5000 # 5 seconds
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Alert: Failed Requests
resource "azurerm_monitor_metric_alert" "failed_requests" {
  name                = "alert-failed-requests-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Alert when failed requests exceed threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Security Alert: Suspicious Activity Query
resource "azurerm_log_analytics_query_pack_query" "suspicious_activity" {
  query_pack_id = azurerm_log_analytics_query_pack.main.id
  body          = <<-QUERY
    SecurityEvent
    | where TimeGenerated > ago(1h)
    | where EventID in (4625, 4648, 4719, 4720, 4722, 4723, 4724, 4725, 4726, 4738, 4740, 4767, 4768, 4771, 4776, 4778, 4779)
    | summarize count() by EventID, Account, Computer
    | where count_ > 5
  QUERY
  display_name  = "Suspicious Security Events"
  description   = "Detects suspicious security events (failed logins, privilege escalations)"
}

resource "azurerm_log_analytics_query_pack" "main" {
  name                = "qp-${var.project_name}-${var.environment}-${var.location_short}-001"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Outputs
output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.main.name
}

output "application_insights_id" {
  value = azurerm_application_insights.main.id
}

output "application_insights_name" {
  value = azurerm_application_insights.main.name
}

output "application_insights_instrumentation_key" {
  value     = azurerm_application_insights.main.instrumentation_key
  sensitive = true
}

output "application_insights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}

output "action_group_id" {
  value = azurerm_monitor_action_group.main.id
}