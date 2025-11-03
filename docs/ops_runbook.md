# Operations Runbook - Infrastructure Pipeline

## 🚨 Emergency Procedures

### Critical: Production Deployment Failed

**Symptoms:**
- Production deployment workflow failed
- Critical issue created in GitHub
- Health checks failing

**Immediate Actions (5 minutes):**

1. **Assess Impact:**
   ```bash
   # Check if production is still serving traffic
   curl -I https://meddevice-prod.trafficmanager.net/health
   
   # Check Application Gateway status
   az network application-gateway show-backend-health \
     --name agw-meddevice-prod-uks-001 \
     --resource-group rg-meddevice-prod-uks-001
   ```

2. **If Production is Down → Immediate Rollback:**
   ```bash
   # Get last successful state backup
   az storage blob list \
     --account-name sttfstateprod001 \
     --container-name tfstate-backups \
     --prefix "prod-" \
     --auth-mode login \
     --query "reverse(sort_by([].{name:name, lastModified:properties.lastModified}, &lastModified))[0].name" \
     -o tsv
   
   # Download backup
   BACKUP_FILE="prod-20241031-143000.tfstate"  # Use output from above
   az storage blob download \
     --account-name sttfstateprod001 \
     --container-name tfstate-backups \
     --name $BACKUP_FILE \
     --file rollback.tfstate \
     --auth-mode login
   
   # Replace current state
   az storage blob upload \
     --account-name sttfstateprod001 \
     --container-name tfstate \
     --name prod.terraform.tfstate \
     --file rollback.tfstate \
     --overwrite \
     --auth-mode login
   
   # Trigger deployment to restore from backup state
   # Go to Actions → Deploy to Production → Run workflow
   ```

3. **If Production is Stable → Investigate:**
   - Review workflow logs
   - Check which step failed
   - Assess if partial deployment occurred
   - Document findings

**Next Steps (15 minutes):**

1. **Notify Stakeholders:**
   - Email: ops-team@yourcompany.com
   - Slack: #infrastructure-alerts
   - Status page: Update incident

2. **Root Cause Analysis:**
   - Review failure logs
   - Check Azure Portal for errors
   - Identify what changed
   - Document timeline

3. **Create Incident Report:**
   - Use GitHub issue template
   - Include timeline
   - Attach logs
   - Proposed fix

### Critical: Security Scan Detected Secrets

**Symptoms:**
- PR pipeline failed on secrets scan
- Gitleaks or TruffleHog alert

**Immediate Actions:**

1. **Identify the Secret:**
   ```bash
   # Check the pipeline logs
   # Note: Type of secret, location, commit
   ```

2. **Rotate the Secret:**
   ```bash
   # If it's an Azure credential
   az ad sp credential reset --id <service-principal-id>
   
   # If it's a Key Vault secret
   az keyvault secret set \
     --vault-name kv-meddevice-prod-uks \
     --name <secret-name> \
     --value <new-value>
   
   # If it's a storage account key
   az storage account keys renew \
     --account-name <account-name> \
     --key primary
   ```

3. **Remove from Git History:**
   ```bash
   # Use BFG Repo-Cleaner or git-filter-repo
   # DO NOT USE git filter-branch (slow and dangerous)
   
   # Example with BFG
   bfg --delete-files secret-file.txt
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```

4. **Audit Access:**
   - Check who committed the secret
   - Review Azure access logs
   - Check if secret was used
   - Document exposure window

### Medium: Health Checks Failing Post-Deployment

**Symptoms:**
- Deployment completed
- Health checks returning non-200 status
- Traffic Manager showing degraded

**Actions:**

1. **Check Application Status:**
   ```bash
   # Check App Service status
   az webapp show \
     --name app-meddevice-prod-uks-001 \
     --resource-group rg-meddevice-prod-uks-001 \
     --query "{name:name, state:state, running:running}"
   
   # Check App Service logs
   az webapp log tail \
     --name app-meddevice-prod-uks-001 \
     --resource-group rg-meddevice-prod-uks-001
   ```

