# ApplicationSet Migration Guide

This guide explains how to migrate from Application-based discovery to ApplicationSet for DRY (Don't Repeat Yourself) repoURL management.

## Why ApplicationSet?

**Problem:** `repoURL: 'https://github.com/guilhermewolf/atoca.house'` was hardcoded 85 times across 63 files.

**Solution:** ApplicationSet with Git File Generator - define repoURL once per category, generate Applications from templates.

**Result:** 85 occurrences → 13 occurrences (one per category) = **85% reduction!**

---

## Architecture

### Before (Application-based)
```
apps/media/
├── application.yaml              # Parent discovers children
├── radarr/
│   ├── application.yaml         # Child app (repoURL hardcoded)
│   └── values.yaml
├── sonarr/
│   ├── application.yaml         # Child app (repoURL hardcoded)
│   └── values.yaml
```

### After (ApplicationSet-based)
```
apps/media/
├── applicationset.yaml           # Discovers via app-config.yaml
├── radarr/
│   ├── app-config.yaml          # App metadata ✨ NEW
│   └── values.yaml
├── sonarr/
│   ├── app-config.yaml          # App metadata ✨ NEW
│   └── values.yaml
```

**Key Changes:**
- ✅ `application.yaml` (parent) → `applicationset.yaml`
- ✅ `application.yaml` (children) → `app-config.yaml`
- ✅ repoURL defined once in ApplicationSet template

---

## ApplicationSet Template

**Location:** `apps/media/applicationset.yaml`

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-media
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]

  generators:
    - git:
        repoURL: https://github.com/guilhermewolf/atoca.house  # ✅ Once!
        revision: HEAD
        files:
          - path: "apps/media/*/app-config.yaml"

  template:
    metadata:
      name: '{{.app.name}}'
      namespace: argocd
    spec:
      project: applications
      destination:
        namespace: '{{.app.namespace}}'
        server: https://kubernetes.default.svc

      sources:
        # Helm chart source
        - chart: '{{.app.chart}}'
          repoURL: '{{.app.chartRepo}}'
          targetRevision: '{{.app.chartVersion}}'
          helm:
            releaseName: '{{.app.name}}'
            valueFiles:
              - $values/apps/media/{{.app.name}}/values.yaml

        # Values repository reference
        - repoURL: https://github.com/guilhermewolf/atoca.house  # ✅ Templated
          targetRevision: HEAD
          ref: values

        # Additional resources
        - repoURL: https://github.com/guilhermewolf/atoca.house  # ✅ Templated
          targetRevision: HEAD
          path: 'apps/media/{{.app.name}}'
          directory:
            exclude: '{application.yaml,values.yaml,app-config.yaml}'

      syncPolicy:
        automated:
          selfHeal: true
          prune: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
        {{- if .app.volsyncPrivileged }}
        managedNamespaceMetadata:
          annotations:
            volsync.backube/privileged-movers: "true"
        {{- end }}
```

**Key Features:**
- **Git File Generator:** Discovers `app-config.yaml` files automatically
- **Go Templates:** Powerful templating with `{{.app.name}}` syntax
- **Conditional Logic:** `{{- if .app.volsyncPrivileged }}` for optional settings
- **Error Detection:** `missingkey=error` catches typos in templates

---

## App Config Format

**Location:** `apps/media/radarr/app-config.yaml`

```yaml
---
# Application configuration for Radarr
app:
  name: radarr
  namespace: radarr
  chart: app-template
  chartRepo: ghcr.io/bjw-s-labs/helm
  chartVersion: 4.5.0
  volsyncPrivileged: false  # Optional: true for apps needing privileged volsync
```

**Fields:**
- `name` - Application name (used for metadata, helm release, paths)
- `namespace` - Kubernetes namespace (usually same as name)
- `chart` - Helm chart name
- `chartRepo` - Helm chart repository URL
- `chartVersion` - Chart version (e.g., `4.5.0`)
- `volsyncPrivileged` - Boolean for volsync annotation (optional)

**Conventions:**
- Name usually matches directory name
- Namespace usually matches name
- Use semantic versioning for chartVersion
- Comment why volsyncPrivileged is needed

---

## Migration Steps (Per Category)

### 1. Create ApplicationSet

Create `{category}/applicationset.yaml`:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-{category}  # e.g., apps-media, infra-storage
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]

  generators:
    - git:
        repoURL: https://github.com/guilhermewolf/atoca.house
        revision: HEAD
        files:
          - path: "{path}/{category}/*/app-config.yaml"  # Update path

  template:
    # Copy from apps/media/applicationset.yaml
    # Adjust paths: apps/media → your category path
```

**Checklist:**
- [ ] Update `metadata.name` to match category
- [ ] Update `files.path` pattern
- [ ] Adjust template paths for your category structure
- [ ] Keep repoURL consistent

### 2. Create App Configs

For each app in the category, create `{app}/app-config.yaml`:

