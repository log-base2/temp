# Azure Infrastructure - Multi-Region Medical Device Application

This repository contains Terraform infrastructure-as-code for deploying a UK-certified medical device application on Azure with high availability across multiple regions.

## 🏗️ Architecture Overview

### Regional Architecture
- **2 Azure Regions**: UK South (Primary) and UK West (Secondary)
- **3 Availability Zones per Region**: Zone-redundant deployment
- **App Services**: Zone-redundant App Service Plans (Premium v3)
- **Application Gateway**: WAF v2 with zone redundancy per region
- **Traffic Manager**: Global load balancing across regions

### Traffic Flow
```
User Request
    ↓
Azure Traffic Manager (Global DNS-based load balancing)
    ↓
[UK South Region]                    [UK West Region]
    ↓                                     ↓
Application Gateway (WAF)            Application Gateway (WAF)
Zone 1 | Zone 2 | Zone 3            Zone 1 | Zone 2 | Zone 3
    ↓                                     ↓
App Service                          App Service
Zone 1 | Zone 2 | Zone 3            Zone 1 | Zone 2 | Zone 3
```

### Key Features
- ✅ **Multi-Region**: Active-active deployment across UK South and UK West
- ✅ **Zone Redundancy**: 3 availability zones per region
- ✅ **Global Load Balancing**: Traffic Manager with performance-based routing
- ✅ **Regional Load Balancing**: Application Gateway (WAF v2) per region
- ✅ **Auto-scaling**: Horizontal scaling within and across zones
- ✅ **High Availability**: 99.99% SLA with zone redundancy
- ✅ **Disaster Recovery**: Automatic failover between regions

## 📋 Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **Azure CLI** (`az`) installed
3. **Terraform** >= 1.5.0
4. **Git** and **GitHub** account
5. **Service Principal** or **Managed Identity** for authentication

## 🚀 Initial Setup

### Step 1: Create Terraform State Storage

```bash
cd scripts
chmod +x setup-terraform-backend.sh
./setup-terraform-backend.sh
```

### Step 2: Configure Azure Authentication

Follow the same authentication setup as in the main README (Workload Identity Federation recommended).

### Step 3: Update Configuration Files

Edit `terraform/environments/prod/terraform.tfvars`:

```hcl
project_name = "meddevice"
cost_center  = "HEALTHCARE-001"

# Regions
primary_region       = "uksouth"
secondary_region     = "ukwest"

# Network ranges (ensure no overlap between regions)
regional_vnet_address_spaces = {
  primary   = ["10.0.0.0/16"]
  secondary = ["10.10.0.0/16"]
}

# App Service Configuration
app_service_sku_name = "P1v3"  # Premium v3 required for zone redundancy
availability_zones   = ["1", "2", "3"]

# Traffic Manager routing
traffic_routing_method = "Performance"  # Routes to closest healthy region

# Your app must implement this endpoint
traffic_manager_monitor_path = "/health"

# Security
key_vault_admin_object_ids = [
  "YOUR-AZURE-AD-OBJECT-ID"
]

alert_email_addresses = [
  "ops-team@yourcompany.com"
]
```

## 📦 What Gets Deployed

### Per Region (UK South AND UK West)
1. **Resource Group**: Regional resource group
2. **Virtual Network**: 3 subnets (App Service, Private Endpoints, Application Gateway)
3. **Network Security Groups**: Security rules for each subnet
4. **Application Gateway**: WAF v2 with zone redundancy
   - Public IP (zone-redundant)
   - WAF rules (OWASP 3.2)
   - HTTP to HTTPS redirect
   - Health probes
5. **App Service Plan**: Premium v3 with zone balancing
   - Deployed across 3 availability zones
   - Auto-scaling enabled (1-15 instances)
6. **App Service**: Linux/Windows web app
   - Zone-redundant
   - VNet integration
   - Managed identity
   - Health check endpoint
7. **Key Vault**: Secrets management with private endpoint
8. **Storage Account**: Application data with private endpoint
9. **Log Analytics**: Regional monitoring
10. **Application Insights**: Regional telemetry
11. **Azure Monitor**: Alerts and diagnostics
12. **Azure Policy**: Compliance enforcement

