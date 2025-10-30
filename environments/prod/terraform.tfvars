# Production Environment Configuration

project_name = "meddevice"
cost_center  = "HEALTHCARE-001"

# Regional Configuration
primary_region       = "uksouth"
primary_region_short = "uks"

secondary_region       = "ukwest"
secondary_region_short = "ukw"

# Networking Configuration per Region
regional_vnet_address_spaces = {
  primary   = ["10.0.0.0/16"]
  secondary = ["10.10.0.0/16"]
}

regional_subnet_app_service = {
  primary   = ["10.0.1.0/24"]
  secondary = ["10.10.1.0/24"]
}

regional_subnet_private_endpoint = {
  primary   = ["10.0.2.0/24"]
  secondary = ["10.10.2.0/24"]
}

regional_subnet_gateway = {
  primary   = ["10.0.3.0/24"]
  secondary = ["10.10.3.0/24"]
}

# App Service Configuration
# P1v3 = 2 vCPU, 8 GB RAM, zone redundancy support
# P2v3 = 4 vCPU, 16 GB RAM, zone redundancy support
# P3v3 = 8 vCPU, 32 GB RAM, zone redundancy support
app_service_sku_name = "P1v3"

# Deploy across all 3 availability zones
availability_zones = ["1", "2", "3"]

# Application Settings
app_service_settings = {
  "ASPNETCORE_ENVIRONMENT"    = "Production"  # or adjust for your runtime
  "WEBSITE_RUN_FROM_PACKAGE"  = "1"
  "ENVIRONMENT"               = "production"
  "COMPLIANCE_MODE"           = "medical-device"
  # Add your application-specific settings here
}

# Traffic Manager Configuration
# Performance = Routes to closest region based on latency
# Priority = Primary/secondary failover
# Weighted = Distribute traffic by percentage
# Geographic = Route based on user geography
traffic_routing_method = "Performance"

traffic_manager_monitor_protocol = "HTTPS"
traffic_manager_monitor_port     = 443
traffic_manager_monitor_path     = "/health"  # Your app must implement this endpoint

# Security Configuration
# IMPORTANT: Replace these with actual Azure AD Object IDs
key_vault_admin_object_ids = [
  "00000000-0000-0000-0000-000000000000", # Replace with actual admin object IDs
]

# Compliance: 7+ years log retention for medical devices
log_retention_days = 2555

# Monitoring Configuration
alert_email_addresses = [
  "ops-team@yourcompany.com",
  "security-team@yourcompany.com"
]