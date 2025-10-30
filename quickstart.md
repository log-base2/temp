# Quick Start Guide - Multi-Region Deployment

Deploy your high-availability, multi-region medical device application in 30 minutes.

## Architecture At A Glance

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Azure Traffic Manager                          │
│              (Global DNS-based Load Balancing)                      │
│                     Performance Routing                             │
└────────────┬────────────────────────────────────┬───────────────────┘
             │                                    │
    ┌────────▼────────┐                  ┌────────▼────────┐
    │   UK SOUTH      │                  │   UK WEST       │
    │  (Primary)      │                  │  (Secondary)    │
    └────────┬────────┘                  └────────┬────────┘
             │                                    │
    ┌────────▼──────────────┐          ┌─────────▼──────────────┐
    │ Application Gateway   │          │  Application Gateway   │
    │   WAF v2 (Zones 1-3)  │          │    WAF v2 (Zones 1-3)  │
    └────────┬──────────────┘          └──────────┬─────────────┘
             │                                     │
    ┌────────▼──────────────┐          ┌──────────▼────────────┐
    │    App Services       │          │     App Services      │
    │  ┌──┬──┬──┐           │          │   ┌──┬──┬──┐          │
    │  │Z1│Z2│Z3│           │          │   │Z1│Z2│Z3│          │
    │  └──┴──┴──┘           │          │   └──┴──┴──┘          │
    └───────────────────────┘          └───────────────────────┘
```

## Prerequisites Checklist

- [ ] Azure subscription (Owner/Contributor)
- [ ] Azure CLI installed
- [ ] Terraform >= 1.5.0 installed
- [ ] GitHub repository created
- [ ] Basic understanding of App Service deployment

## Quick Deploy (30 Minutes)

### Step 1: Get Your Azure IDs (3 minutes)

```bash
# Login
az login

# Get your Object ID
az ad signed-in-user show --query id -o tsv
# Save this - you'll need it!

# Get subscription ID
az account show --query id -o tsv
# Save this too!

# Get tenant ID
az account show --query tenantId -o tsv
```

### Step 2: Create State Storage (3 minutes)

```bash
cd scripts
chmod +x setup-terraform-backend.sh
./setup-terraform-backend.sh
```

### Step 3: Setup GitHub Authentication (10 minutes)

```bash
# Create service principal
APP_ID=$(az ad app create --display-name "GitHub-Actions-MedDevice" --query appId -o tsv)
SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)

# Configure OIDC for GitHub (replace YOUR_ORG and YOUR_REPO)
az ad app federated-credential create --id $APP_ID --parameters "{
  \"name\": \"GitHubActions\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}"

# Get subscription and tenant IDs
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Assign Contributor role
az role assignment create \
  --assignee $SP_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID

# Grant access to Terraform state
az role assignment create \
  --assignee $SP_ID \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-terraform-state-prod/providers/Microsoft.Storage/storageAccounts/sttfstateprod001

echo "==================== SAVE THESE VALUES ===================="
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "==========================================================="
```

### Step 4: Configure GitHub (5 minutes)

1. Go to your GitHub repo → Settings → Secrets → Actions
2. Add these secrets:

```
AZURE_CLIENT_ID = <APP_ID from step 3>
AZURE_TENANT_ID = <TENANT_ID from step 3>
AZURE_SUBSCRIPTION_ID_DEV = <SUBSCRIPTION_ID>
AZURE_SUBSCRIPTION_ID_STAGING = <SUBSCRIPTION_ID>
AZURE_SUBSCRIPTION_ID_PROD = <SUBSCRIPTION_ID>
AZURE_CLIENT_ID_DEV = <APP_ID>
AZURE_CLIENT_ID_STAGING = <APP_ID>
AZURE_CLIENT_ID_PROD = <APP_ID>
```

3. Create GitHub Environments:
   - Settings → Environments → New environment
   - Create: `development`, `staging`, `production`
   - For `production`: Add 2 required reviewers

### Step 5: Update Configuration (5 minutes)

Edit `terraform/environments/prod/terraform.tfvars`:

```hcl
project_name = "meddevice"  # Change this to your project name

# IMPORTANT: Add your Azure AD Object ID from Step 1
key_vault_admin_object_ids = [
  "YOUR-OBJECT-ID-FROM-STEP-1"
]

# Add your email
alert_email_addresses = [
  "your-email@company.com"
]

# Update runtime if not using .NET
app_service_settings = {
  "ASPNETCORE_ENVIRONMENT" = "Production"  # Change to your runtime
  # For Python: "PYTHON_VERSION" = "3.11"
  # For Node: "WEBSITE_NODE_DEFAULT_VERSION" = "18-lts"
}
```

**IMPORTANT**: Update the `application_stack` in `modules/app-service/main.tf`:
```hcl
application_stack {
  dotnet_version = "8.0"  # OR
  # python_version = "3.11"  # OR
  # node_version = "18-lts"  # OR
  # java_version = "17"
}
```

### Step 6: Test Locally (2 minutes)

```bash
cd terraform/environments/dev
terraform init
terraform plan

# If plan looks good:
terraform apply
```

This will deploy to Development environment only (single region, cheaper).

### Step 7: Deploy to Production (2 minutes)

```bash
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

