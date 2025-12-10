# GitHub Workflows

This directory contains CI/CD workflows for the Kubernetes GitOps repository.

## Workflows

### 🏷️ [`labeler.yaml`](./labeler.yaml)
**Trigger:** On PR opened
**Purpose:** Automatically labels PRs based on changed files

- Labels infrastructure categories (networking, storage, security, etc.)
- Labels application categories (media, data, auth, etc.)
- Adds size labels (XS, S, M, L, XL, XXL) based on lines changed
- Labels renovate PRs by type (container, helm, github-action)
- Detects security-related changes

**Configuration:** [`.github/labeler.yaml`](../labeler.yaml)

### 🔄 [`labels-sync.yaml`](./labels-sync.yaml)
**Trigger:** Daily at midnight, on push to labels.yaml, manual
**Purpose:** Syncs repository labels with configuration

- Creates/updates labels from configuration
- Deletes labels not in configuration (controlled)
- Ensures consistent labeling across repository

**Configuration:** [`.github/labels.yaml`](../labels.yaml)

### ✅ [`validate-manifests.yaml`](./validate-manifests.yaml)
**Trigger:** On PR with YAML changes, push to main
**Purpose:** Validates all Kubernetes and ArgoCD manifests

**Jobs:**
- **validate-yaml**: Lints YAML syntax with yamllint
- **validate-kubernetes**: Validates Kubernetes manifests with kubeconform
- **validate-argocd**: Validates ArgoCD application specs
- **comment-results**: Posts validation summary to PR

**Benefits:**
- Catches syntax errors before merge
- Ensures Kubernetes API compliance
- Validates ArgoCD applications
- Fast feedback in PRs

### 🔒 [`security-scan.yaml`](./security-scan.yaml)
**Trigger:** On PR, push to main, weekly schedule, manual
**Purpose:** Scans for security vulnerabilities and misconfigurations

**Jobs:**
- **trivy-scan**: Scans for vulnerabilities in dependencies and images
- **kubescape-scan**: Checks Kubernetes manifests against NSA/MITRE frameworks
- **secret-scan**: Detects accidentally committed secrets with Gitleaks

**Results:**
- Uploads findings to GitHub Security tab (SARIF format)
- Enables comments on PRs for Gitleaks findings
- Weekly scheduled scans for ongoing monitoring

**Best Practices:**
- Runs on every PR (shift-left security)
- Scheduled weekly scans catch new vulnerabilities
- SARIF integration with GitHub Security

### 🔗 [`link-check.yaml`](./link-check.yaml)
**Trigger:** On PR with MD changes, push to main, weekly schedule, manual
**Purpose:** Checks all links in Markdown documentation

**Features:**
- Validates external links
- Excludes localhost and internal domains
- Retries failed links (network issues)
- Creates GitHub issue on scheduled failure
- Comments on PRs with broken links

**Configuration:**
- Excludes: localhost, `127.0.0.1`, `*.atoca.house`
- Max retries: 3
- Timeout: 20 seconds

### ☁️ [`tofu-plan.yaml`](./tofu-plan.yaml)
**Trigger:** On PR with Terraform changes
**Purpose:** Plans OpenTofu/Terraform changes

**Jobs:**
1. **Format check** (`tofu fmt`)
2. **Init** (`tofu init`)
3. **Validate** (`tofu validate`)
4. **Plan** (`tofu plan`)
5. **Comment PR** with plan output

**Environment Variables:** (from secrets)
- `TF_VAR_cloudflare_api_token`
- `TF_VAR_zone_id`
- `TF_VAR_account_id`
- `TF_VAR_domain`
- `TF_VAR_npm_ip`

**Working Directory:** `infra/terraform`

### ☁️ [`tofu-apply.yaml`](./tofu-apply.yaml)
**Trigger:** On push to main with Terraform changes, manual
**Purpose:** Applies OpenTofu/Terraform changes to infrastructure

**Jobs:**
1. **Init** (`tofu init`)
2. **Apply** (`tofu apply -auto-approve`)

**⚠️ Warning:**
- Auto-approves changes on push to main
- Ensure changes are reviewed via `tofu-plan.yaml` in PR first
- Manual trigger available for emergency changes

**Working Directory:** `infra/terraform`

## Workflow Best Practices

### Security
- ✅ All actions pinned to SHA digests (Renovate updates these)
- ✅ Minimal permissions (principle of least privilege)
- ✅ Secrets stored in GitHub Secrets
- ✅ SARIF uploads to GitHub Security tab
- ✅ Secret scanning on every PR and push

