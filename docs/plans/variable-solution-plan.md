# Variable Solution Plan for ArgoCD Applications

**Issue:** PR #1388 feedback - hardcoded `repoURL` appears 85 times across 63 application.yaml files

**Goal:** Implement DRY principle for repoURL while maintaining GitOps best practices

---

## Current State Analysis

### Structure
```
13 categories (infra/k8s/* and apps/*)
├── 13 parent apps (category-level application.yaml)
└── ~50 child apps (individual application.yaml files)

Total: 63 application.yaml files
Hardcoded repoURL: 85 occurrences
```

### Example Current App Structure
```yaml
# apps/media/radarr/application.yaml
sources:
  - chart: app-template
    repoURL: ghcr.io/bjw-s-labs/helm  # External chart
  - repoURL: 'https://github.com/guilhermewolf/atoca.house'  # Hardcoded ❌
    targetRevision: HEAD
    ref: values
  - repoURL: 'https://github.com/guilhermewolf/atoca.house'  # Hardcoded ❌
    path: apps/media/radarr/
```

### Variables Requested
1. **repoURL** - `https://github.com/guilhermewolf/atoca.house` (85 times)
2. **Paths** - Like `$values/apps/media/radarr/values.yaml` (questionable - app-specific)

---

## Solution Options

### Option 1: ApplicationSet with Git File Generator ⭐ (Recommended)

**Approach:** Convert category parent apps from Application to ApplicationSet

#### How It Works
```yaml
# apps/media/applicationset.yaml (replaces apps/media/application.yaml)
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-media
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/guilhermewolf/atoca.house  # Once! ✅
        revision: HEAD
        files:
          - path: "apps/media/*/app-config.yaml"
  template:
    metadata:
      name: '{{.app.name}}'
    spec:
      project: applications
      sources:
        - chart: '{{.app.chart}}'
          repoURL: '{{.app.chartRepo}}'
          targetRevision: '{{.app.chartVersion}}'
          helm:
            releaseName: '{{.app.name}}'
            valueFiles:
              - $values/apps/media/{{.app.name}}/values.yaml
        - repoURL: https://github.com/guilhermewolf/atoca.house  # Template once ✅
          targetRevision: HEAD
          ref: values
        - repoURL: https://github.com/guilhermewolf/atoca.house  # Template once ✅
          path: 'apps/media/{{.app.name}}'
```

```yaml
# apps/media/radarr/app-config.yaml (new file per app)
app:
  name: radarr
  namespace: radarr
  chart: app-template
  chartRepo: ghcr.io/bjw-s-labs/helm
  # renovate: datasource=docker depName=ghcr.io/bjw-s-labs/helm/app-template
  chartVersion: 4.5.0
```

#### Pros
✅ **ArgoCD Native** - Official solution for DRY
✅ **repoURL once per category** - 85 → 13 occurrences (85% reduction)
✅ **Go templating** - Powerful, flexible
✅ **Auto-discovery** - Add app-config.yaml, app appears automatically
✅ **Pure GitOps** - No preprocessing needed
✅ **Future-proof** - ArgoCD's recommended pattern
✅ **Maintains current discovery pattern** - Parent discovers children

#### Cons
❌ **New file per app** - Requires app-config.yaml (50 new files)
❌ **Bigger change** - Convert 13 parent apps
❌ **Learning curve** - Team needs to understand ApplicationSet
❌ **Migration effort** - Must migrate all apps at once per category
❌ **Less explicit** - Template logic vs direct manifests

#### Migration Effort
- **Files to create:** 50 app-config.yaml files
- **Files to modify:** 13 parent apps (Application → ApplicationSet)
- **Files to delete:** 50 child application.yaml files (moved to app-config)
- **Time estimate:** 4-6 hours
- **Risk:** Medium (can migrate category-by-category)

---

### Option 2: Kustomize Components with Bases

**Approach:** Create base application template, apps overlay with kustomize

#### How It Works
```yaml
# common/base/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: PLACEHOLDER
spec:
  sources:
    - repoURL: REPO_URL  # Will be replaced
      targetRevision: HEAD
      ref: values
```

```yaml
# apps/media/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd

replacements:
  - source:
      kind: ConfigMap
      name: repo-config
      fieldPath: data.repoURL
    targets:
      - select:
          kind: Application
        fieldPaths:
          - spec.sources.[repoURL=REPO_URL].repoURL

configMapGenerator:
  - name: repo-config
    literals:
      - repoURL=https://github.com/guilhermewolf/atoca.house

resources:
  - radarr/application.yaml
  - sonarr/application.yaml
```

```yaml
# apps/media/application.yaml (parent app updated)
source:
  repoURL: https://github.com/guilhermewolf/atoca.house
  path: apps/media
  kustomize: {}  # Enable kustomize build
```

