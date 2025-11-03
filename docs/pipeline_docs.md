# DevSecOps Pipeline Guide - Medical Device Compliant

## 🔒 Pipeline Security & Compliance Overview

This pipeline is designed for **medical device applications** with strict security, compliance, and safety requirements.

### Key Security Features

✅ **Multi-Layer Security Scanning**
- Checkov (Infrastructure security)
- TFSec (Terraform-specific security)
- Terrascan (Policy compliance)
- Gitleaks (Secrets detection)
- TruffleHog (Credential scanning)

✅ **Medical Device Compliance**
- UK data residency validation
- 7-year log retention verification
- TLS 1.2+ enforcement checks
- Private endpoint validation
- Automated compliance reporting

✅ **Deployment Safety**
- Business hours enforcement (9 AM - 5 PM UK, Mon-Fri)
- Multi-approver requirement for production
- State backup before every deployment
- Destructive change warnings
- Post-deployment validation
- Automatic rollback capability

✅ **Audit & Traceability**
- Complete audit trail (7-year retention)
- Change risk assessment
- Deployment records
- GitHub deployment tracking
- Automated notifications

## 📋 Pipeline Workflows

### 1. Pull Request Pipeline (`terraform-plan.yml`)

**Triggers:** Every PR that changes Terraform code

**Purpose:** Validate and review changes before merge

#### Workflow Steps:

```
1. Code Quality (2-3 min)
   ├── Terraform format check
   ├── Syntax validation
   └── Variable validation

2. Security Scanning (3-5 min)
   ├── Checkov (infrastructure security)
   ├── TFSec (Terraform security)
   ├── Terrascan (policy compliance)
   └── Results uploaded to GitHub Security

3. Secrets Detection (1-2 min)
   ├── Gitleaks (historical + current)
   └── TruffleHog (credential patterns)

4. Compliance Validation (1 min)
   ├── UK region enforcement
   ├── Log retention verification
   ├── TLS version checks
   └── Private endpoint validation

5. Terraform Plan (5-8 min)
   ├── Plan for Dev environment
   ├── Plan for Staging environment
   ├── Plan for Production environment
   └── Plans posted as PR comments

6. Cost Estimation (2-3 min)
   ├── Infracost breakdown
   └── Cost posted as PR comment

7. Risk Assessment (1-2 min)
   ├── Analyze changes (add/modify/destroy)
   ├── Identify high-risk changes
   ├── Calculate risk level
   └── Create risk assessment issue if needed

Total Time: ~15-25 minutes
```

#### What Gets Checked:

**Security:**
- No hardcoded secrets
- No insecure configurations
- Proper encryption settings
- Network security rules
- IAM permissions

**Compliance:**
- Data residency (UK only)
- Log retention (7 years for prod)
- TLS 1.2+ enforcement
- Private endpoints enabled
- Managed identities used

**Quality:**
- Terraform formatting
- Valid syntax
- No deprecated resources
- Best practices followed

#### Outputs:

1. **PR Comments:**
   - Terraform plan for each environment
   - Security scan results
   - Cost estimate
   - Risk assessment

2. **GitHub Security Tab:**
   - All security findings with severity
   - Remediation guidance
   - Trend analysis

3. **Artifacts (5 days):**
   - Terraform plans for each environment
   - Security scan reports
   - Compliance check results

### 2. Production Deployment Pipeline (`terraform-apply-prod.yml`)

**Triggers:**
- Push to `main` branch (changes to prod/ or modules/)
- Manual workflow_dispatch

**Purpose:** Safely deploy to production with multiple safety checks

#### Workflow Steps:

```
1. Pre-Deployment Validation (2-3 min)
   ├── Business hours check (9 AM - 5 PM UK, Mon-Fri)
   ├── Recent deployment check (>1 hour gap required)
   ├── Commit message validation
   ├── Security pre-check
   └── Manual cancellation window

2. Deployment Record Creation (30 sec)
   ├── Create GitHub deployment
   └── Set status to "in progress"

3. State Backup (1 min)
   ├── Backup current state file
   ├── Create backup metadata
   └── Store in Azure Storage (7-year retention)

4. Terraform Apply (10-30 min)
   ├── Initialize Terraform
   ├── Final plan review
   ├── Impact analysis (add/change/destroy count)
   ├── Destructive change warning (30 sec pause)
   ├── Apply changes
   ├── Capture outputs
   └── Upload audit artifacts

5. Post-Deployment Validation (5-10 min)
   ├── Wait for stabilization (2 min)
   ├── Traffic Manager health check
   ├── Primary region health check
   ├── Secondary region health check
   ├── Azure resource health check
   └── Validation summary

6. Status Updates (1 min)
   ├── Update GitHub deployment status
   ├── Create success/failure issue
   ├── Notify stakeholders
   └── Create audit log

Total Time: ~20-45 minutes
```

