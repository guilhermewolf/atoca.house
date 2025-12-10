# Cluster Deployment Checklist

Quick reference checklist for deploying the new 3-node Kubernetes cluster.

## Pre-Deployment

### Hardware Preparation
- [ ] 3x Mini PCs with AMD Ryzen 7 4800H ready
- [ ] 256GB NVMe installed in each (system disk)
- [ ] 1TB NVMe installed in each (data disk)
- [ ] All nodes connected to 192.168.178.0/24 network
- [ ] Network switch configured (if using managed switch)
- [ ] Static IP addresses reserved in DHCP:
  - [ ] 192.168.178.201 (node-01)
  - [ ] 192.168.178.202 (node-02)
  - [ ] 192.168.178.203 (node-03)
  - [ ] 192.168.178.210 (gateway LoadBalancer)

### Software Prerequisites
- [ ] 1Password CLI installed (`brew install --cask 1password-cli`)
- [ ] talosctl installed (`brew install talosctl`)
- [ ] kubectl installed (`brew install kubectl`)
- [ ] ansible installed (`brew install ansible`)
- [ ] sops installed (`brew install sops`)
- [ ] yq installed (`brew install yq`)
- [ ] 1Password authenticated (`op signin`)

### Configuration Preparation
- [ ] Age encryption key accessible in 1Password
- [ ] ArgoCD Redis secret stored in 1Password
- [ ] GitHub repository cloned locally
- [ ] Working directory: `/path/to/atoca.house`

## Talos Image Creation

- [ ] Visit https://factory.talos.dev/
- [ ] Select architecture: `amd64`
- [ ] Select platform: `bare-metal` or `metal`
- [ ] Select Talos version: `1.9.0` or latest stable
- [ ] Add extensions:
  - [ ] `siderolabs/iscsi-tools`
  - [ ] `siderolabs/util-linux-tools`
  - [ ] `siderolabs/qemu-guest-agent` (if using VMs)
- [ ] Copy schematic ID: `____________________________`
- [ ] Download ISO image
- [ ] Create bootable USB drives (3x) or configure PXE

## Configuration Generation

- [ ] Check interface names on all nodes (boot Talos ISO first):
  ```bash
  talosctl -n <node-temp-ip> get links
  # Note the primary interface name (e.g., eth0, enp0s3, etc.)
  ```
- [ ] Update `infra/talos/patches/node-*.yaml` if interface is not `eth0`
- [ ] Update factory schematic ID in `infra/talos/patches/controlplane-common.yaml`
- [ ] Generate configurations:
  ```bash
  cd infra/talos
  ./generate-configs.sh
  ```
- [ ] Verify encrypted configs created:
  - [ ] `controlplane-node-01.enc.yaml`
  - [ ] `controlplane-node-02.enc.yaml`
  - [ ] `controlplane-node-03.enc.yaml`
  - [ ] `config.enc.yaml`
- [ ] Commit configs to Git:
  ```bash
  git add infra/talos/*.enc.yaml
  git commit -m "Add Talos configs for new x86_64 cluster"
  git push
  ```

## Hardware Deployment

### Node 01 (192.168.178.201)
- [ ] Boot from Talos USB/ISO
- [ ] Verify disks detected:
  - [ ] `/dev/sda` (256GB) - system
  - [ ] `/dev/sdb` (1TB) - data
- [ ] Note interface name: `__________`
- [ ] Node accessible via network

### Node 02 (192.168.178.202)
- [ ] Boot from Talos USB/ISO
- [ ] Verify disks detected:
  - [ ] `/dev/sda` (256GB) - system
  - [ ] `/dev/sdb` (1TB) - data
- [ ] Note interface name: `__________`
- [ ] Node accessible via network

### Node 03 (192.168.178.203)
- [ ] Boot from Talos USB/ISO
- [ ] Verify disks detected:
  - [ ] `/dev/sda` (256GB) - system
  - [ ] `/dev/sdb` (1TB) - data
- [ ] Note interface name: `__________`
- [ ] Node accessible via network

## Bootstrap Execution

- [ ] All nodes booted and accessible
- [ ] 1Password authenticated: `eval $(op signin)`
- [ ] Run bootstrap playbook:
  ```bash
  cd infra/ansible
  ansible-playbook bootstrap.yaml
  ```
- [ ] Bootstrap started (timestamp: `__________`)
- [ ] Monitor progress (estimated 45-60 minutes)

### Bootstrap Phases (Auto-checked by playbook)
1. [ ] Age encryption setup ✓
2. [ ] Talos configs applied to all nodes ✓
3. [ ] First control plane bootstrapped ✓
4. [ ] All nodes joined cluster ✓
5. [ ] Cilium CNI installed ✓
6. [ ] Sealed Secrets installed ✓
7. [ ] ArgoCD installed ✓
8. [ ] Rook-Ceph operator deployed ✓
9. [ ] Rook-Ceph cluster deployed ✓
10. [ ] Infrastructure healthy ✓

