# Architecture Decision Records (ADR)

## About This Document

This document captures all major architectural and technical decisions made for the medical device application infrastructure on Azure. Each decision is documented with context, alternatives considered, and rationale.

**Format:** ADR format based on Michael Nygard's template

---

## ADR-001: Multi-Region Deployment Strategy

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

The medical device application requires high availability and disaster recovery capabilities. We need to determine whether to deploy in a single region or multiple regions.

**Decision:**

Deploy to **two Azure regions** (UK South as primary, UK West as secondary) in an active-active configuration.

**Alternatives Considered:**

1. **Single Region Deployment**
   - *Pros:* Lower cost (~£700/month), simpler architecture, easier management
   - *Cons:* Single point of failure, no regional DR, limited to single region SLA (99.95%)
   - *Why rejected:* Insufficient for medical device availability requirements

2. **Three or More Regions**
   - *Pros:* Maximum availability, better global distribution
   - *Cons:* Significantly higher cost (£2,000+/month), increased complexity, data consistency challenges
   - *Why rejected:* Over-engineered for UK-only user base, unnecessary cost

3. **Active-Passive (Primary + DR)**
   - *Pros:* Lower cost than active-active, simpler failover
   - *Cons:* Unused capacity in DR region, slower failover, DR region not tested regularly
   - *Why rejected:* Wastes resources, doesn't provide load distribution

**Rationale:**

- **Medical device requirements:** Need 99.99% availability (active-active provides this)
- **UK data residency:** Both regions within UK borders
- **Load distribution:** Traffic Manager can distribute load for better performance
- **Cost-effective DR:** Secondary region actively serves traffic (not idle)
- **Regular failover testing:** Both regions always active ensures they work
- **Regional failure protection:** Can survive entire region failure
- **Acceptable cost:** ~£1,500/month for both regions is justifiable for medical device

**Consequences:**

- ✅ High availability (99.99% SLA)
- ✅ Better performance (load distributed)
- ✅ Regular DR testing (both always active)
- ❌ Higher cost than single region
- ❌ Increased deployment complexity
- ⚠️ Need to manage data consistency across regions

---

## ADR-002: Availability Zones Strategy

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Within each region, we need to decide on availability zone strategy for App Services and Application Gateway.

**Decision:**

Deploy across **all 3 availability zones** in each region with zone-redundant configuration.

**Alternatives Considered:**

1. **No Availability Zones (Single Zone)**
   - *Pros:* Lowest cost, simplest deployment
   - *Cons:* 99.95% SLA only, vulnerable to zone failures
   - *Why rejected:* Insufficient availability for medical device

2. **2 Availability Zones**
   - *Pros:* Better than single zone, lower cost than 3 zones
   - *Cons:* Only 99.99% SLA (same as 3 zones), less resilient
   - *Why rejected:* No cost benefit over 3 zones, less resilient

3. **Zone-Pinned (specific zone per instance)**
   - *Pros:* More control over placement
   - *Cons:* Manual zone management, less automatic failover
   - *Why rejected:* Zone-balancing provides automatic distribution

**Rationale:**

- **Maximum availability:** 99.99% SLA with zone redundancy
- **Datacenter failure protection:** Can survive entire datacenter failure
- **Automatic distribution:** Azure handles zone balancing
- **No cost penalty:** 3 zones costs same as 2 zones for Premium v3
- **Medical device compliance:** Requires highest availability
- **Minimal latency:** All zones within same region (<2ms latency)

**Consequences:**

- ✅ 99.99% SLA per region
- ✅ Automatic failover between zones
- ✅ Protection against datacenter failures
- ✅ Load distributed across 3 zones
- ⚠️ Minimum 3 instances required (1 per zone)
- ⚠️ Requires Premium v3 SKU (higher cost)

---

## ADR-003: Compute Platform Selection

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Need to select the compute platform for hosting the medical device application.

**Decision:**

Use **Azure App Service (Premium v3)** with zone redundancy instead of Azure Functions.

**Alternatives Considered:**