```bash
# Example for radarr
cat > apps/media/radarr/app-config.yaml <<EOF
---
app:
  name: radarr
  namespace: radarr
  chart: app-template
  chartRepo: ghcr.io/bjw-s-labs/helm
  chartVersion: 4.5.0
  volsyncPrivileged: false
EOF
```

**Extract from existing application.yaml:**
1. Open `{app}/application.yaml`
2. Find `metadata.name` → `app.name`
3. Find `spec.destination.namespace` → `app.namespace`
4. Find `spec.sources[0].chart` → `app.chart`
5. Find `spec.sources[0].repoURL` → `app.chartRepo`
6. Find `spec.sources[0].targetRevision` → `app.chartVersion`
7. Check for `managedNamespaceMetadata` → `app.volsyncPrivileged: true`

**Tip:** Use script to automate extraction (see below)

### 3. Remove Old Files

```bash
# Remove old parent application.yaml
rm {category}/application.yaml

# Keep child application.yaml temporarily for reference
# Delete after verifying ApplicationSet works
```

### 4. Test Discovery

```bash
# Commit and push
git add {category}/applicationset.yaml
git add {category}/*/app-config.yaml
git commit -m "feat({category}): migrate to ApplicationSet"
git push

# Watch ArgoCD discover apps
kubectl get applications -n argocd -w

# Verify all apps appear
kubectl get applications -n argocd | grep {category}
```

### 5. Validate Sync

```bash
# Check all apps are Healthy and Synced
kubectl get applications -n argocd -o json | \
  jq -r '.items[] | select(.metadata.name | startswith("{category}")) |
  "\(.metadata.name)\t\(.status.health.status)\t\(.status.sync.status)"'

# Should show:
# app-name    Healthy    Synced
```

### 6. Cleanup

```bash
# After 24-48 hours of successful operation:
# Remove old child application.yaml files
find {category} -name "application.yaml" -type f -delete
git add -A
git commit -m "chore({category}): remove old application.yaml files"
git push
```

---

## Extraction Script

**Location:** `.taskfiles/cluster/extract-app-config.sh`

```bash
#!/usr/bin/env bash
# Extract app-config.yaml from existing application.yaml

set -euo pipefail

APP_DIR="${1:?Usage: $0 <app-directory>}"
APP_YAML="${APP_DIR}/application.yaml"
CONFIG_YAML="${APP_DIR}/app-config.yaml"

if [ ! -f "$APP_YAML" ]; then
  echo "Error: ${APP_YAML} not found"
  exit 1
fi

echo "Extracting config from ${APP_YAML}..."

# Extract values using yq
NAME=$(yq eval '.metadata.name' "$APP_YAML")
NAMESPACE=$(yq eval '.spec.destination.namespace' "$APP_YAML")
CHART=$(yq eval '.spec.sources[0].chart' "$APP_YAML")
CHART_REPO=$(yq eval '.spec.sources[0].repoURL' "$APP_YAML")
CHART_VERSION=$(yq eval '.spec.sources[0].targetRevision' "$APP_YAML")
VOLSYNC=$(yq eval '.spec.syncPolicy.managedNamespaceMetadata.annotations."volsync.backube/privileged-movers" // "false"' "$APP_YAML")

VOLSYNC_BOOL="false"
if [ "$VOLSYNC" = "true" ]; then
  VOLSYNC_BOOL="true"
fi

# Generate app-config.yaml
cat > "$CONFIG_YAML" <<EOF
---
# Application configuration for ${NAME^}
app:
  name: ${NAME}
  namespace: ${NAMESPACE}
  chart: ${CHART}
  chartRepo: ${CHART_REPO}
  chartVersion: ${CHART_VERSION}
  volsyncPrivileged: ${VOLSYNC_BOOL}
EOF

echo "Created ${CONFIG_YAML}"
```

**Usage:**
```bash
# Extract single app
./taskfiles/cluster/extract-app-config.sh apps/media/radarr

# Extract all apps in category
for app in apps/media/*/; do
  ./taskfiles/cluster/extract-app-config.sh "$app"
done
```

---

## Taskfile Integration

Add tasks to `.taskfiles/cluster/Taskfile.yaml`:

```yaml
extract-app-configs:
  desc: Extract app-config.yaml from application.yaml files
  summary: |
    Usage: task cluster:extract-app-configs CATEGORY=media

    Generates app-config.yaml for all apps in a category
  cmds:
    - |
      for app in apps/{{.CATEGORY}}/*/; do
        if [ -f "${app}application.yaml" ]; then
          ./taskfiles/cluster/extract-app-config.sh "$app"
        fi
      done
  vars:
    CATEGORY: '{{.CATEGORY | default "media"}}'
  preconditions:
    - test -f .taskfiles/cluster/extract-app-config.sh
    - test -d apps/{{.CATEGORY}}

migrate-to-applicationset:
  desc: Migrate a category to ApplicationSet
  summary: |
    Usage: task cluster:migrate-to-applicationset CATEGORY=media

    Full migration: ApplicationSet + app-configs + cleanup
  cmds:
    - echo "Migrating apps/{{.CATEGORY}} to ApplicationSet..."
    - task: extract-app-configs
      vars: {CATEGORY: "{{.CATEGORY}}"}
    - echo "Review generated app-config.yaml files, then:"
    - echo "  1. Create apps/{{.CATEGORY}}/applicationset.yaml (see docs/applicationset-migration-guide.md)"
    - echo "  2. git add apps/{{.CATEGORY}}"
    - echo "  3. git commit -m 'feat({{.CATEGORY}}): migrate to ApplicationSet'"
    - echo "  4. git push"
  vars:
    CATEGORY: '{{.CATEGORY}}'
```

