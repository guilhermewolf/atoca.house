# Volume Snapshots Role

This role installs the Kubernetes Volume Snapshot CRDs and Snapshot Controller, which are required by CSI drivers like Rook-Ceph to support volume snapshots.

## What it installs

1. **Volume Snapshot CRDs** (Custom Resource Definitions):
   - `VolumeSnapshotClass` - Defines snapshot parameters
   - `VolumeSnapshot` - User-facing snapshot resource
   - `VolumeSnapshotContent` - Actual snapshot binding

2. **Snapshot Controller**:
   - Manages the lifecycle of volume snapshots
   - Handles snapshot creation and deletion
   - Runs in the `kube-system` namespace

## Why this is needed

Rook-Ceph CSI drivers require these CRDs to provide snapshot functionality. Without them, you'll see errors like:

```
The Kubernetes API could not find snapshot.storage.k8s.io/VolumeSnapshotClass for requested resource
```

## Version

The role installs the CRDs from the [kubernetes-csi/external-snapshotter](https://github.com/kubernetes-csi/external-snapshotter) project.

Default version: `v8.2.0` (configured in `defaults/main.yaml`)

## Usage

This role is automatically run as part of the bootstrap playbook before the `rook_ceph` role.

To run it manually:

```bash
ansible-playbook playbooks/bootstrap.yaml --tags snapshots
```

## Verification

After installation, verify the CRDs are present:

```bash
kubectl get crd | grep snapshot
```

Expected output:
```
volumesnapshotclasses.snapshot.storage.k8s.io
volumesnapshotcontents.snapshot.storage.k8s.io
volumesnapshots.snapshot.storage.k8s.io
```

Check the snapshot controller is running:

```bash
kubectl get deployment snapshot-controller -n kube-system
```
