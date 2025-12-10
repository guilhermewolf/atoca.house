# .github Directory

This directory contains GitHub-specific configuration for automation, CI/CD, and repository management.

## 📁 Directory Structure

```
.github/
├── workflows/           # GitHub Actions workflows
│   ├── labeler.yaml
│   ├── labels-sync.yaml
│   ├── validate-manifests.yaml
│   ├── security-scan.yaml
│   ├── link-check.yaml
│   ├── tofu-plan.yaml
│   ├── tofu-apply.yaml
│   └── README.md
├── renovate/            # Renovate configuration files
│   └── grafanaDashboards.json
├── CODEOWNERS           # Code ownership rules
├── labels.yaml          # Label definitions
├── labeler.yaml         # Auto-labeler rules
└── README.md            # This file
```

## 🤖 Automation Overview

### Renovate Bot
**Purpose:** Automated dependency updates

**Configuration:**
- **Main:** `/renovate.json`
- **Extensions:** `.github/renovate/grafanaDashboards.json`

**What it updates:**
- Docker images in Kubernetes manifests
- Helm chart versions in ArgoCD applications
- GitHub Actions (pinned to SHA digests)
- Grafana dashboards
- Docker Compose stacks
- Terraform/OpenTofu providers

**Features:**
- Auto-merge minor/patch updates for trusted sources
- Groups related updates (e.g., monitoring stack)
- Schedules updates during business hours
- Requires manual approval for major updates
- Security vulnerability alerts

**Dashboard:** Check `/renovate-dashboard` issue for status

### GitHub Actions
**Purpose:** CI/CD automation and validation

**Workflows:**
1. **Labeler** - Auto-labels PRs based on files changed
2. **Labels Sync** - Syncs repository labels daily
3. **Validate Manifests** - Validates YAML/K8s/ArgoCD manifests
4. **Security Scan** - Scans for vulnerabilities (Trivy, Kubescape, Gitleaks)
5. **Link Checker** - Validates documentation links
6. **Tofu Plan** - Plans Terraform changes on PRs
7. **Tofu Apply** - Applies Terraform changes on merge

**Runner:** Self-hosted `arc-runners` (Actions Runner Controller in cluster)

See [`workflows/README.md`](./workflows/README.md) for details.

## 🏷️ Labels System

### Label Categories

#### Area Labels (What part of repo)
- `area/networking` - Cilium, Envoy, DNS
- `area/storage` - Rook-Ceph, CSI drivers
- `area/security` - Cert-manager, sealed-secrets
- `area/monitoring` - Prometheus, Grafana
- `area/cluster-management` - Metrics-server, reloader
- `area/operators` - Kubernetes operators
- `area/media` - Media applications
- `area/data` - Databases
- `area/auth` - Authentication
- `area/argocd` - ArgoCD configuration
- `area/ansible` - Ansible playbooks
- `area/talos` - Talos Linux
- `area/terraform` - Terraform/OpenTofu
- `area/docker` - Docker Compose
- `area/docs` - Documentation
- `area/github` - GitHub Actions

#### Type Labels (What kind of change)
- `type/feature` - New functionality
- `type/enhancement` - Improvement to existing
- `type/bug` - Bug fix
- `type/refactor` - Code refactoring
- `type/docs` - Documentation only
- `type/chore` - Maintenance, dependencies
- `type/ci` - CI/CD changes

#### Priority Labels (How urgent)
- `priority/critical` - Immediate attention
- `priority/high` - Soon
- `priority/medium` - Normal queue
- `priority/low` - Nice to have

#### Size Labels (How big - auto-added)
- `size/XS` - 0-9 lines
- `size/S` - 10-29 lines
- `size/M` - 30-99 lines
- `size/L` - 100-499 lines
- `size/XL` - 500-999 lines
- `size/XXL` - 1000+ lines

#### Status Labels (Current state)
- `status/blocked` - Blocked by dependencies
- `status/wip` - Work in progress
- `status/ready-for-review` - Ready
- `status/needs-changes` - Changes requested
- `status/approved` - Ready to merge
- `status/on-hold` - Waiting