2. **Verify Application Gateway:**
   ```bash
   # Check backend health
   az network application-gateway show-backend-health \
     --name agw-meddevice-prod-uks-001 \
     --resource-group rg-meddevice-prod-uks-001
   ```

3. **Check Application Insights:**
   ```bash
   # Query for errors
   az monitor app-insights query \
     --app appi-meddevice-prod-uks-001 \
     --analytics-query "exceptions | where timestamp > ago(1h) | summarize count() by problemId, outerMessage" \
     --resource-group rg-meddevice-prod-uks-001
   ```

4. **Common Issues:**
   - `/health` endpoint not implemented → Deploy app with health endpoint
   - App not started → Restart App Service
   - Network connectivity → Check NSG rules, private endpoints
   - Configuration issue → Review app settings in App Service

## 📅 Scheduled Operations

### Daily Tasks

**Morning (9:00 AM UK):**

1. **Check Overnight Deployments:**
   ```bash
   # Review GitHub Actions for any failures
   gh run list --limit 10
   ```

2. **Review Security Alerts:**
   - Check GitHub Security tab
   - Review new findings
   - Triage by severity

3. **Check Azure Health:**
   ```bash
   # Check for any Azure service issues
   az resource health list \
     --resource-group rg-meddevice-prod-uks-001
   ```

4. **Monitor Costs:**
   ```bash
   # Check daily spend
   az consumption usage list \
     --start-date $(date -d "yesterday" +%Y-%m-%d) \
     --end-date $(date +%Y-%m-%d)
   ```

**End of Day (5:00 PM UK):**

1. **Check Open PRs:**
   - Review pending infrastructure changes
   - Check for security findings
   - Assign reviewers if needed

2. **Verify Backups:**
   ```bash
   # Check today's state backups
   az storage blob list \
     --account-name sttfstateprod001 \
     --container-name tfstate-backups \
     --prefix "prod-$(date +%Y%m%d)"
   ```

### Weekly Tasks (Monday)

1. **Security Review:**
   - Review all security findings from past week
   - Track remediation progress
   - Update security dashboard

2. **Cost Analysis:**
   ```bash
   # Weekly cost report
   az consumption usage list \
     --start-date $(date -d "7 days ago" +%Y-%m-%d) \
     --end-date $(date +%Y-%m-%d) \
     | jq -r '.[] | "\(.usageStart) \(.pretaxCost) \(.product)"'
   ```

3. **Deployment Review:**
   - Count deployments (dev/staging/prod)
   - Review failure rate
   - Identify patterns

4. **Pipeline Health:**
   - Check average pipeline duration
   - Review failure reasons
   - Optimize if needed

### Monthly Tasks (First Monday)

1. **Compliance Audit:**
   - Run compliance checklist
   - Verify 7-year log retention
   - Check UK data residency
   - Review encryption settings
   - Verify private endpoints

2. **Security Audit:**
   - Review all NSG rules
   - Audit Key Vault access
   - Review managed identities
   - Check for unused resources

3. **Performance Review:**
   - Application Gateway performance
   - App Service metrics
   - Traffic Manager routing
   - Cost optimization opportunities

4. **Documentation Update:**
   - Update runbooks
   - Review and update README
   - Update architecture diagrams
   - Document lessons learned

### Quarterly Tasks (First Monday of Quarter)

1. **DR Test:**
   - Test regional failover
   - Verify backup restoration
   - Document recovery time
   - Update DR plan

2. **Security Penetration Test:**
   - Engage security team
   - Test WAF effectiveness
   - Test network segmentation
   - Document findings

3. **Capacity Planning:**
   - Review growth trends
   - Plan scaling needs
   - Estimate future costs
   - Optimize resources

4. **Compliance Certification:**
   - Prepare audit documentation
   - Gather evidence
   - Schedule audit
   - Remediate findings

## 🔧 Common Maintenance Tasks

### Update Terraform Providers

```bash
# 1. Check current versions
cd terraform/environments/prod
terraform version
terraform providers

# 2. Update version in main.tf
# Edit required_providers block

# 3. Test in dev first
cd ../dev
terraform init -upgrade
terraform plan

# 4. If successful, create PR for all environments
git checkout -b chore/update-terraform-providers
# Make changes
git commit -m "chore: update Terraform providers to latest"
git push
# Create PR
```

