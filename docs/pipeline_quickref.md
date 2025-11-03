# Pipeline Quick Reference Card

## 🚀 Common Tasks

### Deploy to Development
```bash
# Push to main with dev changes
git checkout main
git pull
# Make changes to terraform/environments/dev/ or terraform/modules/
git add .
git commit -m "feat: add new resource"
git push origin main
# ✅ Deploys automatically (no approval needed)
```

### Deploy to Production
```bash
# Same as above, but with prod changes
# Make changes to terraform/environments/prod/
git push origin main
# ⏸️ Requires 2+ approvers
# ⏸️ Only works 9 AM - 5 PM UK, Mon-Fri
```

### Review a PR
```bash
# 1. Check security findings (GitHub Security tab)
# 2. Review Terraform plans (PR comments)
# 3. Check cost estimate (PR comment)
# 4. Review risk assessment (PR comment)
# 5. Approve if all checks pass
```

## 🔍 Checking Pipeline Status

### View Current Deployments
```bash
# GitHub Actions → Workflows
# Or use CLI:
gh run list --limit 5
```

### Check Last Deployment Status
```bash
gh run list --workflow="Deploy to Production" --limit 1
```

### View Security Findings
```bash
# GitHub → Security → Code scanning alerts
```

## 🚨 Emergency Procedures

### Production is Down
```bash
# 1. Get last good state backup
BACKUP=$(az storage blob list \
  --account-name sttfstateprod001 \
  --container-name tfstate-backups \
  --prefix "prod-" \
  --auth-mode login \
  --query "reverse(sort_by([].{name:name}, &name))[1].name" -o tsv)

# 2. Download it
az storage blob download \
  --account-name sttfstateprod001 \
  --container-name tfstate-backups \
  --name $BACKUP \
  --file rollback.tfstate \
  --auth-mode login

# 3. Replace current state
az storage blob upload \
  --account-name sttfstateprod001 \
  --container-name tfstate \
  --name prod.terraform.tfstate \
  --file rollback.tfstate \
  --overwrite \
  --auth-mode login

# 4. Revert code change
git revert <commit-sha>
git push origin main

# 5. Approve re-deployment
```

### Deployment Stuck
```bash
# Cancel workflow run
gh run cancel <run-id>

# Force unlock Terraform state (if needed)
cd terraform/environments/prod
terraform force-unlock <LOCK_ID>
```

### Security Alert
```bash
# 1. Check Security tab for details
# 2. Rotate affected credentials
az ad sp credential reset --id <sp-id>

# 3. Remove secret from Git history
git filter-repo --path <file> --invert-paths
git push --force
```

## 📊 Useful Queries

### Check Production Health
```bash
# Traffic Manager
az network traffic-manager endpoint list \
  --profile-name tm-meddevice-prod-global \
  --resource-group rg-meddevice-prod-global-001 \
  --query "[].{name:name, status:endpointMonitorStatus}"

# Application Gateway
az network application-gateway show-backend-health \
  --name agw-meddevice-prod-uks-001 \
  --resource-group rg-meddevice-prod-uks-001
```

### View Recent Deployments
```bash
gh run list \
  --workflow="Deploy to Production" \
  --limit 10 \
  --json conclusion,createdAt,displayTitle \
  --jq '.[] | "\(.createdAt) \(.conclusion) \(.displayTitle)"'
```

### Check Today's Costs
```bash
az consumption usage list \
  --start-date $(date +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[].{date:usageStart, cost:pretaxCost, resource:instanceName}" \
  -o table
```

### View Application Errors
```bash
az monitor app-insights query \
  --app appi-meddevice-prod-uks-001 \
  --analytics-query "exceptions | where timestamp > ago(1h) | summarize count() by problemId" \
  --resource-group rg-meddevice-prod-uks-001
```

## 🔑 Key Contacts

| Role | Contact | When to Contact |
|------|---------|-----------------|
| DevOps Team | @ops-team | Pipeline issues, deployments |
| Security Team | @security-team | Security findings, compliance |
| On-Call | See OPS_RUNBOOK.md | Production incidents |

## 📋 Pre-Deployment Checklist

**Before Creating PR:**
- [ ] Tested locally (`terraform plan`)
- [ ] Formatted code (`terraform fmt`)
- [ ] No secrets in code
- [ ] Good commit message

**Before Approving PR:**
- [ ] All security scans passed
- [ ] Terraform plans reviewed
- [ ] Cost estimate reasonable
- [ ] Risk level acceptable

**Before Production Deploy:**
- [ ] Tested in dev ✓
- [ ] Tested in staging ✓
- [ ] Business hours (9 AM - 5 PM UK)
- [ ] Approvers available
- [ ] Stakeholders notified (if high risk)

## 🎯 Pipeline Decision Tree

```
Need to deploy?
├─ To Dev?
│  └─ Push to main → Auto-deploys
├─ To Staging?
│  └─ Push to main → Needs 1 approval
└─ To Production?
   ├─ Outside business hours?
   │  └─ Use manual trigger with reason
   └─ During business hours?
      └─ Push to main → Needs 2+ approvals
```

## 📞 Support Links

- **Pipeline Guide:** `PIPELINE_GUIDE.md`
- **Ops Runbook:** `OPS_RUNBOOK.md`
- **Main README:** `README.md`
- **GitHub Actions:** https://github.com/your-org/your-repo/actions
- **Azure Portal:** https://portal.azure.com

## 🛑 When NOT to Deploy

- ❌ During incidents
- ❌ Before major holidays
- ❌ Without testing in dev/staging
- ❌ With failing security scans
- ❌ Without approvers available
- ❌ During system maintenance
- ❌ Outside business hours (unless emergency)

## ✅ Signs of Healthy Pipeline

- ✅ All checks passing on main
- ✅ No critical security findings
- ✅ Deployment success rate > 95%
- ✅ Average deployment time < 30 min
- ✅ No state lock issues
- ✅ Health checks passing
- ✅ Cost within budget

## 🔧 Quick Fixes

**"Terraform format check failed"**
```bash
terraform fmt -recursive terraform/
git add .
git commit --amend --no-edit
git push --force
```

**"Checkov failed"**
```bash
# Review findings
# Fix issues or add suppression comments
#checkov:skip=CKV_AZURE_XX: <reason>
```

**"State locked"**
```bash
# Wait 15 minutes, or if urgent:
terraform force-unlock <LOCK_ID>
```

**"Business hours check failed"**
```bash
# Use manual workflow_dispatch
# Go to Actions → Deploy to Production → Run workflow
# Provide justification in "reason" field
```

---

**Print this and keep it handy! 📄**