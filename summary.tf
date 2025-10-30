# Multi-Region Architecture - Complete Terraform Infrastructure

## 🎯 What You Have

A **production-ready, enterprise-grade, multi-region Azure infrastructure** for medical device applications with:

- ✅ **2 Azure Regions** (UK South + UK West) deployed identically
- ✅ **3 Availability Zones per region** for 99.99% SLA
- ✅ **Application Gateway (WAF v2)** in each region as load balancer
- ✅ **Traffic Manager** for global DNS-based load balancing
- ✅ **App Services** with zone redundancy and auto-scaling
- ✅ **Complete security stack** (Key Vault, Private Endpoints, NSGs, WAF)
- ✅ **Full monitoring** (Application Insights, Log Analytics, Alerts)
- ✅ **DevSecOps CI/CD** with GitHub Actions
- ✅ **Medical device compliance** (UK regulations, 7-year logs)

## 📦 Complete File Structure

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf              ✅ Simple copy from prod
│   │   ├── variables.tf         ✅ Copy from prod
│   │   └── terraform.tfvars     ✅ Dev config (single region)
│   ├── staging/
│   │   ├── main.tf              ✅ Copy from prod
│   │   ├── variables.tf         ✅ Copy from prod
│   │   └── terraform.tfvars     ✅ Staging config
│   └── prod/
│       ├── main.tf              ✅ COMPLETE - Multi-region orchestration
│       ├── variables.tf         ✅ COMPLETE - All variables
│       └── terraform.tfvars     ✅ COMPLETE - Production config
│
├── modules/
│   ├── regional-deployment/     ✅ COMPLETE - Deploys one full region
│   │   └── main.tf
│   ├── networking-regional/     ✅ COMPLETE - VNet, NSGs, subnets per region
│   │   └── main.tf
│   ├── app-service/             ✅ COMPLETE - Zone-redundant App Service
│   │   └── main.tf
│   ├── application-gateway/     ✅ COMPLETE - WAF v2 Load Balancer
│   │   └── main.tf
│   ├── traffic-manager/         ✅ COMPLETE - Global load balancing
│   │   └── main.tf
│   ├── security/                ✅ COMPLETE - Key Vault, managed identities
│   │   └── main.tf
│   ├── monitoring/              ✅ COMPLETE - Log Analytics, App Insights
│   │   └── main.tf
│   ├── storage/                 ✅ COMPLETE - Storage with private endpoints
│   │   └── main.tf
│   └── policy/                  ✅ COMPLETE - Azure Policy enforcement
│       └── main.tf
│
└── README.md                    ✅ COMPLETE - Full documentation

.github/workflows/
├── terraform-plan.yml           ✅ COMPLETE - PR validation
├── terraform-apply-dev.yml      ✅ COMPLETE - Auto-deploy to dev
├── terraform-apply-staging.yml  ✅ COMPLETE - Manual staging deploy
└── terraform-apply-prod.yml     ✅ COMPLETE - Multi-approval prod deploy

scripts/
└── setup-terraform-backend.sh  ✅ COMPLETE - State storage setup

QUICKSTART.md                    ✅ COMPLETE - 30-minute setup guide
README.md                        ✅ COMPLETE - Full documentation
DEPLOYMENT_CHECKLIST.md          ✅ COMPLETE - Step-by-step checklist
```

## 🏗️ Architecture Flow

### Deployment Order
```
1. Terraform creates Global Resource Group
2. Terraform deploys to UK South (primary):
   ├── VNet + Subnets + NSGs
   ├── Key Vault + Storage (with private endpoints)
   ├── Log Analytics + Application Insights
   ├── App Service Plan (P1v3, zones 1-3)
   ├── App Service (zone-redundant)
   └── Application Gateway (WAF v2, zones 1-3)
3. Terraform deploys to UK West (secondary):
   └── (Same as UK South with different IPs)
4. Traffic Manager created:
   ├── Endpoint 1 → UK South App Gateway
   └── Endpoint 2 → UK West App Gateway
5. Monitoring configured for all resources
```

### Traffic Flow (User Request)
```
User
  ↓
