variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

# Regional Configuration
variable "primary_region" {
  description = "Primary Azure region"
  type        = string
  default     = "uksouth"
}

variable "primary_region_short" {
  description = "Short name for primary region"
  type        = string
  default     = "uks"
}

variable "secondary_region" {
  description = "Secondary Azure region"
  type        = string
  default     = "ukwest"
}

variable "secondary_region_short" {
  description = "Short name for secondary region"
  type        = string
  default     = "ukw"
}

# Networking variables per region
variable "regional_vnet_address_spaces" {
  description = "Address spaces for VNets in each region"
  type        = map(list(string))
  default = {
    primary   = ["10.0.0.0/16"]
    secondary = ["10.10.0.0/16"]
  }
}

variable "regional_subnet_app_service" {
  description = "Address prefix for App Service subnet per region"
  type        = map(list(string))
  default = {
    primary   = ["10.0.1.0/24"]
    secondary = ["10.10.1.0/24"]
  }
}

variable "regional_subnet_private_endpoint" {
  description = "Address prefix for Private Endpoint subnet per region"
  type        = map(list(string))
  default = {
    primary   = ["10.0.2.0/24"]
    secondary = ["10.10.2.0/24"]
  }
}

variable "regional_subnet_gateway" {
  description = "Address prefix for Application Gateway subnet per region"
  type        = map(list(string))
  default = {
    primary   = ["10.0.3.0/24"]
    secondary = ["10.10.3.0/24"]
  }
}

# App Service Configuration
variable "app_service_sku_name" {
  description = "SKU for App Service Plan (P1v3, P2v3, P3v3 for zone redundancy)"
  type        = string
  default     = "P1v3"
}

variable "availability_zones" {
  description = "Availability zones for App Service (must use Premium v3 SKU)"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "app_service_settings" {
  description = "Application settings for App Service"
  type        = map(string)
  default     = {}
}

# Traffic Manager Configuration
variable "traffic_routing_method" {
  description = "Traffic Manager routing method (Performance, Priority, Weighted, Geographic)"
  type        = string
  default     = "Performance"
}

variable "traffic_manager_monitor_protocol" {
  description = "Protocol for Traffic Manager health checks"
  type        = string
  default     = "HTTPS"
}

variable "traffic_manager_monitor_port" {
  description = "Port for Traffic Manager health checks"
  type        = number
  default     = 443
}

variable "traffic_manager_monitor_path" {
  description = "Path for Traffic Manager health checks"
  type        = string
  default     = "/health"
}

# Security variables
variable "key_vault_admin_object_ids" {
  description = "List of Azure AD object IDs for Key Vault administrators"
  type        = list(string)
}

variable "log_retention_days" {
  description = "Number of days to retain logs (minimum 2555 days for medical device compliance - 7 years)"
  type        = number
  default     = 2555
}

# Monitoring variables
variable "alert_email_addresses" {
  description = "Email addresses for alert notifications"
  type        = list(string)
}