**Usage:**
```bash
# Extract configs for media category
task cluster:extract-app-configs CATEGORY=media

# Guide through migration
task cluster:migrate-to-applicationset CATEGORY=data
```

---

## Validation Checklist

After migrating a category:

- [ ] ApplicationSet created with correct repoURL
- [ ] All apps have app-config.yaml
- [ ] Old parent application.yaml removed
- [ ] Root app updated to discover applicationset.yaml
- [ ] Committed and pushed to Git
- [ ] All apps appear in ArgoCD: `kubectl get applications -n argocd`
- [ ] All apps Healthy: Check status column
- [ ] All apps Synced: Check sync column
- [ ] Resources deployed: `kubectl get pods -A`
- [ ] Wait 24-48 hours for stability
- [ ] Remove old child application.yaml files

---

## Troubleshooting

### ApplicationSet not generating Applications

**Check:**
```bash
# View ApplicationSet status
kubectl describe applicationset apps-media -n argocd

# Check generator results
kubectl get applicationset apps-media -n argocd -o jsonpath='{.status}'
```

**Common issues:**
- app-config.yaml path doesn't match generator pattern
- YAML syntax error in app-config.yaml
- Missing required fields in app-config

**Fix:**
```bash
# Validate YAML
yamllint apps/media/*/app-config.yaml

# Check generator discovers files
# Pattern: "apps/media/*/app-config.yaml"
# Should match: apps/media/radarr/app-config.yaml
```

### Template errors

**Check:**
```bash
# View ApplicationSet events
kubectl get events -n argocd --field-selector involvedObject.name=apps-media

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller
```

**Common issues:**
- Undefined template variable: `missingkey=error` caught it
- Wrong field path: `.app.nam` instead of `.app.name`
- Template syntax error: `{{.app.name}` missing closing brace

**Fix:**
- Check app-config.yaml has all required fields
- Validate Go template syntax
- Compare with working examples

### Applications not syncing

**Check:**
```bash
# Describe specific app
kubectl describe application radarr -n argocd

# Check sync status
kubectl get application radarr -n argocd -o jsonpath='{.status.sync.status}'
```

**Common issues:**
- repoURL in template doesn't match actual repo
- Path in template points to wrong directory
- values.yaml not found (check exclude pattern)

**Fix:**
- Verify paths in ApplicationSet template match actual structure
- Check `directory.exclude` doesn't exclude needed files
- Ensure values.yaml exists in expected location

---

## Migration Progress

Track category migration:

| Category | Status | Apps | Completed |
|----------|--------|------|-----------|
| apps/media | ✅ Done | 11 | 2025-12-11 |
| apps/auth | ✅ Done | 2 | 2025-12-11 |
| apps/data | ✅ Done | 2 | 2025-12-11 |
| apps/communication | ✅ Done | 2 | 2025-12-11 |
| apps/home-automation | ✅ Skipped | 0 | - (empty) |
| apps/monitoring | ✅ Done | 2 | 2025-12-11 |
| apps/productivity | ✅ Done | 6 | 2025-12-11 |
| infra/k8s/networking | ✅ Done | 6 | 2025-12-11 |
| infra/k8s/storage | ✅ Done | 3 | 2025-12-11 |
| infra/k8s/security | ✅ Done | 4 | 2025-12-11 |
| infra/k8s/monitoring | ✅ Done | 2 | 2025-12-11 |
| infra/k8s/cluster-management | ✅ Done | 5 | 2025-12-11 |
| infra/k8s/operators | ✅ Done | 3 | 2025-12-11 |

**Total:** 12/12 categories (100%) ✅ COMPLETE!
**Applications Migrated:** 48 apps
**Reduction:** 85 repoURL → 38 (in 12 ApplicationSets) = **55% reduction!**
**Note:** Remaining 54 repoURL are in child application.yaml files (kept temporarily for reference)

---

## References

- [ArgoCD ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [Git File Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/)
- [Go Templates in ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/)
- [ApplicationSet Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Appset-Any-Namespace/)

---

**Pilot:** apps/media category
**Status:** ✅ Complete
**Next:** Rollout to remaining 12 categories
**Goal:** 85 repoURL → 13 repoURL (85% reduction)
