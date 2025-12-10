# Migration Guide: Raspberry Pi Cluster → Mini PC Cluster

## Overview

This guide documents the migration from the existing 4-node Raspberry Pi cluster to a new 3-node x86_64 mini PC cluster with Rook-Ceph distributed storage.

## Cluster Comparison

| Aspect | Old Cluster (Raspberry Pi) | New Cluster (Mini PC) |
|--------|---------------------------|----------------------|
| **Nodes** | 4 nodes (3x 4GB + 1x 8GB) | 3 nodes (16GB each) |
| **Architecture** | ARM64 | x86_64 (AMD Ryzen 7 4800H) |
| **Topology** | 1 control plane + 3 workers | 3 control planes (HA) |
| **Total RAM** | 20GB | 48GB |
| **Total CPU** | ~16 cores (ARM) | 48 cores (24 physical) |
| **Storage** | External NAS (Longhorn) | Distributed Ceph (3x 1TB) |
| **System Disks** | 4x 128GB SD cards | 3x 256GB NVMe |
| **Data Disks** | None (NAS only) | 3x 1TB NVMe (Ceph) |
| **Talos Version** | 1.11.5 | 1.9.0+ |
| **Storage Solution** | Longhorn + NAS | Rook-Ceph (block/fs/object) |

## Key Architectural Changes

### 1. High Availability Control Plane

**Old:** Single control plane node (SPOF)
**New:** 3 control planes with distributed etcd

**Benefits:**
- No single point of failure
- API server load balanced across 3 nodes
- Etcd quorum survives 1 node failure
- Control plane operations continue during node maintenance

### 2. Hyper-Converged Storage

**Old:** External Longhorn storage or NAS
**New:** Rook-Ceph integrated on all nodes

**Benefits:**
- Lower network latency (local storage)
- Block, filesystem, and object storage from one system
- 2-way replication tolerates 1 node failure
- S3-compatible object storage for backups

### 3. Workload Scheduling

**Old:** Dedicated workers for application pods
**New:** All nodes can schedule workloads

**Benefits:**
- Better resource utilization (no idle control plane)
- Simplified node management (uniform configuration)
- More capacity for applications (48GB vs 20GB RAM)

## Migration Steps

### Phase 1: Preparation (Current State)

1. **Backup Current Cluster**
   ```bash
   # Backup etcd
   kubectl get all --all-namespaces -o yaml > backup-all-resources.yaml

   # Export ArgoCD applications
   kubectl get applications -n argocd -o yaml > backup-argocd-apps.yaml

   # Backup persistent data
   # Use VolSync or manual backup to external storage
   ```

2. **Document Current State**
   - List all running applications
   - Note custom configurations
   - Export secrets (store securely)
   - Document DNS records and ingress routes

3. **Update Repository (✅ COMPLETE)**
   - ✅ Reorganized infrastructure by category
   - ✅ Created Rook-Ceph configuration
   - ✅ Updated bootstrap playbook for 3 control planes
   - ✅ Created Talos configuration templates
   - ✅ Updated documentation

### Phase 2: Generate New Cluster Configuration

1. **Create Talos Factory Image**
   - Visit https://factory.talos.dev/
   - Select: x86_64, bare-metal, Talos 1.9.0+
   - Add extensions: iscsi-tools, util-linux-tools
   - Save schematic ID for configuration

2. **Generate Talos Configs**
   ```bash
   cd infra/talos

   # Edit patches/node-*.yaml with correct network interface names
   # (check interface names when booting Talos ISO)

   # Generate and encrypt configs
   ./generate-configs.sh
   ```

3. **Verify Generated Configs**
   - Check encrypted files exist: `controlplane-node-*.enc.yaml`
   - Verify talosconfig encrypted: `config.enc.yaml`
   - Backup unencrypted secrets to secure location

4. **Commit Configuration**
   ```bash
   git add infra/talos/*.enc.yaml
   git commit -m "Add Talos configs for new x86_64 cluster"
   git push
   ```

