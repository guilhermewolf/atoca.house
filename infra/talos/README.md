# Talos Linux Configuration - New Cluster

## Cluster Specifications

**Hardware:**

- 3x Mini PCs with AMD Ryzen 7 4800H
- 16GB RAM per node
- 256GB system disk (Talos OS)
- 1TB data disk (Ceph storage)

**Architecture:**

- 3 control plane nodes (no workers)
- HA etcd cluster (3 replicas)
- Distributed storage with Rook-Ceph

## Network Configuration

| Node | Role | IP Address |
|------|------|------------|
| node-01 | Control Plane | 192.168.40.11 |
| node-02 | Control Plane | 192.168.40.12 |
| node-03 | Control Plane | 192.168.40.13 |

**Network Details:**

- Server VLAN: `192.168.40.0/24`
- Kubernetes Pods (Cilium): `10.244.0.0/16`
- Kubernetes Services: `10.96.0.0/12`
- Cluster Endpoint: `https://192.168.40.11:6443` (VIP or first node)

## Talos Image

Create custom Talos image with required extensions:

**Factory URL:** <https://factory.talos.dev/>

**Configuration:**

- Platform: Bare Metal (x86_64)
- Talos Version: `1.9.0` (or latest stable)
- System Extensions:
  - `siderolabs/qemu-guest-agent` (if running virtualized)
  - `siderolabs/iscsi-tools` (for Rook-Ceph RBD)
  - `siderolabs/util-linux-tools` (for disk management)

## Generating Configurations

### Step 1: Generate Base Configs

```bash
# Set cluster name and endpoint
export CLUSTER_NAME="atoca-k8s"
export CLUSTER_ENDPOINT="https://192.168.40.11:6443"

# Generate configs for all 3 control planes
talosctl gen config $CLUSTER_NAME $CLUSTER_ENDPOINT \
  --output-dir infra/talos/generated \
  --with-secrets infra/talos/generated/secrets.yaml \
  --config-patch-control-plane @infra/talos/patches/controlplane-common.yaml \
  --additional-sans 192.168.40.11 \
  --additional-sans 192.168.40.12 \
  --additional-sans 192.168.40.13
```

### Step 2: Apply Node-Specific Patches

Each node needs specific configuration for:

- Hostname
- Network interface
- Disk configuration (1TB data disk for Ceph)
- Rook-Ceph kubelet mounts

See patch files in `infra/talos/patches/` directory.

### Step 3: Encrypt Configs with SOPS

```bash
# Encrypt each control plane config
for i in 1 2 3; do
  sops --encrypt \
    --config ../../.sops.yaml \
    infra/talos/generated/controlplane-$i.yaml > \
    infra/talos/controlplane-$i.enc.yaml
done

# Store talosconfig securely
sops --encrypt \
  --config ../../.sops.yaml \
  infra/talos/generated/talosconfig > \
  infra/talos/config.enc.yaml
```

## Configuration Patches

### Common Control Plane Patch (`patches/controlplane-common.yaml`)

Applies to all 3 control plane nodes:

```yaml
machine:
  # Install configuration
  install:
    disk: /dev/sda  # 256GB system disk
    image: factory.talos.dev/installer/<your-schematic-id>:v1.9.0
    wipe: false

  # Network configuration
  network:
    hostname: ""  # Override per node
    nameservers:
      - 192.168.40.1
      - 1.1.1.1

  # Kubelet configuration for Rook-Ceph
  kubelet:
    extraMounts:
      - destination: /var/lib/rook
        type: bind
        source: /var/lib/rook
        options:
          - bind
          - rshared
          - rw
    nodeIP:
      validSubnets:
        - 192.168.40.0/24

  # Time configuration
  time:
    disabled: false
    servers:
      - time.cloudflare.com

  # Features
  features:
    rbac: true
    stableHostname: true
    kubernetesTalosAPIAccess:
      enabled: true
      allowedRoles:
        - os:admin
      allowedKubernetesNamespaces:
        - kube-system

  # System disk partitions
  disks:
    - device: /dev/sdb  # 1TB data disk for Ceph
      partitions:
        - mountpoint: /var/mnt/ceph

# Cluster configuration
cluster:
  # Discovery
  discovery:
    enabled: true
    registries:
      kubernetes:
        disabled: false
      service:
        disabled: false

  # Network
  network:
    cni:
      name: none  # Using Cilium
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12

  # Proxy configuration
  proxy:
    disabled: true  # Using Cilium kube-proxy replacement

  # Scheduler configuration
  scheduler:
    config:
      apiVersion: kubescheduler.config.k8s.io/v1
      kind: KubeSchedulerConfiguration

  # Controller manager
  controllerManager:
    extraArgs:
      bind-address: 0.0.0.0

  # API server configuration
  apiServer:
    certSANs:
      - 192.168.40.11
      - 192.168.40.12
      - 192.168.40.13
    extraArgs:
      feature-gates: MixedProtocolLBService=true

  # Etcd configuration (3-node HA)
  etcd:
    advertisedSubnets:
      - 192.168.40.0/24

  # Allow scheduling on control plane nodes
  allowSchedulingOnControlPlanes: true
```

