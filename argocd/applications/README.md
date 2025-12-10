# ArgoCD Applications

This directory contains the root-level ArgoCD configuration for managing the entire cluster via GitOps.

## Structure

The GitOps system uses a hierarchical app-of-apps pattern:

```
argocd/applications/
├── root.yaml              # Root app-of-apps (entry point)
├── argocd.yaml            # ArgoCD self-management
├── project.yaml           # App-of-apps project
├── infra-project.yaml     # Infrastructure project
└── applications-project.yaml  # Applications project

infra/k8s/
├── networking/
│   ├── application.yaml   # Parent app (discovers cilium, envoy-gateway, etc.)
│   ├── cilium/application.yaml
│   ├── envoy-gateway/application.yaml
│   └── ...
├── storage/
│   ├── application.yaml   # Parent app (discovers rook-ceph, etc.)
│   ├── rook-ceph-operator/application.yaml
│   └── ...
└── ... (other infra categories)

apps/
├── media/
│   ├── application.yaml   # Parent app (discovers radarr, sonarr, etc.)
│   ├── radarr/application.yaml
│   ├── sonarr/application.yaml
│   └── ...
├── data/
│   ├── application.yaml   # Parent app (discovers postgres, etc.)
│   └── ...
└── ... (other app categories)
```

## How It Works

### 1. Root App (`root.yaml`)

The single entry point that discovers all category parent apps:
- Scans `infra/k8s/*/application.yaml`
- Scans `apps/*/application.yaml`
- Creates parent apps for each category

### 2. Category Parent Apps

Each category (networking, storage, media, etc.) has an `application.yaml` that:
- Discovers all child apps in that category using directory recursion
- Manages the lifecycle of apps in that category
- Uses the app-of-apps pattern

### 3. Child Apps

Individual applications (cilium, radarr, etc.) have their own `application.yaml` that:
- Defines the Helm chart or Kustomize manifests
- Specifies sync policies
- Configures the application

## Deployment

### Bootstrap

During cluster bootstrap, the system is deployed in this order:

1. **Manual Bootstrap** (via Ansible or Taskfile):
   ```bash
   task cluster:bootstrap
   # OR
   cd infra/ansible && ansible-playbook bootstrap.yaml
   ```

   This installs:
   - Talos OS on all nodes
   - Cilium CNI (manually applied)
   - Sealed Secrets (manually applied)
   - ArgoCD (manually applied from `argocd/install/`)

2. **ArgoCD Takes Over**:
   ```bash
   kubectl apply -k argocd/applications/
   ```

   This creates:
   - `root` app → discovers all category parents
   - Category parents → discover all child apps
   - Child apps → sync from Git

### Adding New Apps

To add a new application:

1. **Create app directory** in appropriate category:
   ```bash
   mkdir -p apps/media/newapp
   ```

2. **Add application.yaml**:
   ```yaml
   # apps/media/newapp/application.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: newapp
     namespace: argocd
   spec:
     project: applications
     source:
       repoURL: https://github.com/guilhermewolf/atoca.house
       targetRevision: HEAD
       path: apps/media/newapp
       # ... rest of config
     destination:
       namespace: newapp
       server: https://kubernetes.default.svc
     syncPolicy:
       automated:
         selfHeal: true
         prune: true
   ```

3. **Commit and push**:
   ```bash
   git add apps/media/newapp
   git commit -m "Add newapp to media category"
   git push
   ```

4. **ArgoCD automatically discovers** it within ~3 minutes (default sync interval)

### Adding New Categories

To add a new category (e.g., `infra/k8s/databases/`):

1. **Create category directory**:
   ```bash
   mkdir -p infra/k8s/databases
   ```

2. **Create parent application.yaml**:
   ```yaml
   # infra/k8s/databases/application.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: infra-databases
     namespace: argocd
   spec:
     project: infra
     source:
       repoURL: https://github.com/guilhermewolf/atoca.house
       targetRevision: HEAD
       path: infra/k8s/databases
       directory:
         recurse: true
         include: '*/application.yaml'
         exclude: 'application.yaml'
     destination:
       namespace: argocd
       server: https://kubernetes.default.svc
     syncPolicy:
       automated:
         selfHeal: true
         prune: true
   ```

3. **Add child apps** in subdirectories:
   ```bash
   mkdir -p infra/k8s/databases/postgresql
   # Create infra/k8s/databases/postgresql/application.yaml
   ```

4. **Commit and push** - the root app will discover the new category parent automatically

## Projects

ArgoCD projects provide RBAC and resource boundaries:

- **`app-of-apps`** (`project.yaml`) - For root and parent apps
- **`infra`** (`infra-project.yaml`) - For infrastructure apps
- **`applications`** (`applications-project.yaml`) - For user applications

## Advantages of This Structure

### 1. **Self-Contained Categories**
Each category manages itself - no central manifest listing all categories.

### 2. **Easy Navigation**
```bash
# Want to see all media apps?
ls apps/media/

# Want to see all networking infra?
ls infra/k8s/networking/
```

### 3. **Automatic Discovery**
- Add new app → automatically discovered by parent
- Add new category → automatically discovered by root
- No need to update central manifests

### 4. **Clear Ownership**
- Each directory contains everything related to that category/app
- Parent `application.yaml` lives with the children it manages

### 5. **Easy Refactoring**
Move apps between categories with `git mv` - root app finds them automatically.

## Useful Commands

### Using Taskfile

```bash
# List all available cluster tasks
task cluster --list

# Bootstrap cluster
task cluster:bootstrap

# Verify cluster health
task cluster:verify-cluster

# Port forward ArgoCD
task cluster:port-forward-argocd

# Sync all apps
task cluster:sync-argocd-apps
```

### Using kubectl

```bash
# View all applications
kubectl get applications -n argocd

# View specific category
kubectl get applications -n argocd -l app.kubernetes.io/name=infra-networking

# Sync all apps
kubectl get applications -n argocd -o name | \
  xargs -I {} kubectl -n argocd patch {} \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# View app details
kubectl describe application <app-name> -n argocd
```

### Using ArgoCD CLI

```bash
# Login
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# List apps
argocd app list

# Sync app
argocd app sync <app-name>

# Sync all
argocd app sync --all
```

## Troubleshooting

### App not appearing

1. **Check parent app is synced**:
   ```bash
   kubectl get application -n argocd
   ```

2. **Check directory structure**:
   ```bash
   # Must have application.yaml in subdirectory
   ls <category>/<app>/application.yaml
   ```

3. **Force refresh parent**:
   ```bash
   kubectl -n argocd patch application <parent-name> \
     --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
   ```

### App stuck in Progressing/OutOfSync

1. **Check app health**:
   ```bash
   kubectl describe application <app-name> -n argocd
   ```

2. **View sync status**:
   ```bash
   argocd app get <app-name>
   ```

3. **Force sync**:
   ```bash
   argocd app sync <app-name> --force
   ```

### Root app not discovering categories

1. **Verify root app exists**:
   ```bash
   kubectl get application root -n argocd
   ```

2. **Check root app sources**:
   ```bash
   kubectl get application root -n argocd -o yaml
   ```

3. **Verify directory pattern match**:
   - Parent apps must be named `application.yaml`
   - Must be in direct subdirectories (not nested deeper)

## References

- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [ArgoCD Projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [Main README](/README.md)
