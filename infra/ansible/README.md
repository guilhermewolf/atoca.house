# Ansible Automation

This directory contains Ansible playbooks and roles for automating Kubernetes cluster operations.

## 📁 Directory Structure

```
infra/ansible/
├── ansible.cfg                    # Ansible configuration
├── inventory/
│   ├── hosts.yaml                # Inventory (localhost for cluster operations)
│   └── group_vars/
│       └── all.yaml              # Global variables (paths, IPs, timeouts)
├── roles/
│   ├── talos/                    # Talos Linux deployment & bootstrap
│   ├── cilium/                   # Cilium CNI installation
│   ├── sealed_secrets/           # Sealed Secrets controller
│   ├── argocd/                   # ArgoCD installation & configuration
│   ├── one_password/             # 1Password secret sealing
│   └── rook_ceph/                # Rook-Ceph verification
├── playbooks/
│   ├── bootstrap.yaml            # Main cluster bootstrap (30-45 min)
│   ├── seal-secrets.yaml         # Seal 1Password secrets
│   └── update-talos.yaml         # Talos/K8s upgrades
├── requirements.yaml             # Ansible Galaxy dependencies
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites

Install required tools:

```bash
# macOS
brew install ansible kubectl talosctl sops kubeseal

# Install 1Password CLI
brew install --cask 1password-cli

# Authenticate 1Password CLI
eval $(op signin)
```

Install Ansible dependencies:

```bash
cd infra/ansible
ansible-galaxy install -r requirements.yaml
```

### Bootstrap New Cluster

```bash
# Full bootstrap (30-45 minutes)
ansible-playbook playbooks/bootstrap.yaml

# Run specific phases only
ansible-playbook playbooks/bootstrap.yaml --tags phase1  # Talos only
ansible-playbook playbooks/bootstrap.yaml --tags phase2  # Cilium only
ansible-playbook playbooks/bootstrap.yaml --tags phase3  # Sealed Secrets only
ansible-playbook playbooks/bootstrap.yaml --tags phase4  # ArgoCD only
ansible-playbook playbooks/bootstrap.yaml --tags phase5  # Rook-Ceph verification
```

### Seal 1Password Secrets

```bash
# Seal secrets for 1Password operator
ansible-playbook playbooks/seal-secrets.yaml