### Global Resources
1. **Traffic Manager**: DNS-based global load balancing
2. **Global Resource Group**: For shared resources
3. **Global Dashboard**: Unified monitoring view

## 🔄 Deployment Process

### Development
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Production (via GitHub Actions)
1. Create Pull Request with infrastructure changes
2. Automated validation and security scans run
3. Terraform plan generated for review
4. Merge to main
5. Manual approval required for production
6. Infrastructure deployed to both regions simultaneously
7. Traffic Manager updated with new endpoints

## 📊 Traffic Management

### Routing Methods

**Performance (Default)**:
- Routes users to closest healthy region based on DNS latency
- Best for global applications
- Automatic failover if primary region fails

**Priority**:
- Primary/secondary failover
- All traffic to primary unless unhealthy
- Good for active-passive setup

**Weighted**:
- Distribute traffic by percentage
- Good for gradual region migration or testing

**Geographic**:
- Route based on user geography
- Good for data residency requirements

### Health Monitoring
- Traffic Manager probes each Application Gateway every 30 seconds
- Application Gateway probes each App Service every 30 seconds
- Automatic removal of unhealthy endpoints
- Automatic re-adding when health restored

## 🔒 Security Features

### Network Security
- ✅ Application Gateway with WAF v2 (OWASP 3.2)
- ✅ NSGs on all subnets with restrictive rules
- ✅ Private endpoints for PaaS services
- ✅ VNet integration for App Services
- ✅ TLS 1.2+ enforced
- ✅ HTTP to HTTPS redirect

### Application Security
- ✅ Managed identities (no stored credentials)
- ✅ Key Vault integration for secrets
- ✅ Azure Policy for compliance
- ✅ DDoS Protection (via Application Gateway)
- ✅ Rate limiting and throttling (WAF)

### Data Security
- ✅ Encryption at rest (AES-256)
- ✅ Encryption in transit (TLS 1.2+)
- ✅ UK data residency
- ✅ 7-year log retention (production)
- ✅ Geo-redundant backups

## 📈 Scaling and Performance

### Horizontal Scaling
- **Automatic**: Based on CPU, memory, and request count
- **Zone-aware**: Scales equally across zones
- **Regional**: Can scale independently per region

### Current Configuration
- **Minimum**: 3 instances (1 per zone per region = 6 total)
- **Maximum**: 15 instances per region (5 per zone = 30 total)
- **Scale triggers**:
  - CPU > 70% → Scale out
  - CPU < 25% → Scale in
  - Memory > 75% → Scale out

### Performance Expectations
- **Availability**: 99.99% (zone-redundant)
- **Latency**: < 50ms (within region)
- **Throughput**: Scales with instance count
- **Failover**: < 1 minute (Traffic Manager)

## 🚀 Application Deployment

### Deployment Targets
Your application needs to be deployed to BOTH regions:

```yaml
# In your application's GitHub Actions workflow
name: Deploy Application

jobs:
  deploy-primary:
    runs-on: ubuntu-latest
    steps:
      - name: Get Infrastructure Outputs
        run: |
          cd terraform/environments/prod
          terraform init
          PRIMARY_APP=$(terraform output -json | jq -r '.primary_region.value.app_service_name')
          echo "APP_NAME=$PRIMARY_APP" >> $GITHUB_ENV
      
      - name: Deploy to Primary Region
        uses: azure/webapps-deploy@v2
        with:
          app-name: ${{ env.APP_NAME }}
          package: ./publish

  deploy-secondary:
    runs-on: ubuntu-latest
    steps:
      - name: Get Infrastructure Outputs
        run: |
          cd terraform/environments/prod
          terraform init
          SECONDARY_APP=$(terraform output -json | jq -r '.secondary_region.value.app_service_name')
          echo "APP_NAME=$SECONDARY_APP" >> $GITHUB_ENV
      
      - name: Deploy to Secondary Region
        uses: azure/webapps-deploy@v2
        with:
          app-name: ${{ env.APP_NAME }}
          package: ./publish
```

### Health Check Endpoint
Your application MUST implement `/health` endpoint:

```csharp
// ASP.NET Core example
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));
```