#### Safety Mechanisms:

**1. Business Hours Enforcement:**
```yaml
- Deployments only 9 AM - 5 PM UK time
- Monday to Friday only
- Can be overridden with manual trigger + justification
```

**2. Multi-Approver Requirement:**
```yaml
environment:
  name: production
  # Configured in GitHub: requires 2+ reviewers
```

**3. State Backup:**
- Automatic backup before every deployment
- Includes metadata (commit, actor, timestamp, reason)
- 7-year retention for compliance
- Enables rollback if needed

**4. Destructive Change Detection:**
```yaml
- Counts resources to destroy/replace
- Issues warning if detected
- 30-second pause for manual cancellation
- Creates high-risk assessment
```

**5. Post-Deployment Validation:**
- Health checks on all endpoints
- Azure resource status verification
- Automatic failure detection
- Rollback recommendation if unhealthy

#### Outputs:

1. **GitHub Deployment:**
   - Full deployment record
   - Success/failure status
   - Links to workflow run

2. **Issues Created:**
   - Success notification (with details)
   - OR Failure alert (with action items)

3. **Artifacts (90 days = compliance):**
   - Final Terraform plan
   - Apply output
   - Infrastructure outputs
   - Audit log (JSON)

4. **Step Summary:**
   - Deployment impact analysis
   - Health check results
   - Resource counts
   - Validation status

### 3. Development Deployment Pipeline (`terraform-apply-dev.yml`)

**Triggers:**
- Push to `main` (changes to dev/ or modules/)
- Manual workflow_dispatch

**Purpose:** Fast, automated deployment to dev environment

#### Key Differences from Production:

- ✅ No business hours restriction
- ✅ No multi-approver requirement
- ✅ Auto-approval enabled
- ✅ Faster execution (~5-10 min)
- ⚠️ Still includes security checks
- ⚠️ State backup still performed

## 🔐 Security Scanning Details

### Checkov

**What it checks:**
- Azure resource configurations
- Security group rules
- Encryption settings
- Public access controls
- IAM policies
- Kubernetes manifests (if applicable)

**Example findings:**
```
CKV_AZURE_35: Ensure storage account uses managed identity
CKV_AZURE_43: Ensure storage account has private endpoint
CKV_AZURE_109: Ensure key vault has purge protection
```

**Severity levels:**
- CRITICAL: Must fix before merge
- HIGH: Must fix before merge
- MEDIUM: Should fix, can be suppressed with justification
- LOW: Optional, best practice

### TFSec

**What it checks:**
- Terraform-specific security issues
- Resource configurations
- Module security
- Variable handling
- Output sensitivity

**Example findings:**
```
azure-storage-use-secure-tls-policy
azure-keyvault-ensure-secret-expiry
azure-network-no-public-egress
```

### Terrascan

**What it checks:**
- Policy compliance
- Industry standards (CIS, NIST, PCI-DSS)
- Best practices
- Compliance frameworks

### Gitleaks

**What it checks:**
- API keys
- Passwords
- Connection strings
- Private keys
- Tokens
- AWS credentials
- Azure credentials

**Scans:**
- Full Git history
- Current changes
- Configuration files

### TruffleHog

**What it checks:**
- High-entropy strings
- Credential patterns
- Secret patterns
- Token patterns

## 📊 Risk Assessment System

The pipeline automatically assesses the risk level of changes:

### Risk Levels:

**🟢 LOW RISK**
- Adding new resources
- Changing configuration (non-destructive)
- Documentation updates
- Output changes

**🟡 MEDIUM RISK**
- Replacing resources (recreation)
- Load balancer changes
- Network configuration changes
- IAM policy changes
- Any changes to Application Gateway or Traffic Manager