# Then manually commit:
git add infra/k8s/security/one-password/*.yaml
git commit -m "Update 1Password sealed secrets"
git push
```

### Update Talos/Kubernetes

```bash
# Set your Talos factory schematic ID
export TALOS_FACTORY_SCHEMATIC_ID="your-schematic-id-here"

# Upgrade Talos (rolling upgrade, one node at a time)
ansible-playbook playbooks/update-talos.yaml
```

## 📚 Playbooks

### `bootstrap.yaml` - Full Cluster Bootstrap

**Purpose:** Bootstrap a new Talos Kubernetes cluster from scratch with ArgoCD GitOps.

**What it does:**

1. **Setup Age encryption** - Retrieves Age key from 1Password for SOPS
2. **Deploy Talos** - Applies configs to all 3 nodes, bootstraps cluster
3. **Install Cilium** - eBPF networking (CNI) with Gateway API support
4. **Install Sealed Secrets** - Encrypted secret management in Git
5. **Install ArgoCD** - GitOps continuous deployment
6. **Deploy Applications** - Root app-of-apps discovers all infrastructure
7. **Verify Rook-Ceph** - Validates distributed storage is healthy

**Time:** 30-45 minutes

**Requirements:**

- Age key in 1Password: `op://K8s/age-key/age.key`
- ArgoCD Redis secret: `op://Private/atoca-house-k8s-argocd-redis/credential`
- Encrypted Talos configs in `infra/talos/`

**Tags:**

- `bootstrap` - All bootstrap tasks
- `phase1` - Talos deployment
- `phase2` - Cilium CNI
- `phase3` - Sealed Secrets
- `phase4` - ArgoCD
- `phase5` - Rook-Ceph verification
- Individual roles: `talos`, `cilium`, `sealed-secrets`, `argocd`, `rook-ceph`

**Example:**

```bash
# Full bootstrap
ansible-playbook playbooks/bootstrap.yaml

# Skip Ceph verification (faster)
ansible-playbook playbooks/bootstrap.yaml --skip-tags rook-ceph

# Only deploy ArgoCD
ansible-playbook playbooks/bootstrap.yaml --tags argocd

# Dry run
ansible-playbook playbooks/bootstrap.yaml --check
```

### `seal-secrets.yaml` - Seal 1Password Secrets

**Purpose:** Retrieve secrets from 1Password and seal them for safe storage in Git.

**What it does:**

1. Retrieves 1Password token from 1Password
2. Retrieves 1Password credentials file from 1Password
3. Creates Kubernetes secret manifests (unsealed)
4. Seals secrets with kubeseal (encrypted with cluster public key)
5. Writes sealed secrets to `infra/k8s/security/one-password/`

**Time:** 1-2 minutes

**Requirements:**

- 1Password CLI authenticated: `eval $(op signin)`
- Sealed Secrets controller running in cluster
- 1Password secrets exist at configured paths

**Output:**

- `infra/k8s/security/one-password/onepassword-token.yaml` (sealed)
- `infra/k8s/security/one-password/op-credentials.yaml` (sealed)

**Important:** This does NOT automatically commit to Git. You must manually review and commit.

**Example:**

```bash
# Seal secrets
ansible-playbook playbooks/seal-secrets.yaml

# Then commit
git add infra/k8s/security/one-password/*.yaml
git commit -m "Update 1Password sealed secrets"
git push
```

### `update-talos.yaml` - Update Talos/Kubernetes

**Purpose:** Rolling upgrade of Talos Linux and optionally Kubernetes.

**What it does:**

1. Fetches latest Talos version from GitHub
2. Displays upgrade plan (version, nodes)
3. Upgrades each node ONE AT A TIME (maintains availability)
4. Waits for each node to be Ready before proceeding
5. Optionally upgrades Kubernetes (commented out by default)

**Time:** 15-30 minutes (depends on node count and download speed)

**Requirements:**

- Talos factory schematic ID (custom image with extensions)
- Set via: `export TALOS_FACTORY_SCHEMATIC_ID="your-id"`
- Or edit playbook and hardcode the value

**Generate schematic:** <https://factory.talos.dev/>

**Example:**

```bash
# Set schematic ID
export TALOS_FACTORY_SCHEMATIC_ID="abc123def456"

# Upgrade Talos
ansible-playbook playbooks/update-talos.yaml

# Upgrade specific version (edit playbook to hardcode version)
```

## 🎭 Roles

Each role handles a specific component of the infrastructure. See individual role READMEs for details.

### `talos` - Talos Linux Deployment

**Responsibilities:**

- Setup Age encryption for SOPS
- Decrypt and apply Talos configurations to all nodes
- Bootstrap first control plane node
- Wait for all nodes to be Ready
- Generate kubeconfig
- Cleanup decrypted files

**Tags:** `talos`, `age`, `encryption`, `deploy`, `bootstrap`, `cleanup`

**See:** `roles/talos/README.md`

### `cilium` - Cilium CNI

**Responsibilities:**

- Deploy Cilium using Helm via kustomize
- Wait for Cilium agents and operator to be ready
- Verify all nodes are Ready after CNI installation

**Tags:** `cilium`, `cni`, `networking`

**See:** `roles/cilium/README.md`

### `sealed_secrets` - Sealed Secrets Controller

**Responsibilities:**

- Deploy Sealed Secrets controller
- Wait for controller to be available
- Verify controller pods are running

**Tags:** `sealed-secrets`, `security`

**See:** `roles/sealed_secrets/README.md`

### `argocd` - ArgoCD GitOps

**Responsibilities:**

- Setup ArgoCD Redis secret from 1Password
- Install ArgoCD (server, repo-server, controller)
- Apply ArgoCD root app-of-apps
- Verify critical infrastructure apps are synced and healthy

**Tags:** `argocd`, `gitops`, `secrets`, `install`, `applications`, `verify`

**See:** `roles/argocd/README.md`

### `one_password` - 1Password Secret Sealing

**Responsibilities:**

- Retrieve 1Password token and credentials from 1Password
- Create Kubernetes secret manifests
- Seal secrets with kubeseal
- Write sealed secrets to `infra/k8s/security/one-password/`
- Cleanup temporary files

**Tags:** `onepassword`, `retrieve`, `create`, `seal`, `cleanup`

**Important:** Path fixed from old `helm/one-password` to `infra/k8s/security/one-password`

**See:** `roles/one_password/README.md`

### `rook_ceph` - Rook-Ceph Verification

**Responsibilities:**

- Verify Rook-Ceph operator is synced and healthy
- Verify Rook-Ceph cluster is synced and healthy
- Check Ceph cluster health (HEALTH_OK)
- Display Ceph status and storage classes

**Tags:** `rook-ceph`, `storage`, `verify`

**Note:** Ceph can take 10-30 minutes to reach HEALTH_OK. This role is non-blocking.

**See:** `roles/rook_ceph/README.md`

## ⚙️ Configuration

### Global Variables

Edit `inventory/group_vars/all.yaml` to configure:

```yaml
# Cluster nodes
control_plane_nodes:
  - name: node-01
    ip: 192.168.40.11
  - name: node-02
    ip: 192.168.40.12
  - name: node-03
    ip: 192.168.40.13

# Paths
repo_root: /path/to/atoca.house
talos_dir: infra/talos
k8s_infra_dir: infra/k8s

# 1Password paths
op_age_key_path: op://K8s/age-key/age.key
op_argocd_redis_id: Private/atoca-house-k8s-argocd-redis/credential

# Timeouts
cilium_timeout: 300       # 5 minutes
argocd_timeout: 300       # 5 minutes
ceph_timeout: 1800        # 30 minutes
```

### Ansible Configuration

Edit `ansible.cfg` for Ansible behavior:

```ini
[defaults]
inventory = inventory/hosts.yaml
stdout_callback = yaml
forks = 10
gathering = smart
```

## 🏷️ Tags

Tags allow running specific parts of playbooks:

**Phase tags:**

- `phase1` - Talos deployment
- `phase2` - Cilium CNI
- `phase3` - Sealed Secrets
- `phase4` - ArgoCD
- `phase5` - Rook-Ceph verification

**Component tags:**

- `talos`, `cilium`, `sealed-secrets`, `argocd`, `onepassword`, `rook-ceph`

**Action tags:**

- `bootstrap` - All bootstrap tasks
- `deploy`, `install`, `verify`, `cleanup`
- `secrets`, `encryption`, `seal`

**Example:**

```bash
# Run only Talos and Cilium
ansible-playbook playbooks/bootstrap.yaml --tags "talos,cilium"

# Skip Rook-Ceph verification
ansible-playbook playbooks/bootstrap.yaml --skip-tags rook-ceph

# Run only secret-related tasks
ansible-playbook playbooks/bootstrap.yaml --tags secrets
```

## 🔍 Troubleshooting

### Ansible can't find tools

**Error:** `which: no talosctl in...`

**Fix:**

```bash
# Check tools are installed
which ansible talosctl kubectl sops op kubeseal

# Install missing tools
brew install talosctl kubectl sops kubeseal
brew install --cask 1password-cli
```

### 1Password authentication failed

**Error:** `op read failed`

**Fix:**

```bash
# Sign in to 1Password
eval $(op signin)

# Verify access
op read op://K8s/age-key/age.key
```

### Talos apply-config failed

**Error:** `connection refused` or `timeout`

**Fix:**

```bash
# Check nodes are reachable
ping 192.168.40.11

# Check Talos is running
talosctl -n 192.168.40.11 version

# Reboot nodes if needed
```

### Cilium pods not ready

**Error:** Cilium pods stuck in Pending or CrashLoopBackOff

**Fix:**

```bash
# Check node status
kubectl get nodes

# Check Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium

# Restart Cilium pods
kubectl rollout restart daemonset/cilium -n kube-system
```

### Ceph not HEALTH_OK

**Issue:** Ceph cluster stuck in HEALTH_WARN

**Fix:**

```bash
# Check Ceph status
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

# Check OSD pods
kubectl get pods -n rook-ceph -l app=rook-ceph-osd

# Wait 10-15 minutes - Ceph needs time
# Check again after waiting
```

### ArgoCD apps not syncing

**Issue:** Applications stuck in OutOfSync or Progressing

**Fix:**

```bash
# Check ArgoCD app status
kubectl get applications -n argocd

# Describe specific app
kubectl describe application <app-name> -n argocd

# Force sync via UI or CLI
kubectl -n argocd patch application <app-name> --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {"prune": true}}}'
```

## 🔐 Security

### Secret Management

- **Age encryption** - Used for SOPS (encrypts Talos configs, secrets)
- **Sealed Secrets** - Asymmetric encryption for Kubernetes secrets in Git
- **1Password** - Secure storage for secrets, tokens, credentials
- **No secrets in Git** - Only encrypted/sealed secrets committed

### Best Practices

- ✅ Age key stored in 1Password (never in Git)
- ✅ Talos configs encrypted with SOPS
- ✅ Kubernetes secrets sealed with kubeseal
- ✅ Temporary files removed after use
- ✅ No automatic git commits (manual review required)
- ✅ `no_log: true` for sensitive tasks

## 📊 Monitoring

### After Bootstrap

```bash
# Check cluster health
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Check ArgoCD applications
kubectl get applications -n argocd

# Check Ceph status
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

# Check storage classes
kubectl get storageclass
```

### Access UIs

```bash
# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080
# User: admin
# Pass: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Ceph Dashboard
kubectl port-forward -n rook-ceph svc/rook-ceph-mgr-dashboard 7000:7000
# https://localhost:7000
# User: admin
# Pass: kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 -d
```

## 🔄 Integration with Taskfile

All playbooks can be run via Taskfile for convenience:

```bash
# Bootstrap cluster
task cluster:bootstrap

# Seal 1Password secrets
task cluster:seal-secrets

# Update Talos
task cluster:update-talos

# Verify cluster
task cluster:verify-cluster

# Check Ceph status
task cluster:ceph-status
```

See `.taskfiles/cluster/Taskfile.yaml` for all available tasks.

## 📝 Changelog

**2025-12-10** - Major restructure:

- ✅ Reorganized into roles and playbooks (best practices)
- ✅ Separated concerns (modularity)
- ✅ Fixed one-password.yaml path issue
- ✅ Removed db-init.yaml (not needed)
- ✅ Improved error handling and idempotency
- ✅ Added comprehensive documentation
- ✅ Removed automatic git commits (anti-pattern)
- ✅ Added tags for granular control

## 🔗 Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Talos Linux Documentation](https://www.talos.dev/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
- [Rook-Ceph Documentation](https://rook.io/docs/rook/latest/)
- [Cilium Documentation](https://docs.cilium.io/)
- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