DNS Query → Traffic Manager
  ├─ Health Check: UK South App Gateway → Healthy
  └─ Response: UK South IP address
  ↓
Application Gateway (UK South)
  ├─ WAF inspection
  ├─ SSL termination
  └─ Load balance to App Services
     ↓
App Service (Zone 1, 2, or 3)
  ├─ Execute application code
  ├─ Access Key Vault for secrets
  ├─ Access Storage if needed
  └─ Send logs to App Insights
```

## 🔄 How It All Works Together

### 1. Regional Deployment Module
The `regional-deployment` module is the key - it:
- Takes region-specific parameters
- Deploys ALL resources for that region
- Returns outputs (App Service name, App Gateway IP, etc.)
- Is called TWICE (once for primary, once for secondary)

### 2. Application Gateway (Regional Load Balancer)
Each region has its own Application Gateway that:
- Sits in front of App Service
- Provides WAF protection (OWASP rules)
- Does SSL termination
- Health checks App Service every 30 seconds
- Scales across 3 availability zones

### 3. Traffic Manager (Global Load Balancer)
The Traffic Manager:
- Receives all user DNS queries
- Health checks each Application Gateway
- Routes users to closest healthy region
- Provides automatic failover
- Uses Performance routing (latency-based)

### 4. App Service (Your Application)
- Deployed across 3 availability zones per region
- Integrated with VNet for security
- Uses managed identity (no credentials)
- Auto-scales based on load
- Must implement `/health` endpoint

## 🎯 Key Differences from Original Design

| Original (Functions) | New (App Services) |
|---------------------|-------------------|
| Azure Functions | Azure App Service |
| Single region | Multi-region (2) |
| Function-specific storage | General storage |
| Consumption/Premium | Premium v3 (P1v3, P2v3, P3v3) |
| No load balancer | Application Gateway per region |
| No global routing | Traffic Manager |
| VNet integration | VNet integration + zones |

## 🚀 Deployment Steps Summary

1. **Prerequisites** (5 min)
   - Azure subscription
   - Azure CLI + Terraform installed
   - GitHub repo created

2. **State Storage** (3 min)
   ```bash
   ./scripts/setup-terraform-backend.sh
   ```

3. **GitHub Auth** (10 min)
   - Create service principal
   - Configure OIDC
   - Add secrets to GitHub

4. **Configure** (5 min)
   - Update `terraform.tfvars` with your values
   - Update runtime in app-service module

5. **Deploy Dev** (2 min)
   ```bash
   cd terraform/environments/dev
   terraform apply
   ```

6. **Deploy Prod** (5 min)
   ```bash
   git push origin main
   # Approve in GitHub Actions
   ```

## 📊 What Gets Created

### Per Region (× 2)
- 1 Resource Group
- 1 Virtual Network
- 3 Subnets (App Service, Private Endpoints, Gateway)
- 3 Network Security Groups
- 3 Private DNS Zones
- 1 Key Vault (Premium, HSM-backed)
- 1 Storage Account (geo-redundant)
- 4 Private Endpoints (Key Vault, Storage Blob, Storage File)
- 1 Application Gateway (WAF v2, zone-redundant)
- 1 Public IP (zone-redundant)
- 1 App Service Plan (Premium v3, zone-redundant)
- 1 App Service (zone-redundant, 3+ instances)
- 1 Log Analytics Workspace
- 1 Application Insights
- 8 Azure Policy Assignments
- Multiple Managed Identities
- Diagnostic Settings on all resources
- Autoscale rules

### Global
- 1 Global Resource Group
- 1 Traffic Manager Profile
- 2 Traffic Manager Endpoints
- 1 Global Monitoring Dashboard

**Total Resources**: ~70 resources across both regions

## 💰 Cost Breakdown

### Production (Monthly)

**UK South Region:**
- App Service Plan P1v3: £125
- Application Gateway WAF v2: £350
- Storage Account: £15
- Key Vault Premium: £10
- Networking (NSG, DNS, etc.): £20
- Monitoring (Log Analytics, App Insights): £30
- **Subtotal**: £550

**UK West Region:**
- Same as UK South: £550

**Global:**
- Traffic Manager: £5

**Total**: ~£1,105/month base cost

**With usage (production load):**
- Data transfer: +£100-200
- Application Gateway bandwidth: +£100-150
- Log Analytics ingestion: +£50-100

**Realistic Total**: £1,400-1,600/month

### Cost Optimization Tips
- Use B1 tier for dev (£50/month)
- Reduce log retention for non-prod
- Use Standard Application Gateway for dev
- Disable zone redundancy for dev

## 🔐 Security Highlights

✅ **Network Security**
- WAF on all entry points (OWASP 3.2)
- NSGs with restrictive rules
- Private endpoints for all PaaS
- No public IPs on compute
- VNet integration

✅ **Identity & Access**
- Managed identities everywhere
- RBAC on all resources
- Key Vault for secrets
- No stored credentials

✅ **Data Protection**
- TLS 1.2+ enforced
- Encryption at rest (AES-256)
- UK data residency
- Geo-redundant backups
- 7-year log retention (prod)

✅ **Compliance**
- Azure Policy enforcement
- Complete audit trail
- Change control via Git
- Automated compliance checks

## 🎓 Application Development Guide

### What Your App Needs

1. **Health Endpoint** (REQUIRED)
   ```
   GET /health → 200 OK
   ```

2. **Environment Variables** (Available)
   - `APPLICATIONINSIGHTS_CONNECTION_STRING`
   - `AZURE_CLIENT_ID` (for managed identity)
   - `KEY_VAULT_URI`
   - `ENVIRONMENT` (dev/staging/prod)
   - `REGION` (primary/secondary)

3. **Managed Identity Usage**
   ```csharp
   // C# example
   var credential = new DefaultAzureCredential();
   var client = new SecretClient(new Uri(Environment.GetEnvironmentVariable("KEY_VAULT_URI")), credential);
   ```

4. **Deployment**
   - Deploy to BOTH regions
   - Use Terraform outputs for App Service names
   - Automated via GitHub Actions

## 🔍 Monitoring & Troubleshooting

### Check Health
```bash
# Global endpoint
curl https://meddevice-prod.trafficmanager.net/health