**🔴 HIGH RISK**
- Destroying resources
- Network infrastructure changes (VNet, subnets)
- Multiple resource replacements
- Critical service changes

### Risk-Based Actions:

**LOW:**
- Standard deployment process
- Single approver

**MEDIUM:**
- Additional validation recommended
- Test in staging first
- Monitoring plan required
- Have rollback ready

**HIGH:**
- Multiple approvers required (2+)
- Maintenance window required
- Stakeholder notification required
- Detailed rollback plan required
- Post-deployment monitoring required

## 🔄 Deployment Process

### For Developers:

1. **Create Feature Branch:**
   ```bash
   git checkout -b feature/add-new-resource
   ```

2. **Make Infrastructure Changes:**
   ```bash
   cd terraform/environments/dev
   terraform fmt
   # Make your changes
   ```

3. **Test Locally:**
   ```bash
   terraform plan
   # Review changes
   ```

4. **Commit and Push:**
   ```bash
   git add .
   git commit -m "feat: add new application gateway rule"
   git push origin feature/add-new-resource
   ```

5. **Create Pull Request:**
   - Go to GitHub
   - Create PR from your branch to `main`
   - Wait for automated checks (~15-25 min)

6. **Review Pipeline Results:**
   - Check security scan results
   - Review Terraform plans
   - Review cost estimate
   - Address any issues

7. **Get Approval:**
   - Request review from team
   - Address feedback
   - Get approval

8. **Merge:**
   - Merge PR to `main`
   - Dev deploys automatically
   - Staging requires approval
   - Production requires multiple approvals

### For Ops Team:

1. **Monitor PR Pipeline:**
   - Review security findings
   - Check compliance status
   - Assess risk level

2. **Review Changes:**
   - Understand infrastructure impact
   - Verify compliance requirements
   - Check for destructive changes

3. **Approve Deployment:**
   - For staging: Single approval
   - For production: Multiple approvals (2+)

4. **Monitor Deployment:**
   - Watch workflow progress
   - Check for errors
   - Verify health checks

5. **Post-Deployment:**
   - Verify application health
   - Check monitoring dashboards
   - Update documentation

## 🚨 Handling Failures

### Pipeline Failure:

1. **Check Workflow Logs:**
   - Identify failed step
   - Review error messages
   - Check which job failed

2. **Common Issues:**

   **Security Scan Failure:**
   ```bash
   # Review findings in Security tab
   # Fix issues in code
   # Re-run pipeline
   ```

   **Terraform Plan Failure:**
   ```bash
   # Check syntax errors
   # Verify variables
   # Check provider versions
   ```

   **Compliance Failure:**
   ```bash
   # Check region settings
   # Verify log retention
   # Check encryption settings
   ```

3. **Fix and Retry:**
   - Fix the issue
   - Push new commit
   - Pipeline runs automatically

### Deployment Failure:

1. **Immediate Actions:**
   - Check deployment status
   - Review failure logs
   - Assess production impact

2. **Decision Tree:**
   ```
   Is production degraded?
   ├── Yes → Immediate rollback
   │   ├── Use backed-up state
   │   └── Restore previous configuration
   └── No → Investigate and fix
       ├── Review error logs
       ├── Fix issue
       └── Re-deploy
   ```

3. **Rollback Procedure:**
   ```bash
   # Get backup state file
   TIMESTAMP="20241031-143000"  # From failure logs
   
   # Restore state
   az storage blob download \
     --account-name sttfstateprod001 \
     --container-name tfstate-backups \
     --name "prod-${TIMESTAMP}.tfstate" \
     --file prod.terraform.tfstate
   
   # Copy to state location
   az storage blob upload \
     --account-name sttfstateprod001 \
     --container-name tfstate \
     --file prod.terraform.tfstate \
     --name prod.terraform.tfstate \
     --overwrite
   
   # Revert code changes
   git revert <commit-sha>
   git push origin main
   
   # Let pipeline re-deploy
   ```

## 📋 Compliance Checklist

### Before Production Deployment:

- [ ] All security scans passed
- [ ] No secrets detected
- [ ] UK region compliance verified
- [ ] 7-year log retention confirmed
- [ ] Private endpoints enabled
- [ ] TLS 1.2+ enforced
- [ ] Managed identities used
- [ ] Business hours (9 AM - 5 PM UK)
- [ ] Multiple approvers ready
- [ ] Stakeholders notified
- [ ] Rollback plan prepared
- [ ] Monitoring dashboard ready