#### Special Labels
- `security` - Security vulnerability/fix
- `breaking-change` - Breaking changes
- `major-update` - Major version bump
- `renovate` - Renovate bot PR
- `dependencies` - Dependency updates
- `critical` - Critical infrastructure

### Label Management

**Configuration:** `labels.yaml`
**Sync:** Automated daily via `labels-sync.yaml` workflow
**Manual sync:** `gh workflow run labels-sync.yaml`

**Adding new labels:**
1. Edit `.github/labels.yaml`
2. Commit and push
3. Workflow syncs automatically
4. Or run manually: `gh workflow run labels-sync.yaml`

### Auto-Labeler Rules

**Configuration:** `labeler.yaml`
**Trigger:** On PR opened

**Examples:**
- Files in `infra/k8s/networking/` → `area/networking`
- Files in `apps/media/` → `area/media`
- 150 lines changed → `size/L`
- Title contains `!` → `breaking-change`
- Branch starts with `renovate/` → `renovate`

**Testing:**
1. Create PR
2. Labeler runs automatically
3. Check labels added to PR

## 👥 Code Ownership

**File:** `CODEOWNERS`
**Purpose:** Defines who owns what code

**Format:**
```
# Pattern         Owners
/infra/talos/     @guilhermewolf
/apps/media/      @guilhermewolf
*.md              @guilhermewolf
```

**Effects:**
- Auto-requests reviews from owners
- Shows ownership in GitHub UI
- Used by Renovate for assignees/reviewers

**Updating:**
Edit `CODEOWNERS` and commit. Takes effect immediately.

## 🔧 Renovate Configuration

### Main Configuration
**File:** `/renovate.json`

**Key features:**
- Extends `config:best-practices`
- Semantic commits (`chore(deps): update ...`)
- PR limits (5 concurrent, 3 per hour)
- Scheduled updates (weekdays 9am-5pm)
- Security vulnerability alerts
- Auto-merge for trusted updates

### Custom Datasources
**File:** `.github/renovate/grafanaDashboards.json`

Updates Grafana dashboard revisions from grafana.com API.

### Package Rules

**Grouped updates:**
- `kubernetes-infrastructure` - Core K8s components
- `rook-ceph` - Storage (requires approval)
- `monitoring-stack` - Prometheus, Grafana
- `media-apps` - Media applications

**Auto-merge:**
- GitHub Actions (trusted sources) - minor/patch
- OCI Charts - minor/patch
- Grafana dashboards - all

**Manual approval:**
- Major version updates
- Rook-Ceph (critical storage)
- Talos (pinned - disabled)

### File Matchers

Renovate scans:
- `infra/k8s/**/*application.yaml` - ArgoCD apps
- `infra/k8s/**/*values.yaml` - Helm values
- `apps/**/*.yaml` - Application configs
- `stacks/**/*.yaml` - Docker Compose
- `.github/workflows/*.yaml` - GitHub Actions
- `Taskfile*.yaml` - Taskfile tool versions

### Regex Managers

Custom annotations for special cases:
```yaml
# renovate: datasource=github-releases depName=talos/talos
talos_version: v1.9.0
```

Renovate will update `v1.9.0` automatically.

## 🚀 Quick Start Guide

### For Contributors

1. **Fork and clone** repository
2. **Create branch:** `git checkout -b feature/my-feature`
3. **Make changes**
4. **Commit:** Use conventional commits
   ```bash
   git commit -m "feat(networking): add new ingress route"
   ```
5. **Push:** `git push origin feature/my-feature`
6. **Create PR** on GitHub
7. **Wait for checks:**
   - Labeler adds labels
   - Manifests validated
   - Security scan runs
   - Links checked
8. **Address feedback** if needed
9. **Merge** when approved and checks pass

### For Maintainers

**Review PR:**
1. Check auto-added labels (area, size, type)
2. Review changes
3. Check workflow results
4. Request changes or approve

**Merge PR:**
1. Ensure all checks pass
2. Use "Squash and merge" for cleaner history
3. Delete branch after merge