1. **Azure Functions (Consumption/Premium)**
   - *Pros:* Serverless, auto-scaling, pay-per-execution
   - *Cons:* Cold start issues, 10-minute timeout, less control, harder to predict costs
   - *Why rejected:* Medical device needs predictable performance, not suitable for long-running operations

2. **Azure Kubernetes Service (AKS)**
   - *Pros:* Maximum flexibility, container orchestration, portable
   - *Cons:* High complexity, requires Kubernetes expertise, operational overhead, higher cost
   - *Why rejected:* Over-engineered for requirements, team expertise, maintenance burden

3. **Virtual Machines (VMs)**
   - *Pros:* Maximum control, can run anything
   - *Cons:* Manual scaling, OS patching required, higher operational burden
   - *Why rejected:* Too much operational overhead, doesn't leverage PaaS benefits

4. **Azure Container Apps**
   - *Pros:* Serverless containers, easier than AKS
   - *Cons:* Newer service, less mature, limited enterprise features
   - *Why rejected:* Prefer more mature service for medical device

**Rationale:**

- **Mature platform:** App Service is well-established and proven
- **Zone redundancy:** Built-in support in Premium v3
- **Managed service:** No OS patching, automatic updates
- **Predictable performance:** Always-on instances, no cold starts
- **VNet integration:** Built-in private networking
- **Monitoring:** Deep integration with Application Insights
- **Deployment slots:** Blue-green deployments supported
- **Scaling:** Automatic horizontal scaling across zones
- **Medical device suitable:** Predictable, reliable, well-documented

**Consequences:**

- ✅ Predictable performance and costs
- ✅ Zone redundancy built-in
- ✅ Mature, well-supported platform
- ✅ Easy integration with Azure services
- ✅ Deployment slots for zero-downtime
- ❌ Higher base cost than Functions (~£250/month per region)
- ❌ Less flexible than containers/VMs
- ⚠️ Requires Premium v3 for zone redundancy

---

## ADR-004: Load Balancing Strategy

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Need to implement load balancing at both regional and global levels.

**Decision:**

Use **Application Gateway (WAF v2)** for regional load balancing and **Traffic Manager** for global routing.

**Alternatives Considered:**

### Regional Load Balancer:

1. **Azure Load Balancer (Standard)**
   - *Pros:* Lower cost, simple Layer 4 load balancing
   - *Cons:* No WAF, no SSL termination, no URL-based routing
   - *Why rejected:* Missing WAF required for medical device security

2. **Azure Front Door**
   - *Pros:* Global CDN, advanced routing, WAF included
   - *Cons:* Higher cost, designed for global distribution (redundant with Traffic Manager)
   - *Why rejected:* Overlaps with Traffic Manager, unnecessary cost

3. **No Load Balancer (Direct to App Service)**
   - *Pros:* Lowest cost, simplest
   - *Cons:* No WAF protection, no advanced routing, limited control
   - *Why rejected:* WAF required for medical device security

### Global Load Balancer:

1. **Azure Front Door**
   - *Pros:* Advanced routing, CDN, single point of management
   - *Cons:* Higher cost (£300+/month), overlaps with Application Gateway
   - *Why rejected:* Expensive, would duplicate Application Gateway features

2. **Azure Load Balancer (Cross-Region)**
   - *Pros:* Layer 4 load balancing, lower cost
   - *Cons:* No health-based routing, no geographic routing
   - *Why rejected:* Traffic Manager provides better health-based routing

**Rationale:**

- **Application Gateway (Regional):**
  - WAF v2 provides OWASP 3.2 protection (medical device security requirement)
  - SSL termination at edge
  - Zone redundancy support
  - Health probes for backend monitoring
  - URL-based routing capabilities
  - Integration with App Service

- **Traffic Manager (Global):**
  - DNS-based routing (minimal latency)
  - Performance-based routing (route to closest healthy region)
  - Health monitoring of regional endpoints
  - Low cost (£5/month)
  - Simple failover logic
  - No single point of failure (DNS-based)

**Consequences:**

- ✅ WAF protection at application edge
- ✅ Health-based global routing
- ✅ Automatic regional failover
- ✅ Zone redundancy for Application Gateway
- ✅ Cost-effective global distribution
- ❌ Application Gateway is expensive (~£350/month per region)
- ⚠️ Two-tier load balancing adds complexity
- ⚠️ Need to configure health probes at both levels