### Phase 3: Deploy New Cluster

1. **Prepare Hardware**
   - Install Talos on all 3 mini PCs
   - Boot from Talos ISO or PXE
   - Verify network connectivity
   - Verify disk detection (256GB + 1TB per node)

2. **Run Bootstrap Playbook**
   ```bash
   cd infra/ansible

   # Ensure 1Password CLI is authenticated
   op signin

   # Run bootstrap (takes ~45-60 minutes)
   ansible-playbook bootstrap.yaml
   ```

3. **Bootstrap Process**
   The playbook will:
   - ✅ Setup age encryption keys
   - ✅ Deploy Talos configs to all 3 nodes
   - ✅ Bootstrap first control plane
   - ✅ Wait for all nodes to join
   - ✅ Install Cilium CNI
   - ✅ Install Sealed Secrets
   - ✅ Install ArgoCD
   - ✅ Deploy Rook-Ceph operator
   - ✅ Deploy Rook-Ceph cluster
   - ✅ Wait for Ceph to be healthy

4. **Verify Cluster Health**
   ```bash
   # Check nodes
   kubectl get nodes -o wide
   # Should show 3 nodes, all control-plane, all Ready

   # Check etcd
   talosctl -n 192.168.178.201 etcd members
   # Should show 3 members

   # Check Ceph
   kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
   # Should show HEALTH_OK (may take 10-15 min)

   # Check storage classes
   kubectl get storageclass
   # Should show ceph-block (default), ceph-filesystem, ceph-bucket
   ```

### Phase 4: Migrate Applications

1. **Sync ArgoCD Applications**
   ```bash
   # ArgoCD should automatically sync all apps
   kubectl get applications -n argocd

   # Force sync if needed
   argocd app sync --all
   ```

2. **Migrate Persistent Data**

   **Option A: Fresh Start**
   - Reconfigure applications to use new Ceph storage
   - Re-import data from backups

   **Option B: Data Migration**
   - Use VolSync to replicate volumes
   - Use rsync or rclone for filesystem data
   - Use database dump/restore for databases

3. **Update DNS Records**
   - Point ingress domains to new gateway IP (192.168.178.210)
   - Update Cloudflare DNS if using cloudflare-ingress
   - Verify external access works

4. **Verify Applications**
   - Check all pods are running: `kubectl get pods -A`
   - Verify application functionality
   - Test persistent storage
   - Verify backups are working

### Phase 5: Decommission Old Cluster

1. **Parallel Operation Period**
   - Run both clusters for 1-2 weeks
   - Monitor new cluster for stability
   - Keep old cluster as fallback

2. **Final Cutover**
   - Stop applications on old cluster
   - Final data sync if needed
   - Update all DNS to new cluster
   - Monitor for issues

3. **Decommission**
   - Power down old cluster
   - Wipe Raspberry Pi SD cards
   - Repurpose hardware or store as spare

## Storage Migration Details

### Longhorn → Rook-Ceph

**Block Storage (RWO):**
```yaml
# Old
storageClassName: longhorn

# New
storageClassName: ceph-block  # This is now the default
```

**Shared Filesystem (RWX):**
```yaml
# Old
storageClassName: longhorn  # Or NFS

# New
storageClassName: ceph-filesystem  # Native CephFS
```

**Object Storage (S3):**
```yaml
# Old
# External S3 or MinIO

# New
storageClassName: ceph-bucket  # S3-compatible via Ceph RGW
```

### Data Migration Options

1. **VolSync Replication**
   - Configure VolSync to replicate from old to new cluster
   - Supports incremental sync
   - Best for large volumes

2. **Manual Backup/Restore**
   - Backup from old cluster to NAS
   - Restore to new cluster
   - Good for small volumes

3. **Application-Level Migration**
   - Database dump/restore (PostgreSQL, MySQL)
   - File-level sync (rsync, rclone)
   - Application-specific tools