**Renovate PRs:**
1. Review dependency dashboard
2. Approve or close PRs
3. Auto-merge trusted updates (already configured)

### For Renovate Management

**View dashboard:**
- Check for issue titled "Dependency Dashboard"
- Shows all pending updates
- Checkboxes to trigger immediate updates

**Manual trigger:**
- Add comment `@renovatebot rebase` to rebase PR
- Close PR to skip update
- Rename PR to change priority

**Configuration changes:**
1. Edit `renovate.json`
2. Commit and push
3. Renovate validates and applies immediately

## 📊 Monitoring

### Workflow Status
```bash
# View all workflow runs
gh run list

# View specific workflow
gh run list --workflow=security-scan.yaml

# View logs
gh run view <run-id> --log
```

### Renovate Status
- Check "Dependency Dashboard" issue
- Review recent Renovate PRs
- Check workflow runs for Renovate PRs

### Security Alerts
- **GitHub Security tab:** Security → Code scanning alerts
- **Dependabot alerts:** Security → Dependabot alerts
- **Workflow runs:** Actions → security-scan.yaml

## 🔍 Troubleshooting

### Labels not syncing
**Check:**
1. Workflow runs: `gh run list --workflow=labels-sync.yaml`
2. Workflow logs: `gh run view <run-id> --log`
3. Label file syntax: `yamllint .github/labels.yaml`

**Fix:**
- Manual trigger: `gh workflow run labels-sync.yaml`
- Check permissions (needs `issues: write`)

### Labeler not working
**Check:**
1. PR was just opened (only runs on `opened` event)
2. Workflow runs: `gh run list --workflow=labeler.yaml`
3. Labeler config: `.github/labeler.yaml`

**Fix:**
- Close and reopen PR to trigger
- Manual trigger: `gh workflow run labeler.yaml`
- Check file patterns in `labeler.yaml`

### Renovate not creating PRs
**Check:**
1. Dependency dashboard issue exists
2. Renovate config validation
3. Recent Renovate activity

**Fix:**
- Validate config: `npx renovate-config-validator renovate.json`
- Check rate limits
- Trigger manually via dashboard checkboxes

### Security scans failing
**Check:**
1. Workflow logs for specific error
2. SARIF upload permissions
3. Scanner tool availability

**Fix:**
- For Trivy: Check image/filesystem access
- For Kubescape: Check manifest paths
- For Gitleaks: Check git history depth

## 📚 Best Practices

### Writing Workflows
- ✅ Pin actions to SHA digests
- ✅ Use minimal permissions
- ✅ Use self-hosted runners
- ✅ Add PR comments for feedback
- ✅ Use `continue-on-error` carefully
- ✅ Cache dependencies when possible
- ✅ Document in README

### Managing Labels
- ✅ Keep labels organized by category
- ✅ Use consistent color scheme
- ✅ Add descriptions to all labels
- ✅ Clean up unused labels regularly
- ✅ Update labeler rules for new labels

### Renovate Configuration
- ✅ Group related updates
- ✅ Schedule non-critical updates
- ✅ Auto-merge trusted sources
- ✅ Require approval for breaking changes
- ✅ Pin critical dependencies (Talos)
- ✅ Test regex managers before committing

### Security
- ✅ Run scans on every PR
- ✅ Review security alerts weekly
- ✅ Keep scanner tools updated
- ✅ Don't disable security checks
- ✅ Investigate all critical findings

## 🔗 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Renovate Documentation](https://docs.renovatebot.com/)
- [GitHub Labels Guide](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels)
- [CODEOWNERS Documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [Actions Runner Controller](https://github.com/actions/actions-runner-controller)

## 📝 Changelog

Track major changes to .github configuration:

- **2025-12-10**: Enhanced labels system with new categories
- **2025-12-10**: Added manifest validation workflow
- **2025-12-10**: Added security scanning workflow
- **2025-12-10**: Added link checker workflow
- **2025-12-10**: Updated Renovate for new repo structure
- **2025-12-10**: Comprehensive documentation added