#### Pros
✅ **Keep Application structure** - No ApplicationSet conversion
✅ **Kustomize familiar** - Existing knowledge
✅ **Gradual migration** - Category by category
✅ **repoURL per category** - 85 → 13 occurrences

#### Cons
❌ **Not ArgoCD native** - Requires kustomize build
❌ **Complexity** - 13 kustomization.yaml files
❌ **Parent apps must use kustomize** - Changes discovery pattern
❌ **Replacement syntax** - Complex, error-prone
❌ **Build step** - ArgoCD must run kustomize build
❌ **Harder to debug** - Template vs actual manifests

#### Migration Effort
- **Files to create:** 13 kustomization.yaml files
- **Files to modify:** 13 parent apps (add kustomize), 50 child apps (add placeholder)
- **Time estimate:** 3-4 hours
- **Risk:** Medium-High (kustomize replacements can be tricky)

---

### Option 3: Kustomize Simple (Components Only)

**Approach:** Just list resources in kustomization.yaml, keep repoURL as-is

#### How It Works
```yaml
# apps/media/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd

resources:
  - radarr/application.yaml
  - sonarr/application.yaml
  - bazarr/application.yaml
  # ... all apps
```

#### Pros
✅ **Minimal change** - Just add listing
✅ **Simple** - No replacements
✅ **Fast migration** - 1-2 hours

#### Cons
❌ **Doesn't solve the problem** - repoURL still hardcoded
❌ **Manual updates** - 13 kustomization.yaml to maintain
❌ **No real benefit** - Adds complexity without DRY

**Verdict:** ❌ Not recommended - doesn't address reviewer's concern

---

### Option 4: Keep Current Structure (No Change)

**Approach:** Document rationale, keep as-is

#### Rationale
- **repoURL rarely changes** - Once set during initial setup
- **Explicit is better** - Clear what repo each app uses
- **Official ArgoCD examples** - Show hardcoded repoURL
- **Low maintenance burden** - 1 change across 85 lines = 5 minutes with find/replace

#### Pros
✅ **Zero migration effort**
✅ **Explicit and clear**
✅ **Matches ArgoCD examples**
✅ **Simple to understand**

#### Cons
❌ **Reviewer unhappy** - Wants DRY
❌ **Fork/rename needs 85 changes** - But this is rare
❌ **Not addressing feedback**

**Verdict:** ❌ Not recommended - ignores valid feedback

---

### Option 5: Hybrid (Taskfile + Templating Script)

**Approach:** Generate application.yaml from templates using task

#### How It Works
```yaml
# apps/media/radarr/app-template.yaml
{{- $repo := .RepoURL }}
sources:
  - repoURL: '{{ $repo }}'
    path: apps/media/radarr
```

```yaml
# Taskfile.yaml
generate-apps:
  cmds:
    - go run scripts/generate-apps.go
  env:
    REPO_URL: https://github.com/guilhermewolf/atoca.house
```

#### Pros
✅ **Full control** - Custom templating
✅ **Can version templates** - .gitignore generated files
✅ **Flexible** - Any templating language

#### Cons
❌ **Not GitOps** - Generated files vs source of truth
❌ **Build step required** - Before commit/push
❌ **Complexity** - Custom tooling
❌ **Easy to forget** - Must regenerate
❌ **CI/CD check needed** - Ensure generated files are up to date

**Verdict:** ❌ Not recommended - breaks GitOps principles

---

## Detailed Comparison Matrix

| Criteria | ApplicationSet | Kustomize Replacements | Keep As-Is | Hybrid Script |
|----------|----------------|------------------------|------------|---------------|
| **DRY Achieved** | ✅ 85→13 | ✅ 85→13 | ❌ 85 | ✅ 85→1 |
| **ArgoCD Native** | ✅ Official | ⚠️ Supported | ✅ Yes | ❌ Custom |
| **GitOps Pure** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **Migration Effort** | 🟡 Medium | 🟡 Medium | ✅ Zero | 🔴 High |
| **Complexity** | 🟡 Medium | 🔴 High | ✅ Low | 🔴 High |
| **Future-Proof** | ✅ Recommended | ⚠️ Works | ✅ Stable | ❌ Custom |
| **Team Learning** | 🟡 New concept | ✅ Familiar | ✅ None | 🔴 Custom |
| **Debugging** | 🟡 Template | 🔴 Complex | ✅ Direct | 🔴 Generated |
| **Flexibility** | ✅ High | 🟡 Limited | ✅ Full | ✅ Full |

---

## Recommended Solution: ApplicationSet (Option 1)