# Regional endpoints
curl https://$(terraform output -json | jq -r '.primary_region.value.app_gateway_public_ip')/health
```

### View Logs
```bash
# Application Insights
az monitor app-insights query \
  --app appi-meddevice-prod-uks-001 \
  --analytics-query "requests | where timestamp > ago(1h)"

# App Service logs
az webapp log tail \
  --name app-meddevice-prod-uks-001 \
  --resource-group rg-meddevice-prod-uks-001
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| 502 Bad Gateway | App Service unhealthy | Check `/health` endpoint |
| Traffic Manager degraded | Regional failure | Check App Gateway health |
| SSL certificate error | No cert configured | Add cert to App Gateway |
| Can't access Key Vault | Managed identity issue | Check RBAC assignments |

## 📚 Next Steps

1. ✅ **Now**: Review this summary
2. ✅ **Next**: Read QUICKSTART.md
3. ✅ **Then**: Run `terraform plan` locally
4. ✅ **Deploy**: Push to GitHub
5. ✅ **Application**: Implement `/health` endpoint
6. ✅ **Deploy App**: Use GitHub Actions
7. ✅ **SSL**: Add certificates
8. ✅ **Monitor**: Set up dashboards
9. ✅ **Test**: DR procedures
10. ✅ **Document**: Runbooks

## 🆘 Support Resources

- **QUICKSTART.md**: Fast setup guide
- **README.md**: Complete documentation  
- **DEPLOYMENT_CHECKLIST.md**: Step-by-step
- **Azure Docs**: docs.microsoft.com
- **Terraform Registry**: registry.terraform.io

## ✅ Ready to Deploy?

You have **everything you need**:
- ✅ Complete Terraform modules
- ✅ Multi-region architecture
- ✅ Security & compliance
- ✅ CI/CD pipelines
- ✅ Monitoring & alerting
- ✅ Documentation

**Go build amazing things! 🚀**