This triggers the GitHub Actions workflow. Go to:
- GitHub → Actions → Watch the deployment
- Approve when prompted for production

## What Just Happened?

You've deployed:

✅ **2 Azure Regions** (UK South + UK West)
✅ **6 App Service Instances** (3 per region, zone-redundant)
✅ **2 Application Gateways** (WAF enabled, zone-redundant)
✅ **1 Traffic Manager** (global load balancing)
✅ **2 Key Vaults** (one per region)
✅ **2 Storage Accounts** (one per region)
✅ **Complete Monitoring** (Application Insights, Log Analytics)

## Verify Deployment

### 1. Get Your Application Endpoint

```bash
cd terraform/environments/prod
terraform output traffic_manager_fqdn
```

This is your global endpoint! Example: `meddevice-prod.trafficmanager.net`

### 2. Check Application Gateway Health

```bash
# Primary region
terraform output -json | jq -r '.primary_region.value.app_gateway_public_ip'

# Secondary region
terraform output -json | jq -r '.secondary_region.value.app_gateway_public_ip'
```

Visit these IPs in your browser (will show error until you deploy your app).

### 3. Check Azure Portal

1. Go to portal.azure.com
2. Look for resource groups:
   - `rg-meddevice-prod-global-001` (Traffic Manager)
   - `rg-meddevice-prod-uks-001` (UK South resources)
   - `rg-meddevice-prod-ukw-001` (UK West resources)

## Next Step: Deploy Your Application

### Required: Implement Health Endpoint

Your application MUST have a `/health` endpoint:

**C# / ASP.NET Core:**
```csharp
app.MapGet("/health", () => Results.Ok(new { 
    status = "healthy", 
    timestamp = DateTime.UtcNow 
}));
```

**Python / Flask:**
```python
@app.route('/health')
def health():
    return jsonify(status='healthy'), 200
```

**Node.js / Express:**
```javascript
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date() });
});
```

### Deploy Your Application

Create `.github/workflows/deploy-app.yml` in your APPLICATION repo:

```yaml
name: Deploy Application

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        region: [primary, secondary]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build Application
        run: |
          # Your build commands here
          dotnet publish -c Release -o ./publish
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Get App Service Name
        id: infra
        run: |
          cd path/to/terraform/environments/prod
          terraform init
          APP_NAME=$(terraform output -json | jq -r '.${{ matrix.region }}_region.value.app_service_name')
          echo "app_name=$APP_NAME" >> $GITHUB_OUTPUT
      
      - name: Deploy to Azure App Service
        uses: azure/webapps-deploy@v2
        with:
          app-name: ${{ steps.infra.outputs.app_name }}
          package: ./publish
```

## Test Your Deployment

### 1. Test Global Endpoint

```bash
curl https://meddevice-prod.trafficmanager.net/health
```

Expected: `{ "status": "healthy" }`

### 2. Test Regional Endpoints

```bash
# Primary (UK South)
curl https://$(terraform output -json | jq -r '.primary_region.value.app_gateway_public_ip')/health

# Secondary (UK West)
curl https://$(terraform output -json | jq -r '.secondary_region.value.app_gateway_public_ip')/health
```

### 3. Test Failover

```bash
# Disable primary region
az network traffic-manager endpoint update \
  --name endpoint-primary \
  --profile-name tm-meddevice-prod-global \
  --resource-group rg-meddevice-prod-global-001 \
  --type azureEndpoints \
  --endpoint-status Disabled

# Wait 60-90 seconds, then test
curl https://meddevice-prod.trafficmanager.net/health
# Should still work (routed to secondary)

# Re-enable primary
az network traffic-manager endpoint update \
  --name endpoint-primary \
  --profile-name tm-meddevice-prod-global \
  --resource-group rg-meddevice-prod-global-001 \
  --type azureEndpoints \
  --endpoint-status Enabled
```

## Common Issues

### Issue: "Application Gateway backend unhealthy"
**Solution**: Your app must respond to `/health` on HTTPS port 443

### Issue: "Traffic Manager endpoint degraded"
**Solution**: Check Application Gateway health first, then App Service logs

### Issue: "Cannot deploy to App Service"
**Solution**: Ensure managed identity has permissions, check app settings

### Issue: "SSL/Certificate errors"
**Solution**: Need to add SSL certificate to Application Gateway (see main README)

## Costs

**Development** (single region, no zones): ~£150/month
**Production** (two regions, zones): ~£1,500/month

Cost breakdown:
- App Services (P1v3 × 2): £500
- Application Gateways (WAF v2 × 2): £700
- Storage, networking, monitoring: £300

## What's Next?

1. ✅ Deploy your application code
2. ✅ Add SSL certificate to Application Gateway
3. ✅ Configure custom domain
4. ✅ Set up continuous deployment
5. ✅ Configure monitoring dashboards
6. ✅ Test disaster recovery procedures
7. ✅ Document runbooks
8. ✅ Compliance documentation

## Support

- **Documentation**: See main README.md
- **Issues**: Open GitHub issue
- **Architecture Questions**: devops@yourcompany.com

---

**Congratulations! You have a production-ready, multi-region, zone-redundant medical device platform! 🎉**