### Why ApplicationSet?
1. **ArgoCD's official solution** for this exact problem
2. **Matches ArgoCD philosophy** - declarative, GitOps-native
3. **Best long-term investment** - Future features will target ApplicationSet
4. **Addresses reviewer feedback** - DRY principle achieved
5. **Maintains discovery pattern** - Parent discovers children (just with templating)

### Migration Strategy

#### Phase 1: Pilot (1 category)
**Target:** `apps/media` (11 apps - medium complexity)

1. Create `apps/media/applicationset.yaml`
2. Create 11 `app-config.yaml` files
3. Delete old `apps/media/application.yaml` (parent)
4. Keep child application.yaml files temporarily (for reference)
5. Test discovery and sync
6. Document lessons learned

**Time:** 2-3 hours
**Risk:** Low (isolated to one category)

#### Phase 2: Rollout (Remaining 12 categories)
**Order:**
1. Small categories first: `apps/home-automation` (1 app)
2. Medium: `apps/auth` (2 apps), `apps/data` (2 apps)
3. Large: `infra/k8s/storage` (4 apps), `infra/k8s/security` (4 apps)

**Time:** 4-6 hours total
**Risk:** Low (proven pattern from Phase 1)

#### Phase 3: Cleanup
1. Remove old child application.yaml files
2. Update root app if needed
3. Document new structure
4. Update contribution guide

**Time:** 1 hour

### File Changes Summary

**Per Category (13 total):**
- **Create:** 1 applicationset.yaml
- **Create:** ~4 app-config.yaml files (average)
- **Delete:** 1 parent application.yaml
- **Delete:** ~4 child application.yaml files (after migration)

**Total:**
- **+63 files:** app-config.yaml (one per app)
- **+13 files:** applicationset.yaml (one per category)
- **-63 files:** application.yaml (replaced by app-config)
- **Net:** +13 files (just the ApplicationSets)

### Code Structure After Migration

```
apps/media/
├── applicationset.yaml          # Parent (manages discovery)
├── radarr/
│   ├── app-config.yaml         # App metadata ✨ NEW
│   └── values.yaml             # Helm values (unchanged)
├── sonarr/
│   ├── app-config.yaml         # App metadata ✨ NEW
│   └── values.yaml             # Helm values (unchanged)
└── ...
```

---

## Alternative Recommendation: Phased Approach

If full ApplicationSet migration seems too big:

### Phase 1: Fix Immediate Issues (This PR)
1. ✅ Fix missing `infra-project.yaml` file
2. ✅ Fix VS Code schema pattern
3. ✅ Add workflow fallback logic
4. ✅ Add validation tasks to Taskfile
5. ✅ Respond to reviewer: "Planning ApplicationSet migration in follow-up PR"

**Merge PR #1388** ← Get current work merged

### Phase 2: ApplicationSet Migration (New PR)
1. ✅ Pilot with `apps/media` category
2. ✅ Document pattern
3. ✅ Rollout to remaining categories
4. ✅ Update documentation

**Benefits:**
- PR #1388 gets merged faster
- ApplicationSet work is isolated and focused
- Team can review smaller changes
- Can gather feedback after pilot

---

## Decision Framework

**Choose ApplicationSet if:**
- ✅ Team willing to learn new pattern
- ✅ Long-term maintainability matters
- ✅ Want ArgoCD-native solution
- ✅ Can dedicate 6-8 hours for migration

**Choose Kustomize if:**
- ✅ Team already expert in Kustomize
- ✅ Want to keep Application resources
- ✅ Okay with preprocessor complexity
- ⚠️ Less future-proof

**Choose Phased if:**
- ✅ Need to merge PR #1388 quickly
- ✅ Want to validate approach before full migration
- ✅ Team needs time to learn ApplicationSet
- ✅ **Recommended for this situation**

---

## Questions for Decision

1. **Urgency:** Do you need PR #1388 merged ASAP, or can it wait for ApplicationSet migration?
2. **Team:** Is team familiar with ApplicationSet, or learning curve needed?
3. **Scope:** Pilot one category first, or migrate all at once?
4. **Risk Tolerance:** Comfortable with larger architectural change?

---

## Next Steps

**If choosing ApplicationSet:**
1. Create pilot ApplicationSet for `apps/media`
2. Test discovery and sync
3. Document pattern
4. Get team feedback
5. Proceed with rollout

**If choosing Phased:**
1. Fix immediate PR issues (infra-project, VS Code, workflow)
2. Merge PR #1388
3. Create new PR for ApplicationSet migration
4. Follow pilot → rollout strategy

---

## References

- [ArgoCD ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [Official Application.yaml Example](https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/application.yaml)
- [Git File Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/)
- [Go Template Support](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/)

---

**Author:** Claude Code
**Date:** 2025-12-11
**PR:** #1388
**Status:** Awaiting decision