### Add New Azure Region

```bash
# 1. Update variables in terraform.tfvars
# Add new region to regional_vnet_address_spaces
# Add subnets for new region

# 2. Update main.tf regions map
# Add third region configuration

# 3. Test in dev first
terraform plan

# 4. Deploy to prod via PR
```

### Rotate Service Principal Credentials

```bash
# 1. Create new credential
NEW_CRED=$(az ad sp credential reset \
  --id $AZURE_CLIENT_ID \
  --query password -o tsv)

# 2. Update GitHub Secrets
# Go to Settings → Secrets → Update AZURE_CLIENT_ID_*

# 3. Test with a small deployment
# Trigger dev deployment

# 4. Document rotation date
echo "$(date): Service principal credential rotated" >> ops-log.txt
```

### Scale App Service

```bash
# 1. Update terraform.tfvars
# Change app_service_sku_name from P1v3 to P2v3

# 2. Create PR with justification
# Explain reason for scaling

# 3. Deploy during business hours
# Monitor for issues

# 4. Verify scaling
az appservice plan show \
  --name asp-meddevice-prod-uks-001 \
  --resource-group rg-meddevice-prod-uks-001 \
  --query "{sku:sku, capacity:capacity}"
```

## 📊 Monitoring & Alerting

### Key Metrics to Watch

**Infrastructure Health:**
```bash
# Application Gateway backend health
az monitor metrics list \
  --resource <app-gateway-resource-id> \
  --metric UnhealthyHostCount \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --interval PT1M

# App Service CPU
az monitor metrics list \
  --resource <app-service-resource-id> \
  --metric CpuPercentage \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --interval PT1M

# Traffic Manager endpoint health
az network traffic-manager endpoint show \
  --name endpoint-primary \
  --profile-name tm-meddevice-prod-global \
  --resource-group rg-meddevice-prod-global-001 \
  --query "endpointMonitorStatus"
```

**Application Metrics:**
```bash
# Request rate
az monitor app-insights metrics show \
  --app appi-meddevice-prod-uks-001 \
  --resource-group rg-meddevice-prod-uks-001 \
  --metric requests/count \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)

# Error rate
az monitor app-insights metrics show \
  --app appi-meddevice-prod-uks-001 \
  --resource-group rg-meddevice-prod-uks-001 \
  --metric requests/failed \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
```

### Alert Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Backend Unhealthy Hosts | > 1 | > 2 | Check App Service health |
| CPU Percentage | > 75% | > 90% | Scale up |
| Memory Percentage | > 80% | > 95% | Scale up |
| Response Time | > 2s | > 5s | Investigate app performance |
| Error Rate | > 1% | > 5% | Check application logs |
| Traffic Manager Degraded | Any endpoint | All endpoints | Regional failover |

## 🔍 Troubleshooting Guide

### Issue: Pipeline Stuck on "Waiting for approval"

**Cause:** GitHub environment protection rule requires approval

**Solution:**
1. Check who the designated approvers are
2. Notify approvers
3. Provide context for the change
4. Wait for approval
5. If urgent, contact ops lead to approve

### Issue: "Terraform state lock" error

**Cause:** Another deployment is running or previous deployment didn't release lock

**Check:**
```bash
# View lock info
az storage blob show \
  --account-name sttfstateprod001 \
  --container-name tfstate \
  --name prod.terraform.tfstate.lock \
  --auth-mode login
```

**Solution:**
```bash
# If lock is stale (> 30 min old), force unlock
cd terraform/environments/prod
terraform force-unlock <LOCK_ID>
```

**Prevention:** Always let workflows complete, don't cancel mid-deployment

### Issue: "Backend initialization failed"

**Cause:** Can't access state storage

**Check:**
```bash
# Verify storage account exists
az storage account show \
  --name sttfstateprod001 \
  --resource-group rg-terraform-state-prod

# Check permissions
az role assignment list \
  --assignee $AZURE_CLIENT_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-terraform-state-prod
```