### Performance
- ✅ Using self-hosted runners (`arc-runners`) for faster builds
- ✅ Conditional execution (only on relevant file changes)
- ✅ Parallel job execution where possible
- ✅ Sparse checkout for label-sync (only fetches labels.yaml)

### Developer Experience
- ✅ PR comments with validation results
- ✅ Clear failure messages
- ✅ Links to logs and documentation
- ✅ Size labels help estimate review effort
- ✅ Automatic labeling reduces manual work

### Reliability
- ✅ `continue-on-error` for non-blocking checks
- ✅ Retry logic for external API calls
- ✅ Scheduled workflows for ongoing monitoring
- ✅ Issue creation for scheduled failures

## Adding a New Workflow

1. **Create workflow file:**
   ```bash
   touch .github/workflows/my-workflow.yaml
   ```

2. **Basic structure:**
   ```yaml
   name: My Workflow

   on:
     pull_request:
       paths:
         - "relevant/path/**"
     push:
       branches: ["main"]

   permissions:
     contents: read

   jobs:
     my-job:
       name: My Job
       runs-on: arc-runners
       steps:
         - name: Checkout
           uses: actions/checkout@<sha>  # Pin to SHA

         - name: Do something
           run: echo "Hello World"
   ```

3. **Best practices:**
   - Pin all actions to SHA digests
   - Use minimal permissions
   - Use `arc-runners` for self-hosted execution
   - Add PR comments for feedback
   - Use `continue-on-error` for non-critical steps
   - Add to this README!

## Self-Hosted Runners

All workflows use `runs-on: arc-runners` which are self-hosted GitHub Actions runners managed by [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller).

**Benefits:**
- Faster builds (no queue time)
- Faster network access (same network as cluster)
- No GitHub-hosted runner costs
- Can access cluster directly
- Kubernetes-native scaling

**Configuration:**
- Deployed in `arc-runners` namespace
- Managed by ArgoCD
- Auto-scales based on job queue

## Troubleshooting

### Workflow fails with "No runner available"
**Cause:** ARC runners not scaled up or unavailable
**Fix:**
```bash
# Check runner pods
kubectl get pods -n arc-runners

# Check runner status
kubectl describe runners -n arc-runners

# Scale manually if needed
kubectl scale deployment arc-runner-set -n arc-runners --replicas=3
```

### Action fails with "digest not found"
**Cause:** SHA digest in workflow is outdated
**Fix:**
- Renovate should auto-update these
- Manually update: `uses: actions/checkout@v6` (Renovate will pin)

### Tofu plan/apply fails with "authentication failed"
**Cause:** Missing or expired secrets
**Fix:**
```bash
# Update secrets
gh secret set TF_VAR_cloudflare_api_token

# Or via GitHub UI: Settings → Secrets → Actions
```

### Security scan uploads fail
**Cause:** Missing permissions or invalid SARIF
**Fix:**
- Ensure `security-events: write` permission
- Check SARIF file format
- Verify GitHub Advanced Security is enabled

### Link checker creates duplicate issues
**Cause:** Issue already exists from previous run
**Fix:** Script checks for existing issues before creating new ones

## Monitoring

### Workflow Runs
View all workflow runs:
```bash
# Via CLI
gh run list

# Via web
https://github.com/guilhermewolf/atoca.house/actions
```

### Failed Workflows
Get notified of failures:
1. **GitHub UI:** Settings → Notifications → Actions
2. **Email:** Automatic on failure (if enabled)
3. **Slack:** Configure GitHub app with notifications

### Metrics
Track workflow performance:
- **Duration:** How long workflows take
- **Success rate:** Percentage of successful runs
- **Queue time:** Time waiting for runner

View in:
- **GitHub Insights:** Repository → Insights → Actions
- **ARC metrics:** Prometheus/Grafana (if configured)

## Maintenance

### Weekly Tasks
- ✅ Review security scan results
- ✅ Check for workflow failures
- ✅ Review and close automated issues

### Monthly Tasks
- ✅ Review workflow performance
- ✅ Update workflow configurations if needed
- ✅ Review runner capacity and adjust if needed

### As Needed
- ✅ Add workflows for new validation needs
- ✅ Update when new tools become available
- ✅ Optimize workflows based on usage patterns

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Actions Runner Controller](https://github.com/actions/actions-runner-controller)
- [Renovate Bot](https://docs.renovatebot.com/)
- [Trivy Security Scanner](https://aquasecurity.github.io/trivy/)
- [Kubescape](https://github.com/kubescape/kubescape)
- [Lychee Link Checker](https://github.com/lycheeverse/lychee)