## Rollback Plan

If critical issues occur during migration:

1. **Immediate Rollback**
   - Update DNS back to old cluster
   - Power on old cluster nodes
   - Verify old cluster is operational

2. **Investigation**
   - Diagnose new cluster issues
   - Check logs: `kubectl logs` and `talosctl logs`
   - Review Ceph status
   - Check resource utilization

3. **Fix and Retry**
   - Address identified issues
   - Test fix on new cluster
   - Plan second cutover attempt

## Post-Migration Optimization

### 1. Resource Tuning

Monitor cluster for 1-2 weeks and adjust:
- Ceph OSD resource limits based on actual usage
- Application resource requests/limits
- Storage class parameters (replication, compression)

### 2. Backup Strategy

Configure backups:
- VolSync for volume replication to NAS
- Velero for cluster-level backups
- Application-specific backups (database dumps)
- Ceph RGW (S3) for backup storage

### 3. Monitoring Setup

Ensure monitoring is working:
- Prometheus scraping Ceph metrics
- Grafana dashboards for Ceph
- Alerting for storage capacity
- Node resource monitoring

### 4. Documentation Updates

Document:
- Any custom configurations
- Lessons learned during migration
- Updated runbooks and procedures
- New cluster architecture diagrams

## Troubleshooting

### Talos Bootstrap Issues

**Nodes not joining cluster:**
```bash
# Check node logs
talosctl -n <node-ip> logs controller-runtime

# Check network connectivity
talosctl -n <node-ip> get routes
talosctl -n <node-ip> get addresses

# Verify etcd
talosctl -n 192.168.178.201 etcd status
```

**Network interface not found:**
- Boot Talos ISO and check: `talosctl -n <node-ip> get links`
- Update `patches/node-*.yaml` with correct interface name

### Ceph Issues

**OSDs not starting:**
```bash
# Check disk is visible and empty
talosctl -n <node-ip> disks

# Check OSD logs
kubectl -n rook-ceph logs -l app=rook-ceph-osd

# Wipe disk if needed
talosctl -n <node-ip> reset --graceful=false --reboot
```

**Ceph not HEALTH_OK:**
```bash
# Check Ceph status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph health detail

# Check OSD tree
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree
```

### Application Issues

**PVCs stuck in Pending:**
```bash
# Check PVC events
kubectl describe pvc <pvc-name>

# Check storage class
kubectl get storageclass

# Check Ceph provisioner logs
kubectl -n rook-ceph logs -l app=csi-rbdplugin
```

## Timeline Estimate

- **Phase 1 (Prep):** 1-2 days
- **Phase 2 (Config):** 2-4 hours
- **Phase 3 (Deploy):** 1-2 hours (mostly automated)
- **Phase 4 (Migrate):** 1-7 days (depends on data volume)
- **Phase 5 (Decommission):** 1-2 weeks (parallel operation)

**Total:** 2-4 weeks for complete migration with testing

## Success Criteria

Migration is complete when:
- ✅ All 3 nodes are Ready and control-plane role
- ✅ Ceph cluster shows HEALTH_OK
- ✅ All ArgoCD applications are Synced and Healthy
- ✅ All application pods are Running
- ✅ Persistent data is accessible and correct
- ✅ External access via ingress works
- ✅ Backups are configured and tested
- ✅ Monitoring shows healthy metrics
- ✅ Old cluster can be safely powered off

## Resources

- Main README: `/README.md`
- Talos Config Guide: `/infra/talos/README.md`
- Rook-Ceph Guide: `/infra/k8s/storage/rook-ceph-cluster/README.md`
- Bootstrap Playbook: `/infra/ansible/bootstrap.yaml`
- Talos Documentation: https://www.talos.dev/
- Rook Documentation: https://rook.io/docs/rook/latest/
- Ceph Documentation: https://docs.ceph.com/
