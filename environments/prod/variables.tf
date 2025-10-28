variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "uksouth"
}

variable "location_short" {
  description = "Short name for Azure region"
  type        = string
  default     = "uks"
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

# Networking variables
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_function_address" {
  description = "Address prefix for Function App subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "subnet_container_address" {
  description = "Address prefix for Container Apps subnet"
  type        = list(string)
  default     = ["10.0.2.0/23"]
}

variable "subnet_private_endpoint_address" {
  description = "Address prefix for Private Endpoint subnet"
  type        = list(string)
  default     = ["10.0.4.0/24"]
}

variable "subnet_gateway_address" {
  description = "Address prefix for Gateway subnet"
  type        = list(string)
  default     = ["10.0.5.0/24"]
}

variable "enable_ddos_protection" {
  description = "Enable DDoS Protection Standard"
  type        = bool
  default     = true
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

# Function App variables
variable "function_app_sku" {
  description = "SKU for Function App (EP1, EP2, EP3 for Premium, or P1v2, P2v2, P3v2 for Dedicated)"
  type        = string
  default     = "EP1"
}

variable "function_app_settings" {
  description = "Additional app settings for Function App"
  type        = map(string)
  default     = {}
}

# Container Apps variables
variable "enable_container_apps" {
  description = "Enable Container Apps deployment"
  type        = bool
  default     = false
}

variable "container_apps" {
  description = "Map of container apps to deploy"
  type = map(object({
    container_image = string
    container_port  = number
    cpu             = number
    memory          = string
    min_replicas    = number
    max_replicas    = number
    env_vars        = map(string)
  }))
  default = {}
}