```python
# Python Flask example
@app.route('/health')
def health():
    return jsonify(status='healthy', timestamp=datetime.utcnow()), 200
```

## 🔍 Monitoring

### Access Points
- **Global Endpoint**: Use Traffic Manager FQDN (from Terraform output)
- **Primary Region**: Direct to UK South Application Gateway
- **Secondary Region**: Direct to UK West Application Gateway

### Monitoring Tools
- **Application Insights**: Per-region application telemetry
- **Log Analytics**: Centralized logging per region
- **Traffic Manager**: Global health and routing metrics
- **Application Gateway**: WAF logs, access logs, performance
- **Azure Monitor**: Unified alerting

### Key Metrics to Monitor
- Traffic Manager endpoint health
- Application Gateway response times
- App Service CPU/Memory utilization
- Request counts per region
- Error rates per region
- WAF blocks and threats

## 🏥 Medical Device Compliance

### UK Regulations
- **DCB0129**: Clinical Risk Management ✅
- **DCB0160**: Clinical Safety Case Reports ✅
- **UKCA Marking**: Medical device certification ✅
- **UK GDPR**: Data protection compliance ✅

### Compliance Features
- ✅ Complete audit trail (Git + Azure logs)
- ✅ Change control (PR approval process)
- ✅ Traceability (linked to tickets)
- ✅ Validation (automated testing)
- ✅ UK-only data residency
- ✅ Multi-region DR capability
- ✅ 7+ years log retention

## 💰 Cost Estimates (Monthly)

### Production Environment (Both Regions)

**Per Region:**
- App Service Plan (P1v3): ~£250
- Application Gateway (WAF v2): ~£350
- Storage (GZRS): ~£30
- Networking: ~£40
- Monitoring: ~£60
- Key Vault: ~£10

**Regional Subtotal**: ~£740/month × 2 regions = **£1,480/month**

**Global Resources:**
- Traffic Manager: ~£5

**Total Estimated Cost**: **~£1,485/month**

*Note: Costs increase with traffic and storage usage. Application Gateway and App Service scale dynamically.*

## 🔧 Common Tasks

### Add SSL Certificate to Application Gateway

1. Upload certificate to Key Vault:
```bash
az keyvault certificate import \
  --vault-name kv-meddevice-prod-uks \
  --name app-ssl-cert \
  --file certificate.pfx
```

2. Update Application Gateway Terraform to reference certificate

### Change Traffic Routing Method

Edit `terraform.tfvars`:
```hcl
traffic_routing_method = "Priority"  # For active-passive
```

### Scale App Service

Edit `terraform.tfvars`:
```hcl
app_service_sku_name = "P2v3"  # Larger instances
```

### Add Third Region

1. Add region to `regional_vnet_address_spaces`
2. Add to `regions` map in main.tf
3. Apply Terraform

## 🆘 Disaster Recovery

### Automatic Failover
- Traffic Manager detects unhealthy region in ~90 seconds
- Automatically routes all traffic to healthy region
- No manual intervention required

### Manual Failover
```bash
# Disable primary region endpoint
az network traffic-manager endpoint update \
  --name endpoint-primary \
  --profile-name tm-meddevice-prod-global \
  --resource-group rg-meddevice-prod-global-001 \
  --type azureEndpoints \
  --endpoint-status Disabled
```

### Recovery Procedures
1. Investigate root cause in failed region
2. Fix infrastructure issues
3. Verify application health
4. Re-enable Traffic Manager endpoint
5. Monitor gradual traffic return

## 📚 Additional Resources

- [Azure App Service Multi-Region](https://docs.microsoft.com/azure/app-service/manage-disaster-recovery)
- [Traffic Manager](https://docs.microsoft.com/azure/traffic-manager/)
- [Application Gateway](https://docs.microsoft.com/azure/application-gateway/)
- [Azure Availability Zones](https://docs.microsoft.com/azure/availability-zones/)
- [UK Medical Device Regulations](https://www.gov.uk/guidance/medical-devices-regulations-and-standards)

## 🆘 Support

For issues:
1. Check Traffic Manager endpoint health
2. Review Application Gateway backend health
3. Check App Service diagnostics
4. Review Application Insights for errors
5. Contact: devops@yourcompany.com