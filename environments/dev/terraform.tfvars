# Staging Environment Configuration

project_name = "meddevice"
cost_center  = "HEALTHCARE-001"

location       = "uksouth"
location_short = "uks"

# Networking Configuration
vnet_address_space              = ["10.2.0.0/16"]
subnet_function_address         = ["10.2.1.0/24"]
subnet_container_address        = ["10.2.2.0/23"]
subnet_private_endpoint_address = ["10.2.4.0/24"]
subnet_gateway_address          = ["10.2.5.0/24"]

# Enable DDoS protection for staging (production-like)
enable_ddos_protection = true

# Security Configuration
key_vault_admin_object_ids = [
  "00000000-0000-0000-0000-000000000000", # Replace with actual admin object IDs
]

# Extended retention for staging (1 year)
log_retention_days = 365

# Monitoring Configuration
alert_email_addresses = [
  "ops-team@yourcompany.com",
  "qa-team@yourcompany.com"
]

# Function App Configuration - Production-like
function_app_sku = "EP1" # Elastic Premium 1

function_app_settings = {
  "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
  "WEBSITE_RUN_FROM_PACKAGE" = "1"
  "ENVIRONMENT"              = "staging"
  "COMPLIANCE_MODE"          = "medical-device"
}

# Container Apps Configuration
enable_container_apps = false

# Example container apps configuration
# container_apps = {
#   api = {
#     container_image = "yourregistry.azurecr.io/api:staging"
#     container_port  = 8080
#     cpu             = 0.5
#     memory          = "1Gi"
#     min_replicas    = 2
#     max_replicas    = 8
#     env_vars = {
#       "ENVIRONMENT" = "staging"
#     }
#   }
# }





# Development Environment Configuration

project_name = "meddevice"
cost_center  = "HEALTHCARE-001"

location       = "uksouth"
location_short = "uks"

# Networking Configuration (smaller ranges for dev)
vnet_address_space              = ["10.1.0.0/16"]
subnet_function_address         = ["10.1.1.0/24"]
subnet_container_address        = ["10.1.2.0/23"]
subnet_private_endpoint_address = ["10.1.4.0/24"]
subnet_gateway_address          = ["10.1.5.0/24"]

# Cost optimization: Disable DDoS protection in dev
enable_ddos_protection = false

# Security Configuration
key_vault_admin_object_ids = [
  "00000000-0000-0000-0000-000000000000", # Replace with actual admin object IDs
]

# Lower retention for dev to save costs
log_retention_days = 30

# Monitoring Configuration
alert_email_addresses = [
  "dev-team@yourcompany.com"
]

# Function App Configuration - smaller SKU for dev
function_app_sku = "B1" # Basic tier for cost savings in dev

function_app_settings = {
  "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
  "WEBSITE_RUN_FROM_PACKAGE" = "1"
  "ENVIRONMENT"              = "development"
  "COMPLIANCE_MODE"          = "development"
}

# Container Apps Configuration
enable_container_apps = false

# Uncomment to enable container apps in dev
# container_apps = {
#   api = {
#     container_image = "yourregistry.azurecr.io/api:dev"
#     container_port  = 8080
#     cpu             = 0.25
#     memory          = "0.5Gi"
#     min_replicas    = 1
#     max_replicas    = 3
#     env_vars = {
#       "ENVIRONMENT" = "development"
#     }
#   }
# }