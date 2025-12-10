# Talos Linux

## Current Cluster Configuration

**Hardware Platform:** x86_64 (AMD Ryzen 7 4800H)
**Talos Version:** 1.9.0 (or latest stable)
**Cluster Topology:** 3-node HA control plane (no dedicated workers)

## Talos Image Factory

Custom Talos images are created using the [Talos Image Factory](https://factory.talos.dev/).

**Configuration:**
- **Platform:** Bare Metal x86_64
- **Version:** 1.9.0+
- **System Extensions:**
  - `siderolabs/qemu-guest-agent` (if running virtualized)
  - `siderolabs/iscsi-tools` (for Rook-Ceph RBD volumes)
  - `siderolabs/util-linux-tools` (for disk management utilities)

**Why these extensions:**
- **iscsi-tools**: Required for Rook-Ceph to provision RBD (RADOS Block Device) volumes
- **util-linux-tools**: Provides disk utilities like `lsblk`, `fdisk` for troubleshooting
- **qemu-guest-agent**: Improves VM integration if running on virtualization platform

## Image Creation

Visit [factory.talos.dev](https://factory.talos.dev/) and select:
1. Architecture: `amd64` (x86_64)
2. Platform: `bare-metal` or `metal`
3. Extensions: Add the extensions listed above
4. Generate schematic ID and download installer image

Example schematic URL format:
```
factory.talos.dev/installer/<schematic-id>:v1.9.0
```

Store this URL in your Talos configuration patches for consistent upgrades.

## Configuration Generation

See `/infra/talos/README.md` for detailed instructions on generating Talos configurations for the cluster.

Quick start:
```bash
cd infra/talos
./generate-configs.sh
```

## References

- [Talos Linux Documentation](https://www.talos.dev/latest/)
- [Talos Image Factory](https://factory.talos.dev/)
- [Rook-Ceph Talos Prerequisites](https://rook.io/docs/rook/latest/Getting-Started/Prerequisites/prerequisites/#ceph-prerequisites)