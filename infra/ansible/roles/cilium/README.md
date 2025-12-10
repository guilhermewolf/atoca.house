# Cilium Role

This role installs and verifies Cilium CNI (Container Network Interface) for Kubernetes networking.

## Responsibilities

1. **Apply Cilium** - Deploys Cilium using Helm via kustomize
2. **Verify Cilium Agents** - Ensures Cilium agents are running on all nodes
3. **Verify Cilium Operator** - Ensures Cilium operator is ready
4. **Verify Nodes** - Confirms all nodes are Ready after CNI installation

## Requirements

- `kubectl` CLI installed
- Kubeconfig configured
- Cilium Helm chart configured in `{{ k8s_infra_dir }}/networking/cilium`
- Kubernetes cluster running (control plane ready)

## Variables

See `inventory/group_vars/all.yaml` for configuration:

- `k8s_infra_dir` - Directory containing infrastructure manifests
- `kubeconfig` - Path to kubeconfig file
- `cilium_timeout` - Timeout for Cilium readiness (default: 300s)
- `default_retries` - Number of retries for operations
- `default_delay` - Delay between retries

## Tags

- `cilium` - All Cilium tasks
- `cni` - CNI-related tasks
- `networking` - Networking tasks

## Usage

```bash
# Run Cilium installation
ansible-playbook playbooks/bootstrap.yaml --tags cilium
```

## Notes

- Cilium provides eBPF-based networking and security
- Supports Kubernetes Gateway API
- Required for pod-to-pod communication
- Must be installed before any applications
- Typically takes 2-5 minutes to fully initialize