### After Production Deployment:

- [ ] Health checks passed
- [ ] Traffic Manager healthy
- [ ] Both regions responding
- [ ] Application Insights receiving data
- [ ] No error spikes
- [ ] Audit log created
- [ ] Documentation updated
- [ ] Stakeholders notified
- [ ] Deployment record complete

## 🔧 Pipeline Configuration

### Required GitHub Secrets:

```yaml
# Azure Authentication
AZURE_CLIENT_ID              # Service principal client ID
AZURE_TENANT_ID              # Azure AD tenant ID
AZURE_SUBSCRIPTION_ID_DEV    # Dev subscription
AZURE_SUBSCRIPTION_ID_STAGING # Staging subscription
AZURE_SUBSCRIPTION_ID_PROD   # Production subscription
AZURE_CLIENT_ID_DEV          # Dev SP (can be same)
AZURE_CLIENT_ID_STAGING      # Staging SP
AZURE_CLIENT_ID_PROD         # Production SP

# Optional
INFRACOST_API_KEY            # For cost estimation
```

### Required GitHub Environments:

**development:**
- No approvers required
- No branch restrictions

**staging:**
- 1 approver required
- Branch restriction: `main` only

**production:**
- 2+ approvers required
- Branch restriction: `main` only
- Wait timer: 5 minutes (optional)
- Deployment branches: `main` only

### Repository Settings:

```yaml
Branch Protection Rules (main):
  - Require pull request before merging
  - Require approvals: 1
  - Require status checks to pass
  - Require conversation resolution
  - Do not allow force pushes
  - Do not allow deletions
```

## 📊 Monitoring the Pipeline

### GitHub Actions:

1. **Workflows Tab:**
   - View all workflow runs
   - Filter by status/branch
   - Download artifacts

2. **Security Tab:**
   - View all security findings
   - Track trends over time
   - Export reports

3. **Deployments Tab:**
   - View deployment history
   - Check environment status
   - See active deployments

### Metrics to Track:

- Pipeline success rate
- Average deployment time
- Security findings over time
- Deployment frequency
- Mean time to recovery (MTTR)
- Change failure rate

## 🎓 Best Practices

### For Developers:

1. **Always run locally first:**
   ```bash
   terraform fmt
   terraform validate
   terraform plan
   ```

2. **Write good commit messages:**
   ```bash
   feat: add new App Service plan
   fix: correct network security group rule
   docs: update infrastructure README
   ```

3. **Small, focused changes:**
   - One feature per PR
   - Easier to review
   - Easier to rollback

4. **Test in dev first:**
   - Deploy to dev
   - Verify functionality
   - Then promote to staging/prod

### For Ops Team:

1. **Review security findings:**
   - Don't ignore warnings
   - Understand each finding
   - Track remediation

2. **Monitor deployments:**
   - Watch for anomalies
   - Check health metrics
   - Verify functionality

3. **Maintain audit trail:**
   - Document decisions
   - Track approvals
   - Keep deployment logs

4. **Regular compliance reviews:**
   - Monthly security reviews
   - Quarterly compliance audits
   - Annual certification reviews

## 🆘 Support & Troubleshooting

### Common Issues:

**1. "Security scan failed"**
- Check Security tab for findings
- Review severity levels
- Fix CRITICAL and HIGH findings
- Document suppressions for MEDIUM

**2. "Business hours check failed"**
- Deployment outside 9 AM - 5 PM UK
- Use manual workflow_dispatch with justification
- Or wait until business hours

**3. "State lock timeout"**
- Another deployment in progress
- Wait for completion
- Or force unlock (caution!)

**4. "Health check failed"**
- Services not yet ready
- Check Application Gateway status
- Verify App Service health
- Review application logs

### Getting Help:

- **Pipeline Issues**: Open GitHub issue with `pipeline` label
- **Security Questions**: Tag `@security-team`
- **Urgent Production Issues**: Tag `@ops-lead` and `@security-lead`
- **Documentation**: Check README.md and QUICKSTART.md

---

**This pipeline ensures safe, compliant, and traceable infrastructure deployments for medical device applications. 🏥**