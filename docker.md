# DevSecOps Pipeline - Security Features Documentation

## 📋 Table of Contents
- [Overview](#overview)
- [Security Architecture](#security-architecture)
- [Container Security](#container-security)
- [Pipeline Security Stages](#pipeline-security-stages)
- [Security Tools Explained](#security-tools-explained)
- [Setup Instructions](#setup-instructions)
- [Security Best Practices](#security-best-practices)
- [Monitoring & Remediation](#monitoring--remediation)

---

## 🎯 Overview

This DevSecOps pipeline implements a **defense-in-depth** security strategy, integrating security at every stage of the software development lifecycle. The pipeline follows the **shift-left security** principle, catching vulnerabilities early before they reach production.

### Key Security Principles
- **Shift-Left Security**: Security testing occurs early in the development process
- **Zero Trust**: Never trust, always verify - every artifact is scanned
- **Defense in Depth**: Multiple layers of security controls
- **Least Privilege**: Containers run as non-root users with minimal permissions
- **Supply Chain Security**: SBOM generation and dependency tracking
- **Compliance by Design**: Automated policy enforcement

---

## 🏗️ Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY PIPELINE                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Stage 1: PRE-BUILD SECURITY SCANNING                │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  • Secret Scanning (Gitleaks)                        │  │
│  │  • SAST - Static Analysis (CodeQL, Semgrep)          │  │
│  │  • Dependency Scanning (.NET Audit)                  │  │
│  │  • License Compliance                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Stage 2: BUILD & CONTAINER SECURITY                 │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  • Secure Multi-stage Build                          │  │
│  │  • Container Vulnerability Scan (Trivy, Grype)       │  │
│  │  • Docker Best Practices (Dockle)                    │  │
│  │  • CVE Analysis (Docker Scout, Snyk)                 │  │
│  │  • SBOM Generation                                   │  │
│  │  • Image Signing (Cosign)                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Stage 3: POST-BUILD COMPLIANCE                      │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  • Policy Enforcement (OPA)                          │  │
│  │  • Azure Policy Compliance                           │  │
│  │  • Audit Logging                                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🐳 Container Security

### Non-Root User Execution
**Why it matters**: Running containers as root is a major security risk. If an attacker compromises your container, they have root-level access.

**Implementation**:
```dockerfile
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
USER appuser
```

**Benefits**:
- Limits blast radius of container escape vulnerabilities
- Prevents privilege escalation attacks
- Meets CIS Docker Benchmark recommendations
- Required for most compliance frameworks (PCI-DSS, SOC 2)

### Multi-Stage Builds
**Why it matters**: Reduces attack surface by excluding build tools and unnecessary dependencies from the final image.

**Implementation**:
- **Build Stage**: Contains SDK, build tools, source code
- **Publish Stage**: Optimizes and prepares application
- **Runtime Stage**: Contains only runtime and published app (60-80% smaller)

**Benefits**:
- Smaller image size = fewer vulnerabilities
- No build tools in production = reduced attack surface
- Faster deployment and pull times

### Health Checks
**Why it matters**: Enables container orchestrators to detect and replace unhealthy containers automatically.

**Implementation**:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

**Benefits**:
- Automatic detection of application failures
- Self-healing in Kubernetes/AKS environments
- Prevents routing traffic to unhealthy containers

### File Permissions
**Why it matters**: Proper ownership prevents unauthorized file modifications.

**Implementation**:
```dockerfile
COPY --from=publish --chown=appuser:appgroup /app/publish .
```

---

## 🔒 Pipeline Security Stages

### Stage 1: Pre-Build Security Scanning

This stage runs before any code is compiled or images are built, catching issues at the earliest possible point.

#### Why Pre-Build Scanning?
- **Cheapest to fix**: Issues found here are easiest and cheapest to remediate
- **Fast feedback**: Developers get immediate feedback on security issues
- **Prevents vulnerable code**: Stops insecure code before it's committed

---

## 🛠️ Security Tools Explained

### 1. **Gitleaks** - Secret Scanning
**Category**: Secret Detection  
**What it does**: Scans code, commit history, and files for hardcoded secrets like API keys, passwords, and tokens.

**Why we use it**:
- Prevents credential leaks that lead to 90% of data breaches
- Scans entire Git history, not just current code
- Catches secrets before they reach public repositories

**What it catches**:
- AWS keys, Azure credentials, GCP tokens
- Database connection strings
- API keys (Slack, Stripe, etc.)
- Private keys and certificates
- Generic high-entropy strings (custom secrets)

**Configuration**:
```yaml
- name: Secret Scanning with Gitleaks
  uses: gitleaks/gitleaks-action@v2
```

**Remediation**: If secrets are found, immediately rotate credentials and use Azure Key Vault or GitHub Secrets.

---

### 2. **CodeQL** - Static Application Security Testing (SAST)
**Category**: Static Analysis  
**What it does**: Analyzes source code without executing it to find security vulnerabilities and code quality issues.

**Why we use it**:
- GitHub's enterprise-grade security scanner
- Understands code context and data flow
- Finds vulnerabilities that simple pattern matching misses
- Free for public repositories

**What it catches**:
- SQL Injection vulnerabilities
- Cross-Site Scripting (XSS)
- Path traversal issues
- Command injection
- Insecure deserialization
- Use of weak cryptography
- Authentication bypasses

**How it works**:
1. Builds a semantic code database
2. Queries database with security patterns
3. Tracks data flow through your application
4. Reports vulnerabilities with code context

**Configuration**:
```yaml
- name: SAST - CodeQL Analysis
  uses: github/codeql-action/init@v3
  with:
    languages: csharp
```

**Integration**: Results appear in GitHub Security tab with detailed remediation guidance.

---

### 3. **Semgrep** - Lightweight SAST
**Category**: Static Analysis  
**What it does**: Fast, lightweight pattern-based code scanning for security issues and bugs.

**Why we use it**:
- Faster than CodeQL (runs in seconds)
- Uses community-maintained rules
- Complements CodeQL with different detection methods
- Excellent for custom security policies

**What it catches**:
- OWASP Top 10 vulnerabilities
- Common security anti-patterns
- Framework-specific issues (.NET Core)
- Business logic flaws
- Security misconfigurations

**Rule Sets Used**:
- `p/security-audit`: General security issues
- `p/secrets`: Additional secret detection
- `p/owasp-top-ten`: OWASP Top 10 vulnerabilities

**Configuration**:
```yaml
- name: Run Semgrep SAST
  uses: returntocorp/semgrep-action@v1
  with:
    config: p/security-audit p/secrets p/owasp-top-ten
```

---

### 4. **.NET Security Audit** - Dependency Scanning
**Category**: Software Composition Analysis (SCA)  
**What it does**: Scans NuGet packages for known vulnerabilities (CVEs).

**Why we use it**:
- 80% of code in modern apps is from dependencies
- Vulnerabilities in dependencies are commonly exploited (Log4Shell, etc.)
- Native .NET tool with official CVE database

**What it catches**:
- Known CVEs in NuGet packages
- Transitive dependency vulnerabilities
- Outdated packages with security fixes

**Severity Levels**:
- **Critical**: Immediate action required
- **High**: Fix within days
- **Moderate**: Fix within sprint
- **Low**: Address when convenient

**Configuration**:
```yaml
- name: Run .NET Security Audit
  run: dotnet list package --vulnerable --include-transitive
```

**Pipeline Behavior**: Fails build if critical vulnerabilities found.

---

### 5. **Trivy** - Container Vulnerability Scanner
**Category**: Container Security  
**What it does**: Comprehensive vulnerability scanner for container images, file systems, and Git repositories.

**Why we use it**:
- Industry standard container scanner
- Fast and accurate CVE detection
- Integrates with GitHub Security tab
- Scans OS packages and application dependencies

**What it scans**:
- OS packages (Alpine, Debian, Ubuntu, etc.)
- Application dependencies (NuGet, npm, pip, etc.)
- Infrastructure as Code (Dockerfile)
- Kubernetes manifests
- Configuration files

**Vulnerability Database**:
- NVD (National Vulnerability Database)
- Vendor-specific advisories
- GitHub Advisory Database
- Updated daily

**Configuration**:
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    severity: 'CRITICAL,HIGH'
```

**Output**: SARIF format uploaded to GitHub Security for tracking and remediation.

---

### 6. **Grype** - Additional CVE Scanner
**Category**: Container Security  
**What it does**: Anchore's vulnerability scanner that provides a second opinion on CVE detection.

**Why we use it**:
- Different vulnerability database (overlaps ~95% with Trivy)
- Catches CVEs that Trivy might miss
- Defense in depth - multiple scanners increase coverage
- Better handling of distroless images

**Configuration**:
```yaml
- name: Scan with Grype
  uses: anchore/scan-action@v3
  with:
    fail-build: true
    severity-cutoff: critical
```

**When it fails**: Only fails on critical vulnerabilities, allowing flexibility for high/medium issues.

---

### 7. **Docker Scout** - Docker Native CVE Scanner
**Category**: Container Security  
**What it does**: Docker's official security scanner integrated into Docker Hub and registries.

**Why we use it**:
- Native Docker integration
- Real-time vulnerability intelligence
- Container image policy enforcement
- Base image recommendations

**Unique Features**:
- Suggests alternative base images with fewer vulnerabilities
- Policy-as-code enforcement
- Integration with Docker Hub analytics

**Configuration**:
```yaml
- name: Docker Scout CVE Scan
  uses: docker/scout-action@v1
  with:
    only-severities: critical,high
```

---

### 8. **Snyk** - Commercial-Grade Security
**Category**: Container & Application Security  
**What it does**: Enterprise security platform for containers, code, and open source dependencies.

**Why we use it**:
- Developer-friendly remediation advice
- Automated fix PRs
- License compliance checking
- Extensive vulnerability database

**What makes Snyk special**:
- Provides specific upgrade paths
- Calculates exploitability scores
- Integrates with IDEs for real-time feedback
- Prioritizes vulnerabilities by risk

**Configuration**:
```yaml
- name: Scan image with Snyk
  uses: snyk/actions/docker@master
  with:
    args: --severity-threshold=high
```

**Note**: Requires `SNYK_TOKEN` secret (free tier available at snyk.io).

---

### 9. **Dockle** - Docker Best Practices Linter
**Category**: Configuration Security  
**What it does**: Checks Docker images against best practices and CIS Docker Benchmark.

**Why we use it**:
- Enforces Docker security standards
- Catches misconfigurations before deployment
- Complements vulnerability scanners

**What it checks**:
- Container runs as root (CIS 4.1)
- Health check present (CIS 4.6)
- Unnecessary packages installed
- Exposed unnecessary ports
- Secrets in environment variables
- Image metadata best practices

**Configuration**:
```yaml
- name: Run Dockle
  uses: erzz/dockle-action@v1
  with:
    exit-level: warn
```

**Checkpoints**:
- **FATAL**: Security critical (fails build)
- **WARN**: Security concern (logged)
- **INFO**: Best practice recommendation

---

### 10. **SBOM Generation** - Software Bill of Materials
**Category**: Supply Chain Security  
**What it does**: Creates a comprehensive inventory of all software components in your container.

**Why we use it**:
- Required for supply chain security (NIST, Executive Order 14028)
- Enables rapid response to new vulnerabilities
- Provides transparency for security audits
- Required by many compliance frameworks

**SBOM Contents**:
- All package names and versions
- Dependency relationships
- License information
- Package origins and checksums
- Vulnerability associations

**Format**: SPDX (Software Package Data Exchange) - industry standard format.

**Configuration**:
```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    format: spdx-json
```

**Use Cases**:
- Vulnerability tracking across time
- License compliance audits
- Incident response (know what's affected)
- Customer security questionnaires

---

### 11. **Cosign** - Image Signing
**Category**: Supply Chain Security  
**What it does**: Cryptographically signs container images to verify authenticity and integrity.

**Why we use it**:
- Prevents tampering between build and deployment
- Verifies image provenance
- Required for zero-trust deployments
- Part of Sigstore project (CNCF)

**How it works**:
1. Generate key pair (private/public)
2. Sign image with private key after successful scans
3. Store signature in registry
4. Verify signature before deployment

**Configuration**:
```yaml
- name: Sign image with Cosign
  run: cosign sign --key cosign.key $IMAGE
```

**Required Secrets**:
- `COSIGN_PRIVATE_KEY`: Your signing key
- `COSIGN_PASSWORD`: Key password

**Verification**: Use admission controllers (like Kyverno or OPA) to enforce signature verification.

---

### 12. **OPA** - Open Policy Agent
**Category**: Policy Enforcement  
**What it does**: Policy-as-code engine that enforces security and compliance policies.

**Why we use it**:
- Codifies security requirements
- Prevents non-compliant deployments
- Enables GitOps for security policies
- Industry standard (CNCF graduated)

**Example Policies**:
```rego
# Deny containers running as root
deny[msg] {
    input.spec.containers[_].securityContext.runAsNonRoot != true
    msg = "Container must not run as root"
}

# Require resource limits
deny[msg] {
    not input.spec.containers[_].resources.limits
    msg = "Container must have resource limits"
}
```

**What it validates**:
- Container security contexts
- Network policies
- Resource quotas
- Image sources (approved registries only)
- Compliance requirements

---

### 13. **Azure Policy Compliance**
**Category**: Cloud Governance  
**What it does**: Validates Azure resources against organizational policies and compliance standards.

**Why we use it**:
- Ensures Azure resources meet security standards
- Validates ACR configuration
- Enforces encryption requirements
- Audits compliance continuously

**What it checks**:
- Container registry has private endpoint
- Images are encrypted at rest
- Admin user disabled (unless explicitly allowed)
- Diagnostic logging enabled
- Network access properly restricted

---

## 🚀 Setup Instructions

### 1. Enable GitHub Security Features

```bash
# In your GitHub repository:
Settings → Code security and analysis

Enable:
☑️ Dependency graph
☑️ Dependabot alerts
☑️ Dependabot security updates
☑️ Code scanning (CodeQL)
☑️ Secret scanning
```

### 2. Configure GitHub Secrets

Navigate to: `Settings → Secrets and variables → Actions → New repository secret`

**Required Secrets**:
```
ACR_USERNAME          # Azure Container Registry admin username
ACR_PASSWORD          # Azure Container Registry admin password
```

**Optional Secrets** (for enhanced security):
```
SNYK_TOKEN            # From snyk.io (free tier available)
COSIGN_PRIVATE_KEY    # Generate with: cosign generate-key-pair
COSIGN_PASSWORD       # Password for cosign key
GITLEAKS_LICENSE      # For Gitleaks Pro features
AZURE_SUBSCRIPTION_ID # For Azure Policy checks
```

### 3. Generate Cosign Keys (Optional)

```bash
# Install cosign
brew install cosign  # macOS
# OR
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Generate key pair
cosign generate-key-pair

# Add cosign.key contents to COSIGN_PRIVATE_KEY secret
# Add password to COSIGN_PASSWORD secret
```

### 4. Create Health Endpoint

Add to your .NET application:

```csharp
// Program.cs or Startup.cs
app.MapGet("/health", () => Results.Ok(new { 
    status = "Healthy",
    timestamp = DateTime.UtcNow 
}));
```

### 5. Create OPA Policies (Optional)

```bash
mkdir -p policies
```

Create `policies/security.rego`:
```rego
package main

deny[msg] {
    input.user == "root"
    msg = "Container must not run as root"
}

deny[msg] {
    not input.healthcheck
    msg = "Container must have a healthcheck"
}
```

### 6. Azure Container Registry Setup

```bash
# Enable admin user (for username/password auth)
az acr update -n yourregistry --admin-enabled true

# Get credentials
az acr credential show -n yourregistry

# Alternative: Use Service Principal (recommended for production)
az ad sp create-for-rbac \
  --name "github-actions-acr" \
  --role "AcrPush" \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.ContainerRegistry/registries/{registry-name}
```

---

## 🛡️ Security Best Practices

### 1. **Regular Updates**
- Update base images weekly (`mcr.microsoft.com/dotnet/aspnet:8.0`)
- Keep GitHub Actions up to date
- Monitor security advisories

### 2. **Secrets Management**
- Never commit secrets to Git
- Use Azure Key Vault for production secrets
- Rotate credentials quarterly
- Use managed identities where possible

### 3. **Vulnerability Response**
- **Critical**: Patch within 24 hours
- **High**: Patch within 7 days
- **Medium**: Patch within 30 days
- **Low**: Address in next sprint

### 4. **Image Hygiene**
- Only use official base images
- Pin specific image versions (e.g., `8.0.1` not `latest`)
- Scan images before and after deployment
- Remove images older than 90 days

### 5. **Network Security**
- Use private endpoints for ACR
- Enable Azure Private Link
- Implement network policies in Kubernetes
- Use Azure Firewall for egress filtering

### 6. **Access Control**
- Disable ACR admin user in production
- Use Azure AD authentication
- Implement RBAC with least privilege
- Enable audit logging

---

## 📊 Monitoring & Remediation

### GitHub Security Tab
All security findings appear in: `Security → Code scanning alerts`

**Features**:
- Centralized vulnerability dashboard
- Automatic issue creation
- Dependency graph visualization
- Security advisories

### Viewing Scan Results

```bash
# View Trivy results locally
trivy image yourregistry.azurecr.io/your-app:latest

# View Dockle results
dockle yourregistry.azurecr.io/your-app:latest

# Download SBOM artifact
gh run download <run-id> -n sbom
```

### Remediation Workflow

1. **Identify**: Security scanner finds vulnerability
2. **Assess**: Review severity 