### Node-Specific Patches

Create `patches/node-01.yaml`, `node-02.yaml`, `node-03.yaml`:

**node-01.yaml:**

```yaml
machine:
  network:
    hostname: node-01
    interfaces:
      - interface: enp5s0f3u2  # Adjust to your interface name
        dhcp: false
        addresses:
          - 192.168.40.11/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.40.1
cluster:
  etcd:
    advertisedSubnets:
      - 192.168.40.0/24
```

**node-02.yaml:**

```yaml
machine:
  network:
    hostname: node-02
    interfaces:
      - interface: enp5s0f3u2
        dhcp: false
        addresses:
          - 192.168.40.12/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.40.1
```

**node-03.yaml:**

```yaml
machine:
  network:
    hostname: node-03
    interfaces:
      - interface: enp5s0f3u2
        dhcp: false
        addresses:
          - 192.168.40.13/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.40.1
```

## Helper Script

See `generate-configs.sh` for automated configuration generation.

## Bootstrap Process

After generating and encrypting configs, use the Ansible bootstrap playbook:

```bash
cd infra/ansible
ansible-playbook bootstrap.yaml
```

The playbook will:

1. Decrypt Talos configs with SOPS
2. Apply configs to all 3 nodes
3. Bootstrap the first control plane
4. Wait for the cluster to form
5. Install Cilium CNI
6. Install Sealed Secrets
7. Install ArgoCD
8. Deploy Rook-Ceph and other infrastructure

## Verification

After bootstrap, verify the cluster:

```bash
# Check nodes
kubectl get nodes -o wide

# Check control plane pods
kubectl get pods -n kube-system

# Check etcd members
talosctl -n 192.168.40.11 etcd members

# Check Ceph status (after Rook-Ceph deployment)
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
```

## Disk Configuration for Rook-Ceph

Talos will automatically detect and make available the 1TB disk (`/dev/sdb`) for Rook-Ceph to use. The `deviceFilter: "^sd[b-z]"` in Rook-Ceph configuration will automatically discover and use this disk.

**Verify disks are available:**

```bash
# Check disks on each node
talosctl -n 192.168.40.11 disks
talosctl -n 192.168.40.13 disks
talosctl -n 192.168.40.203 disks
```

Each node should show:

- `/dev/sda` (256GB) - Talos OS
- `/dev/sdb` (1TB) - Available for Ceph

## Upgrading Talos

When upgrading Talos, upgrade one control plane at a time:

```bash
# Upgrade node-01
talosctl -n 192.168.40.11 upgrade --image factory.talos.dev/installer/<schematic>:v1.9.1

# Wait for node-01 to be ready, then upgrade node-02
talosctl -n 192.168.40.12 upgrade --image factory.talos.dev/installer/<schematic>:v1.9.1

# Wait for node-02 to be ready, then upgrade node-03
talosctl -n 192.168.40.13 upgrade --image factory.talos.dev/installer/<schematic>:v1.9.1
```

## Troubleshooting

**Node won't join cluster:**

```bash
# Check node logs
talosctl -n <node-ip> logs controller-runtime

# Check etcd status
talosctl -n 192.168.40.11 etcd status
```

**Disk not detected by Rook:**

```bash
# Check if disk is visible
talosctl -n <node-ip> disks

# Wipe disk if it has previous partitions
talosctl -n <node-ip> reset --graceful=false --reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL
```

**Network issues:**

```bash
# Check interface name
talosctl -n <node-ip> get links

# Verify routes
talosctl -n <node-ip> get routes
```
