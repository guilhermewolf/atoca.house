# Rook-Ceph Storage Cluster

Distributed storage cluster using Rook-Ceph for block, filesystem, and object storage.

## Architecture

**3-Node Cluster:**
- All nodes are control planes with storage
- Each node contributes 1TB disk
- 2-way replication (can tolerate 1 node failure)
- Total usable storage: ~1.5TB (3TB raw / 2 replicas)

## Storage Classes

### 1. Block Storage (RWO) - `ceph-block` (default)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ceph-block
  resources:
    requests:
      storage: 10Gi
```

**Use for:** Databases, stateful apps, single-pod storage

### 2. Shared Filesystem (RWX) - `ceph-filesystem`
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ceph-filesystem
  resources:
    requests:
      storage: 100Gi
```

**Use for:** Media libraries, shared configs, multi-pod access

### 3. Object Storage (S3) - `ceph-bucket`
```yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: my-bucket
spec:
  generateBucketName: my-app-bucket
  storageClassName: ceph-bucket
```

**Use for:** Backups, media storage, S3-compatible apps

## Resource Usage

**Per Node (~16GB RAM):**
- MON (Monitor): ~1-2GB
- OSD (Storage): ~2-4GB
- MGR (Manager): ~512MB-1GB
- MDS (if using CephFS): ~2-4GB

**Total Cluster:**
- ~11-15GB RAM for Ceph (leaves ~17GB for apps)
- ~4-6 CPU cores reserved

## Talos Configuration

You **must** configure Talos to use the 1TB disk:

```yaml
# In each controlplane config
machine:
  kubelet:
    extraMounts:
      - destination: /var/lib/rook
        type: bind
        source: /var/lib/rook
        options:
          - bind
          - rshared
          - rw

  # Optional: Pre-format and mount 1TB disk
  disks:
    - device: /dev/sdb  # Adjust to your disk name
      partitions:
        - mountpoint: /var/mnt/storage
```

**Check disk names on Talos:**
```bash
talosctl disks -n 192.168.178.201
talosctl disks -n 192.168.178.202
talosctl disks -n 192.168.178.203
```

Update `deviceFilter` in values.yaml to match your disk pattern.

## Deployment Order

1. **Operator first** (rook-ceph-operator)
2. **Wait 2-3 minutes** for operator to be ready
3. **Cluster second** (rook-ceph-cluster)
4. **Wait 10-15 minutes** for cluster bootstrap

## Accessing Ceph Dashboard

**Get admin password:**
```bash
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo
```

**Port forward (temporary):**
```bash
kubectl port-forward -n rook-ceph svc/rook-ceph-mgr-dashboard 7000:7000
```

Open: http://localhost:7000
Username: `admin`

**Or access via Ingress:**
https://ceph.atoca.house (after setting up HTTPRoute)

## Ceph Toolbox

For advanced operations, use the toolbox pod:

```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash

# Inside toolbox:
ceph status
ceph osd status
ceph df
ceph health detail
```

## Monitoring

Ceph metrics are automatically exported to Prometheus if monitoring is enabled.

**Key metrics:**
- `ceph_cluster_total_bytes` - Total storage
- `ceph_cluster_total_used_bytes` - Used storage
- `ceph_health_status` - Cluster health (0=HEALTH_OK)
- `ceph_osd_up` - OSD availability

## Object Storage (S3) Access

**Get S3 credentials:**
```bash
kubectl -n rook-ceph get secret rook-ceph-object-user-ceph-objectstore-my-user \
  -o jsonpath='{.data.AccessKey}' | base64 --decode
kubectl -n rook-ceph get secret rook-ceph-object-user-ceph-objectstore-my-user \
  -o jsonpath='{.data.SecretKey}' | base64 --decode
```

**S3 endpoint:**
```
http://rook-ceph-rgw-ceph-objectstore.rook-ceph.svc.cluster.local
```

**Configure s3cmd:**
```bash
s3cmd --configure
# Host: rook-ceph-rgw-ceph-objectstore.rook-ceph.svc.cluster.local
# Access Key: <from above>
# Secret Key: <from above>
```

## Troubleshooting

**Check cluster health:**
```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
```

**Check OSD status:**
```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree
```

**View logs:**
```bash
kubectl -n rook-ceph logs -l app=rook-ceph-operator
kubectl -n rook-ceph logs -l app=rook-ceph-mon
kubectl -n rook-ceph logs -l app=rook-ceph-osd
```

**Common issues:**
- **OSDs not coming up:** Check disk is empty and not partitioned
- **Slow performance:** Check network latency between nodes
- **Out of space:** Ceph reserves 15% of disk space by default

## Disaster Recovery

**Backup PVC:**
```bash
# Create VolumeSnapshot
kubectl create -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
spec:
  volumeSnapshotClassName: ceph-block
  source:
    persistentVolumeClaimName: my-pvc
EOF
```

**External backup with VolSync:**
Ceph RBD volumes work with VolSync for replication to NAS/S3.

## References

- [Rook Documentation](https://rook.io/docs/rook/latest/)
- [Ceph Documentation](https://docs.ceph.com/)
- [Rook Helm Charts](https://github.com/rook/rook/tree/master/deploy/charts)