---

## ADR-005: Infrastructure as Code Tool

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Need to select IaC tool for managing Azure infrastructure.

**Decision:**

Use **Terraform** with HCL for infrastructure provisioning.

**Alternatives Considered:**

1. **Azure Bicep**
   - *Pros:* Native Azure, better Azure integration, simpler syntax
   - *Cons:* Azure-only, less mature ecosystem, smaller community
   - *Why rejected:* Want multi-cloud skills portability

2. **ARM Templates (JSON)**
   - *Pros:* Native Azure, no additional tools
   - *Cons:* Verbose, difficult to read/maintain, limited reusability
   - *Why rejected:* Poor developer experience, hard to maintain

3. **Pulumi**
   - *Pros:* Use programming languages (Python, TypeScript), strong typing
   - *Cons:* Smaller community, less mature, requires programming knowledge
   - *Why rejected:* Team familiarity with HCL, prefer declarative approach

4. **Ansible**
   - *Pros:* Configuration management + provisioning, agentless
   - *Cons:* Procedural not declarative, slower, less cloud-native
   - *Why rejected:* Not designed for cloud infrastructure provisioning

**Rationale:**

- **Industry standard:** Most widely used IaC tool
- **Multi-cloud:** Can extend to other clouds if needed
- **Mature ecosystem:** Large community, lots of modules
- **Declarative:** Easier to understand desired state
- **State management:** Built-in state tracking
- **Module reusability:** Can create reusable modules
- **Provider ecosystem:** Azure provider is mature and well-maintained
- **Team skills:** Terraform skills are widely available
- **CI/CD integration:** Excellent GitHub Actions support

**Consequences:**

- ✅ Industry-standard tool
- ✅ Large community and ecosystem
- ✅ Declarative syntax is readable
- ✅ Good state management
- ✅ Reusable modules
- ❌ State management adds complexity
- ❌ Learning curve for team
- ⚠️ Need to manage state storage securely

---

## ADR-006: Security Scanning Tools

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Medical device compliance requires comprehensive security scanning. Need to select tools for infrastructure security validation.

**Decision:**

Use **multiple security scanning tools** in the pipeline: Checkov, TFSec, Terrascan, Gitleaks, and TruffleHog.

**Alternatives Considered:**

1. **Single Tool (e.g., only Checkov)**
   - *Pros:* Simpler, faster pipelines, easier to manage
   - *Cons:* Single tool may miss issues, no redundancy
   - *Why rejected:* Medical device requires comprehensive scanning

2. **Commercial Tools (e.g., Snyk, Prisma Cloud)**
   - *Pros:* Enterprise support, advanced features, single dashboard
   - *Cons:* Expensive (£5,000+/year), vendor lock-in
   - *Why rejected:* Open-source tools sufficient for requirements

3. **Manual Security Reviews Only**
   - *Pros:* Most thorough, human judgment
   - *Cons:* Slow, not scalable, inconsistent
   - *Why rejected:* Need automation for every PR

**Rationale:**

- **Defense in depth:** Multiple tools catch different issues
- **Complementary coverage:**
  - **Checkov:** Infrastructure security misconfigurations
  - **TFSec:** Terraform-specific security issues
  - **Terrascan:** Policy compliance (CIS, NIST)
  - **Gitleaks:** Secrets in Git history
  - **TruffleHog:** High-entropy credential patterns

- **All open-source:** No licensing costs
- **GitHub integration:** Upload results to Security tab
- **SARIF format:** Standardized reporting
- **Medical device compliance:** Comprehensive scanning demonstrates due diligence
- **CI/CD friendly:** Fast execution, clear outputs

**Consequences:**

- ✅ Comprehensive security coverage
- ✅ Multiple layers of detection
- ✅ Free and open-source
- ✅ Good for compliance demonstration
- ❌ Longer pipeline execution time (~5 minutes)
- ❌ May produce duplicate findings
- ⚠️ Need to triage findings from multiple sources
- ⚠️ Potential for false positives

---

## ADR-007: Deployment Approval Strategy

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Medical device regulations require change control and approval processes for production deployments.