- [ ] Bootstrap completed (timestamp: `__________`)
- [ ] Bootstrap duration: `__________ minutes`

## Post-Deployment Verification

### Cluster Health
- [ ] All nodes Ready:
  ```bash
  kubectl get nodes -o wide
  # Should show 3 nodes, all Ready, all control-plane
  ```
- [ ] Pods running:
  ```bash
  kubectl get pods -A
  # Should show no CrashLoopBackOff or Error states
  ```
- [ ] etcd healthy:
  ```bash
  talosctl -n 192.168.178.201 etcd members
  # Should show 3 members
  ```

### Storage
- [ ] Ceph cluster healthy (may take 10-15 min):
  ```bash
  kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
  # Should show HEALTH_OK
  ```
- [ ] Storage classes available:
  ```bash
  kubectl get storageclass
  # Should show: ceph-block (default), ceph-filesystem, ceph-bucket
  ```
- [ ] OSDs deployed:
  ```bash
  kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree
  # Should show 3 OSDs (one per node)
  ```

### ArgoCD
- [ ] ArgoCD accessible:
  ```bash
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  # Open: https://localhost:8080
  ```
- [ ] Admin password retrieved:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d
  ```
- [ ] All applications syncing:
  ```bash
  kubectl get applications -n argocd
  # Check for Synced and Healthy status
  ```

### Networking
- [ ] Gateway LoadBalancer IP assigned: `192.168.178.210`
- [ ] DNS records updated (if applicable)
- [ ] Ingress accessible externally
- [ ] Test application: `curl http://whoami.atoca.house` (or similar)

## Post-Deployment Tasks

### Immediate (Day 1)
- [ ] Change ArgoCD admin password
- [ ] Document any issues encountered
- [ ] Take Ceph cluster snapshot/baseline metrics
- [ ] Verify backup systems configured

### Short-term (Week 1)
- [ ] Monitor Ceph cluster health daily
- [ ] Check resource utilization (RAM, CPU, disk)
- [ ] Verify all applications functioning
- [ ] Test storage failover (simulate node failure)
- [ ] Update documentation with actual deployment notes

### Medium-term (Week 2-4)
- [ ] Run parallel with old cluster (if migrating)
- [ ] Migrate application data
- [ ] Update all DNS records
- [ ] Performance tuning based on observed usage
- [ ] Schedule old cluster decommission

### Long-term (Month 1+)
- [ ] Delete old cluster configs from `infra/talos/old-cluster-backup/`
- [ ] Archive old cluster documentation
- [ ] Review and optimize Ceph configuration
- [ ] Plan backup and disaster recovery testing
- [ ] Update README badges/metrics

## Troubleshooting Reference

### Common Issues

**Nodes not joining:**
```bash
talosctl -n <node-ip> logs controller-runtime
talosctl -n 192.168.178.201 etcd status
```

**Ceph not healthy:**
```bash
kubectl -n rook-ceph logs -l app=rook-ceph-operator
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph health detail
```

**ArgoCD apps not syncing:**
```bash
kubectl describe application <app-name> -n argocd
argocd app sync <app-name> --force
```

**Interface name wrong:**
```bash
# Check actual interface name
talosctl -n <node-ip> get links
# Update infra/talos/patches/node-*.yaml
# Regenerate configs: cd infra/talos && ./generate-configs.sh
```

## Rollback Plan

If critical issues occur:

1. [ ] Document the issue
2. [ ] Capture logs:
   ```bash
   kubectl get events --all-namespaces > events.log
   kubectl logs -n kube-system -l k8s-app=cilium > cilium.log
   talosctl -n 192.168.178.201 logs > talos.log
   ```
3. [ ] Restore DNS to old cluster (if migrating)
4. [ ] Power on old cluster
5. [ ] Investigate new cluster issue
6. [ ] Plan remediation
7. [ ] Schedule second deployment attempt

## Success Criteria

Deployment is successful when:
- [x] All checklist items above are complete
- [x] Cluster has been running stable for 24 hours
- [x] All applications are functioning
- [x] Storage is performing as expected
- [x] Backups are operational
- [x] No critical errors in logs
- [x] Team/users can access services

## Notes

Use this space for deployment-specific notes:

```
Date: _______________
Deployment lead: _______________

Issues encountered:
-
-

Solutions applied:
-
-

Performance observations:
-
-

Additional configuration:
-
-
```

## Resources

- [Installation Guide](/docs/install.md)
- [Talos Configuration Guide](/infra/talos/README.md)
- [Rook-Ceph Guide](/infra/k8s/storage/rook-ceph-cluster/README.md)
- [Migration Guide](/docs/migration-to-new-cluster.md)
- [Bootstrap Playbook](/infra/ansible/bootstrap.yaml)
