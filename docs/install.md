# Cluster Installation Guide

This guide covers installing the Kubernetes cluster from scratch using automated Ansible playbooks.

## Prerequisites

### Required Tools

- **1Password CLI** (`op`) - For secret management
- **talosctl** - Talos Linux CLI tool
- **kubectl** - Kubernetes CLI tool
- **ansible** - Automation tool
- **sops** - Secret encryption
- **yq** - YAML processor

Install on macOS:

```bash
brew install --cask 1password-cli
brew install talosctl kubectl ansible sops yq
```

### Required Credentials

- 1Password account with access to K8s vault
- Age encryption key stored in 1Password (`op://K8s/age-key/age.key`)
- ArgoCD Redis secret stored in 1Password

### Hardware Requirements

- 3x Mini PCs with AMD Ryzen 7 4800H, 16GB RAM
- 256GB NVMe for Talos OS (per node)
- 1TB NVMe for Ceph storage (per node)
- Network connectivity on 192.168.40.0/24

## Installation Steps

### Step 1: Generate Talos Configurations

First, create custom Talos image with required extensions:

1. Visit <https://factory.talos.dev/>
2. Select:
   - Architecture: `amd64`
   - Platform: `bare-metal`
   - Talos version: `1.9.0` or latest
3. Add extensions:
   - `siderolabs/iscsi-tools`
   - `siderolabs/util-linux-tools`
4. Save the schematic ID

Then generate the cluster configs:

```bash
cd infra/talos

# Ensure age key is available
mkdir -p $HOME/.config/age/
chmod 700 ~/.config/age/
op read op://K8s/age-key/age.key > $HOME/.config/age/age.key
chmod 600 ~/.config/age/age.key

# Generate and encrypt configs
./generate-configs.sh
```

This creates encrypted configs for all 3 control plane nodes.

### Step 2: Prepare Hardware

1. **Flash Talos ISO** to all 3 nodes:
   - Download ISO from factory with your schematic ID
   - Boot each node from USB or PXE

2. **Verify network and disks**:

   ```bash
   # Check node is accessible (temporary IP from DHCP)
   talosctl -n <node-temp-ip> disks

   # Should show:
   # - /dev/sda (256GB) - for Talos OS
   # - /dev/sdb (1TB) - for Ceph storage
   ```

3. **Note interface names**:

   ```bash
   talosctl -n <node-temp-ip> get links
   ```

   If your interface is not `eth0`, update `infra/talos/patches/node-*.yaml` files.

### Step 3: Bootstrap Cluster

Authenticate with 1Password and run the automated bootstrap:

```bash
# Authenticate with 1Password
eval $(op signin)

# Run bootstrap playbook (takes 45-60 minutes)
cd infra/ansible
ansible-playbook bootstrap.yaml
```

The playbook will:

1. ✅ Setup age encryption
2. ✅ Deploy Talos configs to all 3 nodes
3. ✅ Bootstrap first control plane
4. ✅ Wait for all nodes to join
5. ✅ Install Cilium CNI
6. ✅ Install Sealed Secrets
7. ✅ Install ArgoCD
8. ✅ Deploy Rook-Ceph operator and cluster
9. ✅ Wait for critical infrastructure to be healthy

### Step 4: Verify Installation

After bootstrap completes:

```bash
# Check cluster nodes
kubectl get nodes -o wide
# Should show 3 nodes, all control-plane, all Ready

# Check ArgoCD applications
kubectl get applications -n argocd
# All apps should be Synced and Healthy

# Check Ceph cluster
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
# Should show HEALTH_OK (may take 10-15 minutes)

# Check storage classes
kubectl get storageclass
# Should show ceph-block (default), ceph-filesystem, ceph-bucket
```

### Step 5: Access Services

**ArgoCD:**

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Open browser: https://localhost:8080
# Username: admin
```

**Ceph Dashboard:**

```bash
# Get password
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 -d

# Port forward
kubectl port-forward -n rook-ceph svc/rook-ceph-mgr-dashboard 7000:7000

# Open browser: http://localhost:7000
# Username: admin
```

## Manual Installation (Advanced)

If you prefer manual installation without Ansible:

<details>
<summary>Click to expand manual steps</summary>

```bash
# 1. Setup age encryption
mkdir -p $HOME/.config/age/
chmod 700 ~/.config/age/
op read op://K8s/age-key/age.key > $HOME/.config/age/age.key
chmod 600 ~/.config/age/age.key
export SOPS_AGE_KEY_FILE="$HOME/.config/age/age.key"

# 2. Decrypt Talos configs
sops -d infra/talos/controlplane-node-01.enc.yaml > infra/talos/controlplane-node-01.yaml
sops -d infra/talos/controlplane-node-02.enc.yaml > infra/talos/controlplane-node-02.yaml
sops -d infra/talos/controlplane-node-03.enc.yaml > infra/talos/controlplane-node-03.yaml
sops -d infra/talos/config.enc.yaml > $HOME/.talos/config

# 3. Apply configs to all nodes
talosctl apply-config --insecure --nodes 192.168.40.11 --file infra/talos/controlplane-node-01.yaml
talosctl apply-config --insecure --nodes 192.168.40.12 --file infra/talos/controlplane-node-02.yaml
talosctl apply-config --insecure --nodes 192.168.40.13 --file infra/talos/controlplane-node-03.yaml

# 4. Bootstrap first control plane
sleep 30
talosctl bootstrap -n 192.168.40.11

# 5. Get kubeconfig
talosctl kubeconfig -f -n 192.168.40.11

# 6. Wait for nodes to be ready
kubectl wait --for=condition=ready nodes --all --timeout=600s

# 7. Install Cilium
kubectl kustomize --enable-helm infra/k8s/networking/cilium | kubectl apply -f -
kubectl wait --for=condition=ready pod -l k8s-app=cilium -n kube-system --timeout=300s

# 8. Install Sealed Secrets
kubectl kustomize --enable-helm infra/k8s/security/sealed-secrets | kubectl apply -f -
kubectl wait --for=condition=available deployment/sealed-secrets-controller -n sealed-secrets --timeout=300s

# 9. Install ArgoCD
kubectl create namespace argocd
kubectl kustomize --enable-helm argocd/install | kubectl apply -f -
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 10. Apply ArgoCD applications
kubectl apply -f argocd/applications/

# 11. Clean up decrypted files
rm infra/talos/controlplane-node-*.yaml
```

</details>

## Troubleshooting

### Nodes not joining cluster

```bash
# Check node logs
talosctl -n <node-ip> logs controller-runtime

# Check etcd status
talosctl -n 192.168.40.11 etcd status
```

### Ceph not starting

```bash
# Check disks are visible
talosctl -n <node-ip> disks

# Check OSD logs
kubectl -n rook-ceph logs -l app=rook-ceph-osd

# Check Ceph status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
```

### ArgoCD apps stuck syncing

```bash
# Check app details
kubectl describe application <app-name> -n argocd

# Force sync
argocd app sync <app-name>
```

## Maintenance

### Updating Talos

Use the automated upgrade playbook:

```bash
cd infra/ansible
ansible-playbook update-talos.yaml
```

### Backing Up Cluster

```bash
# Backup etcd
talosctl -n 192.168.40.11 etcd snapshot snapshot.db

# Backup all resources
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
```

## References

- [Talos Configuration Guide](/infra/talos/README.md)
- [Rook-Ceph Guide](/infra/k8s/storage/rook-ceph-cluster/README.md)
- [Migration Guide](/docs/migration-to-new-cluster.md)
- [Main README](/README.md)