**Decision:**

Implement **multi-stage approval process** with environment-based gates:
- Development: No approval (auto-deploy)
- Staging: 1 approver required
- Production: 2+ approvers required + business hours restriction

**Alternatives Considered:**

1. **No Approval (Fully Automated)**
   - *Pros:* Fastest deployment, minimal friction
   - *Cons:* No human oversight, risky for production
   - *Why rejected:* Doesn't meet medical device change control requirements

2. **Single Approver for All**
   - *Pros:* Simple process, faster than multiple
   - *Cons:* Single person can make mistakes, no redundancy
   - *Why rejected:* Medical device requires multiple reviewers

3. **Approval at PR Stage Only**
   - *Pros:* Single approval point, simpler
   - *Cons:* Time gap between PR approval and deployment
   - *Why rejected:* Need approval at deployment time (last verification)

4. **Manual Deployment (No Automation)**
   - *Pros:* Maximum control, manual verification
   - *Cons:* Slow, error-prone, inconsistent, no audit trail
   - *Why rejected:* Doesn't leverage automation benefits

**Rationale:**

- **Regulatory compliance:** Medical devices require change control
- **Four-eyes principle:** Multiple reviewers catch mistakes
- **Business hours enforcement:** Deployments only during support hours (9-5 UK)
- **Environment progression:** Increasing safety gates as risk increases
- **Fast development:** No approvals for dev encourages testing
- **GitHub Environments:** Built-in feature, no custom tooling
- **Audit trail:** GitHub tracks all approvals with timestamps
- **Flexibility:** Can override business hours with justification

**Consequences:**

- ✅ Meets medical device change control requirements
- ✅ Multiple reviewers prevent mistakes
- ✅ Business hours ensure support availability
- ✅ Complete audit trail in GitHub
- ✅ Fast development cycle (no dev approvals)
- ❌ Slower production deployments (waiting for approvers)
- ❌ Requires multiple people available
- ⚠️ Business hours restriction may delay urgent fixes

---

## ADR-008: State Backup and Retention Strategy

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Need to ensure Terraform state can be recovered and meets medical device audit requirements.

**Decision:**

Implement **automatic state backup before every deployment** with 7-year retention.

**Alternatives Considered:**

1. **No Backups (Rely on State File Versioning)**
   - *Pros:* Simpler, no additional storage
   - *Cons:* Versioning may not capture all scenarios, no explicit metadata
   - *Why rejected:* Need guaranteed backups with metadata

2. **Manual Backups**
   - *Pros:* Full control over when backups occur
   - *Cons:* Easy to forget, inconsistent, no audit trail
   - *Why rejected:* Human error risk too high

3. **Daily/Weekly Scheduled Backups**
   - *Pros:* Regular backups, predictable
   - *Cons:* May miss state between backups, doesn't capture pre-deployment state
   - *Why rejected:* Need backup before each change, not time-based

4. **Shorter Retention (90 days)**
   - *Pros:* Lower storage costs
   - *Cons:* Doesn't meet medical device audit requirements
   - *Why rejected:* Medical devices require 7-year audit trail

**Rationale:**

- **Medical device compliance:** 7-year audit trail requirement
- **Rollback capability:** Can restore any previous state
- **Metadata included:** Timestamp, actor, commit, reason
- **Automatic:** No human intervention required
- **Low cost:** State files are small (~1MB), storage is cheap
- **Immutable:** Once backed up, cannot be changed
- **Quick recovery:** Can restore in minutes if needed

**Consequences:**

- ✅ Can rollback any deployment
- ✅ Meets 7-year audit requirements
- ✅ Fully automated (no human error)
- ✅ Includes deployment metadata
- ✅ Low storage cost (~£5/year)
- ⚠️ Need retention policy management
- ⚠️ Backups accumulate over time (not a problem with current size)

---

## ADR-009: Monitoring and Observability Platform

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Need comprehensive monitoring for medical device application with long-term log retention.

**Decision:**

Use **Azure Monitor suite**: Log Analytics Workspace + Application Insights with 7-year retention for production.

**Alternatives Considered:**

