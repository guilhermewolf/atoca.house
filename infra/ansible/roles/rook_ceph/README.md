# Rook-Ceph Role

This role verifies that Rook-Ceph distributed storage is deployed and healthy.

## Responsibilities

1. **Verify Operator** - Ensures Rook-Ceph operator is synced, healthy, and running
2. **Verify Cluster** - Ensures Rook-Ceph cluster is synced and healthy
3. **Verify Ceph Health** - Checks Ceph cluster health status (HEALTH_OK)
4. **Display Status** - Shows Ceph status and storage classes

## Requirements

- `kubectl` CLI installed
- Kubeconfig configured
- ArgoCD managing Rook-Ceph applications
- Rook-Ceph operator and cluster deployed
- `rook-ceph-tools` pod running (for health checks)

## Variables

See `inventory/group_vars/all.yaml` for configuration:

- `kubeconfig` - Path to kubeconfig file
- `rook_ceph_namespace` - Namespace for Rook-Ceph (default: rook-ceph)
- `argocd_namespace` - Namespace for ArgoCD (default: argocd)
- `enable_ceph_verification` - Enable Ceph health checks (default: true)
- `enable_detailed_output` - Show detailed status (default: true)
- `ceph_timeout` - Timeout for Ceph health (default: 1800s / 30 minutes)
- `default_retries` - Number of retries for operations
- `default_delay` - Delay between retries

## Tags

- `rook-ceph` - All Rook-Ceph tasks
- `storage` - Storage-related tasks
- `verify` - Verification tasks

## Usage

```bash
# Run Rook-Ceph verification
ansible-playbook playbooks/bootstrap.yaml --tags rook-ceph

# Skip Ceph health verification
ansible-playbook playbooks/bootstrap.yaml --tags rook-ceph -e "enable_ceph_verification=false"
```

## Important Notes

- **Long Wait Time**: Ceph cluster can take 10-30 minutes to reach HEALTH_OK
- **Multiple Retries**: Uses 60 retries with 30s delay (up to 30 minutes)
- **Non-Blocking**: Ceph health check won't fail bootstrap if not HEALTH_OK yet
- **Manual Verification**: After bootstrap, manually check: `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status`

## Storage Classes

After successful deployment, these storage classes are available:
- `ceph-block` (default) - RWO block storage for databases
- `ceph-filesystem` - RWX shared filesystem for media
- `ceph-bucket` - S3-compatible object storage

## Troubleshooting

If Ceph is not HEALTH_OK:
1. Check OSD pods: `kubectl get pods -n rook-ceph -l app=rook-ceph-osd`
2. Check Ceph status: `kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status`
3. Check events: `kubectl get events -n rook-ceph --sort-by='.lastTimestamp'`
4. Wait 10-15 minutes - Ceph needs time to stabilize