**Solution:**
- Verify service principal has "Storage Blob Data Contributor" role
- Check network access to storage account
- Verify authentication is working

### Issue: "Security scan failed - too many findings"

**Triage Process:**

1. **Filter by severity:**
   - CRITICAL: Must fix immediately
   - HIGH: Fix before merge
   - MEDIUM: Fix or document suppression
   - LOW: Optional

2. **Common findings:**

   **CKV_AZURE_43: Storage account without private endpoint**
   ```hcl
   # Fix: Add private endpoint (should already be in storage module)
   resource "azurerm_private_endpoint" "storage" {
     # ... configuration
   }
   ```

   **CKV_AZURE_109: Key Vault without purge protection**
   ```hcl
   # Fix: Enable purge protection
   resource "azurerm_key_vault" "main" {
     purge_protection_enabled = true
     # ...
   }
   ```

   **TLS version issue**
   ```hcl
   # Fix: Set minimum TLS version
   min_tls_version = "1.2"
   ```

3. **Suppress if needed:**
   ```hcl
   # Add to resource if justified
   #checkov:skip=CKV_AZURE_XXX: Reason for suppression
   resource "azurerm_resource" "main" {
     # ...
   }
   ```

## 📝 Audit & Compliance

### Generate Compliance Report

```bash
# 1. Export all resources
az resource list \
  --resource-group rg-meddevice-prod-uks-001 \
  --query "[].{Name:name, Type:type, Location:location}" \
  -o table > compliance-resources-uks.txt

az resource list \
  --resource-group rg-meddevice-prod-ukw-001 \
  --query "[].{Name:name, Type:type, Location:location}" \
  -o table > compliance-resources-ukw.txt

# 2. Verify UK regions only
if grep -v "uksouth\|ukwest" compliance-resources-*.txt; then
  echo "❌ Non-UK resources found!"
else
  echo "✅ All resources in UK regions"
fi

# 3. Check log retention
az monitor log-analytics workspace show \
  --workspace-name log-meddevice-prod-uks-001 \
  --resource-group rg-meddevice-prod-uks-001 \
  --query "retentionInDays"

# 4. Verify encryption
az keyvault show \
  --name kv-meddevice-prod-uks \
  --query "{softDelete:properties.enableSoftDelete, purgeProtection:properties.enablePurgeProtection}"

# 5. Export audit logs
az monitor activity-log list \
  --start-time $(date -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ) \
  --offset 7d \
  --resource-group rg-meddevice-prod-uks-001 \
  > audit-log-7days.json
```

### Deployment Audit Trail

All deployments automatically create audit logs stored for 7 years:

**Location:** Azure Storage
- Account: `sttfstateprod001`
- Container: `tfstate-backups`
- File pattern: `prod-YYYYMMDD-HHMMSS.json`

**Contents:**
- Timestamp
- Commit SHA
- Actor (who deployed)
- Workflow run ID
- Reason for deployment

**Retrieve:**
```bash
az storage blob download \
  --account-name sttfstateprod001 \
  --container-name tfstate-backups \
  --name "prod-20241031-143000.json" \
  --file audit-log.json \
  --auth-mode login

cat audit-log.json | jq .
```

## 📞 Escalation Contacts

### On-Call Rotation

| Role | Primary | Backup | Contact |
|------|---------|--------|---------|
| DevOps Lead | Name | Name | @username |
| Security Lead | Name | Name | @username |
| Infrastructure Architect | Name | Name | @username |

### Escalation Path

1. **Level 1 - DevOps Engineer:**
   - Pipeline failures
   - Deployment issues
   - Configuration changes

2. **Level 2 - DevOps Lead:**
   - Production outages
   - Security incidents
   - Compliance violations

3. **Level 3 - CTO/VP Engineering:**
   - Major incidents
   - Data breaches
   - Regulatory issues

### Communication Channels

- **Slack:** #infrastructure-alerts (automated), #ops-team (human)
- **Email:** ops-team@yourcompany.com
- **PagerDuty:** (if configured)
- **GitHub:** Issues with `urgent` label

---

**Keep this runbook updated! Document all procedures and lessons learned.**