1. **Third-Party SIEM (e.g., Splunk, Datadog)**
   - *Pros:* Advanced features, better visualizations, multi-cloud
   - *Cons:* Expensive (£10,000+/year), data egress costs, vendor lock-in
   - *Why rejected:* Cost prohibitive, Azure native solution sufficient

2. **Self-Hosted (e.g., ELK Stack)**
   - *Pros:* Full control, no vendor lock-in, customizable
   - *Cons:* High operational overhead, need to manage infrastructure, no native Azure integration
   - *Why rejected:* Operational burden too high for medical device

3. **Application Insights Only (No Log Analytics)**
   - *Pros:* Simpler, lower cost, APM-focused
   - *Cons:* Limited query capabilities, no infrastructure logs
   - *Why rejected:* Need comprehensive infrastructure logging

4. **Log Analytics Only (No Application Insights)**
   - *Pros:* Unified logging platform
   - *Cons:* Missing APM features, less application visibility
   - *Why rejected:* Need application performance monitoring

**Rationale:**

- **Native integration:** Deep Azure service integration
- **Long-term retention:** Supports 7-year retention (medical device requirement)
- **Powerful querying:** KQL for complex log analysis
- **Application Insights:** APM with distributed tracing
- **Cost-effective:** Pay for what you ingest and retain
- **Compliance features:** Immutable logs, audit trail
- **Alerting:** Built-in alert rules and action groups
- **No infrastructure:** Fully managed service
- **Security:** Role-based access control, no data egress

**Consequences:**

- ✅ Native Azure integration
- ✅ 7-year retention supported
- ✅ Comprehensive monitoring (infrastructure + application)
- ✅ Cost-effective for requirements
- ✅ No infrastructure to manage
- ❌ Vendor lock-in to Azure
- ❌ KQL learning curve
- ⚠️ Storage costs increase with 7-year retention (~£60/month)

---

## ADR-010: Network Security Approach

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Medical device requires comprehensive network security with data protection.

**Decision:**

Implement **private endpoints for all PaaS services** with no public access.

**Alternatives Considered:**

1. **Public Endpoints with Firewall Rules**
   - *Pros:* Simpler, cheaper, easier to configure
   - *Cons:* Traffic goes over public internet, higher attack surface
   - *Why rejected:* Medical device security requires private networking

2. **Service Endpoints Only**
   - *Pros:* Traffic stays on Azure backbone, simpler than private endpoints
   - *Cons:* Still uses public IP space, less secure than private endpoints
   - *Why rejected:* Want fully private IP addresses

3. **VPN/ExpressRoute Required**
   - *Pros:* Maximum security, dedicated connection
   - *Cons:* Expensive (£1,000+/month), complex, requires on-premises infrastructure
   - *Why rejected:* Application is cloud-native, no on-premises requirement

**Rationale:**

- **Medical device security:** Private networking required
- **Data protection:** No data traverses public internet
- **Private IP addresses:** All PaaS services get private IPs in VNet
- **DNS integration:** Private DNS zones for name resolution
- **Compliance:** Demonstrates network isolation for audits
- **Defense in depth:** Multiple layers of network security
- **Azure native:** Well-supported Azure feature

**Consequences:**

- ✅ Maximum network security
- ✅ All traffic private within Azure
- ✅ Private IP addresses for all services
- ✅ DNS integrated with VNet
- ❌ Higher complexity (private endpoints + DNS zones)
- ❌ Higher cost (~£10/endpoint/month)
- ⚠️ Requires VNet integration for all services
- ⚠️ More complex troubleshooting

---

## ADR-011: Identity and Access Management

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Need secure authentication for services and eliminate credential management.

**Decision:**

Use **Managed Identities exclusively** with RBAC for all inter-service authentication. Use **OIDC Workload Identity Federation** for GitHub Actions.

**Alternatives Considered:**

1. **Service Principals with Client Secrets**
   - *Pros:* Traditional approach, widely understood
   - *Cons:* Secrets to manage, rotation required, can be compromised
   - *Why rejected:* Managed identities eliminate secrets

2. **Service Principals with Certificates**
   - *Pros:* More secure than secrets, longer validity
   - *Cons:* Still credentials to manage, need secure storage
   - *Why rejected:* Managed identities are better

