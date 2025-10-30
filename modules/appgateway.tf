variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
variable "location_short" { type = string }
variable "region_name" { type = string }
variable "tags" { type = map(string) }
variable "gateway_subnet_id" { type = string }
variable "app_service_fqdn" { type = string }
variable "key_vault_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "availability_zones" { type = list(string) }

locals {
  app_gateway_name = "agw-${var.project_name}-${var.environment}-${var.location_short}-001"
  public_ip_name   = "pip-agw-${var.project_name}-${var.environment}-${var.location_short}-001"
  
  # Application Gateway configuration
  backend_address_pool_name      = "appservice-backend-pool"
  frontend_port_name_http        = "frontend-port-http"
  frontend_port_name_https       = "frontend-port-https"
  frontend_ip_configuration_name = "frontend-ip-config"
  http_setting_name              = "appservice-http-setting"
  listener_name_http             = "http-listener"
  listener_name_https            = "https-listener"
  request_routing_rule_name_http = "http-routing-rule"
  request_routing_rule_name_https = "https-routing-rule"
  redirect_configuration_name    = "http-to-https-redirect"
  probe_name                     = "health-probe"
}

# Public IP for Application Gateway (zone-redundant)
resource "azurerm_public_ip" "main" {
  name                = local.public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones
  domain_name_label   = "${var.project_name}-${var.environment}-${var.location_short}"
  tags                = var.tags
}

# Managed Identity for Application Gateway (to access Key Vault for certificates)
resource "azurerm_user_assigned_identity" "app_gateway" {
  name                = "id-${local.app_gateway_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Grant Application Gateway access to Key Vault for certificates
resource "azurerm_role_assignment" "app_gateway_key_vault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app_gateway.principal_id
}

# Application Gateway (WAF v2 with zone redundancy)
resource "azurerm_application_gateway" "main" {
  name                = local.app_gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location
  zones               = var.availability_zones
  tags                = var.tags

  # Identity for accessing Key Vault
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_gateway.id]
  }

  sku {
    name     = "WAF_v2"  # WAF for medical device security
    tier     = "WAF_v2"
    capacity = length(var.availability_zones)  # Minimum one instance per zone
  }

  # Enable autoscaling
  autoscale_configuration {
    min_capacity = length(var.availability_zones)
    max_capacity = length(var.availability_zones) * 10  # Max 10 instances per zone
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.gateway_subnet_id
  }

  frontend_port {
    name = local.frontend_port_name_http
    port = 80
  }

  frontend_port {
    name = local.frontend_port_name_https
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.main.id
  }

  backend_address_pool {
    name  = local.backend_address_pool_name
    fqdns = [var.app_service_fqdn]
  }

  # Health probe
  probe {
    name                                      = local.probe_name
    protocol                                  = "Https"
    path                                      = "/health"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
    
    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = local.http_setting_name
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = true
    probe_name                          = local.probe_name
    
    # Connection draining for graceful shutdown
    connection_draining {
      enabled           = true
      drain_timeout_sec = 60
    }
  }

  # HTTP Listener (for redirect to HTTPS)
  http_listener {
    name                           = local.listener_name_http
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_http
    protocol                       = "Http"
  }

  # HTTPS Listener
  # Note: In production, add SSL certificate from Key Vault
  http_listener {
    name                           = local.listener_name_https
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name_https
    protocol                       = "Https"
    
    # TODO: Add SSL certificate
    # ssl_certificate_name = "app-ssl-cert"
    # For now, this will need to be added manually or via separate certificate resource
  }

  # HTTP to HTTPS redirect
  redirect_configuration {
    name                 = local.redirect_configuration_name
    redirect_type        = "Permanent"
    target_listener_name = local.listener_name_https
    include_path         = true
    include_query_string = true
  }

  request_routing_rule {
    name                        = local.request_routing_rule_name_http
    rule_type                   = "Basic"
    http_listener_name          = local.listener_name_http
    redirect_configuration_name = local.redirect_configuration_name
    priority                    = 100
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name_https
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name_https
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 110
  }

  # Web Application Firewall Configuration
  waf_configuration {
    enabled                  = true
    firewall_mode            = var.environment == "prod" ? "Prevention" : "Detection"
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    file_upload_limit_mb     = 100
    request_body_check       = true
    max_request_body_size_kb = 128
  }

  # Force specific SSL protocols and ciphers
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"  # TLS 1.2 only
  }

  lifecycle {
    ignore_changes = [
      tags["hidden-link: /app-insights-resource-id"]
    ]
  }
}

# Diagnostic settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "app_gateway" {
  name                       = "diag-${local.app_gateway_name}"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Outputs
output "application_gateway_id" {
  value = azurerm_application_gateway.main.id
}

output "application_gateway_name" {
  value = azurerm_application_gateway.main.name
}

output "public_ip_id" {
  value = azurerm_public_ip.main.id
}

output "public_ip_address" {
  value = azurerm_public_ip.main.ip_address
}

output "public_ip_fqdn" {
  value = azurerm_public_ip.main.fqdn
}