3. **Shared Access Signatures (SAS)**
   - *Pros:* Fine-grained permissions, temporary
   - *Cons:* Still secrets, need generation and distribution
   - *Why rejected:* Managed identities preferred

4. **API Keys/Access Keys**
   - *Pros:* Simple, built-in
   - *Cons:* Long-lived secrets, broad permissions, hard to rotate
   - *Why rejected:* Security anti-pattern

**Rationale:**

- **No secrets:** Managed identities eliminate credential storage
- **Automatic rotation:** Azure handles token rotation
- **RBAC integration:** Fine-grained permission control
- **Audit trail:** All access logged via Azure AD
- **OIDC for GitHub:** No secrets stored in GitHub
- **Medical device security:** Eliminates credential compromise risk
- **Compliance:** Demonstrates strong authentication for audits
- **Azure native:** Fully supported across Azure services

**Consequences:**

- ✅ Zero secrets stored anywhere
- ✅ Automatic credential rotation
- ✅ Strong RBAC permissions
- ✅ Complete audit trail
- ✅ Excellent security posture
- ❌ Requires Azure AD integration
- ⚠️ Limited to Azure services (can't use for external APIs)
- ⚠️ OIDC requires GitHub Enterprise or GitHub Team

---

## ADR-012: UK Data Residency Strategy

**Status:** Accepted

**Date:** 2024-11-06

**Context:**

Medical device application must comply with UK data residency requirements for patient data.

**Decision:**

Deploy **all resources exclusively in UK regions** (UK South and UK West) with automated compliance validation in CI/CD pipeline.

**Alternatives Considered:**

1. **Europe-Wide Deployment**
   - *Pros:* More region options, better redundancy
   - *Cons:* Doesn't guarantee UK residency, may violate regulations
   - *Why rejected:* UK data residency is legal requirement

2. **Manual Compliance Checks**
   - *Pros:* Simple, no automation needed
   - *Cons:* Error-prone, inconsistent, no prevention
   - *Why rejected:* Need automated enforcement

3. **Azure Policy Only**
   - *Pros:* Prevents deployment to wrong regions
   - *Cons:* Only at Azure level, doesn't catch Terraform errors early
   - *Why rejected:* Want to catch issues in PR phase

**Rationale:**

- **Legal requirement:** UK medical device regulations require UK data residency
- **Patient data protection:** Ensures patient data stays in UK
- **Automated validation:** Pipeline checks on every PR
- **Fail fast:** Catches violations before deployment
- **Audit evidence:** Demonstrates compliance to regulators
- **Both regions in UK:** UK South and UK West both meet requirements

**Consequences:**

- ✅ Guaranteed UK data residency
- ✅ Automated compliance checking
- ✅ Regulatory compliance demonstrated
- ✅ Audit trail of enforcement
- ❌ Limited to 2 UK regions only
- ❌ Can't use other Azure regions (even for DR)
- ⚠️ Regional failures impact both regions (rare)

---

## Summary of Key Decisions

| Decision | Choice | Key Reason |
|----------|--------|------------|
| Regions | 2 (UK South + UK West) | HA + DR + UK residency |
| Availability Zones | 3 per region | 99.99% SLA |
| Compute | App Service Premium v3 | Mature, predictable, zone-redundant |
| Regional LB | Application Gateway WAF v2 | Security (WAF) + zone redundancy |
| Global LB | Traffic Manager | DNS-based, low cost, health-aware |
| IaC Tool | Terraform | Industry standard, multi-cloud |
| Security Scanning | 5 tools (Checkov, TFSec, etc.) | Defense in depth |
| Approvals | Multi-stage (0/1/2 approvers) | Compliance + speed |
| State Backup | Automatic, 7-year retention | Recovery + audit trail |
| Monitoring | Azure Monitor + App Insights | Native, 7-year retention |
| Networking | Private endpoints | Maximum security |
| Identity | Managed Identities + OIDC | Zero secrets |
| Data Residency | UK only + automated checks | Regulatory compliance |

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2024-11-06 | 1.0 | Initial ADRs created | Team |

---