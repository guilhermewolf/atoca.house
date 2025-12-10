# Talos Role

This role handles Talos Linux deployment and Kubernetes cluster bootstrap.

## Responsibilities

1. **Age Encryption Setup** - Retrieves and configures Age key for SOPS decryption
2. **Talos Deployment** - Decrypts and applies Talos configurations to all nodes
3. **Cluster Bootstrap** - Bootstraps the first control plane and generates kubeconfig
4. **Verification** - Waits for all nodes to be Ready
5. **Cleanup** - Removes decrypted configuration files

## Requirements

- `talosctl` CLI installed
- `kubectl` CLI installed
- `sops` CLI installed
- `op` (1Password CLI) installed and authenticated
- Age key stored in 1Password at `{{ op_age_key_path }}`
- Encrypted Talos configurations in `{{ talos_dir }}/`

## Variables

See `inventory/group_vars/all.yaml` for configuration:

- `control_plane_nodes` - List of nodes with name and IP
- `bootstrap_node_ip` - IP of first control plane node
- `talos_dir` - Directory containing Talos configurations
- `age_config_dir` - Directory for Age encryption keys
- `kubeconfig` - Path to generated kubeconfig file

## Tags

- `talos` - All Talos tasks
- `age` - Age encryption setup only
- `encryption` - Encryption-related tasks
- `deploy` - Talos deployment only
- `bootstrap` - Bootstrap cluster only
- `cleanup` - Cleanup tasks only

## Usage

```bash
# Run all tasks
ansible-playbook playbooks/bootstrap.yaml --tags talos

# Setup Age only
ansible-playbook playbooks/bootstrap.yaml --tags age

# Deploy Talos only
ansible-playbook playbooks/bootstrap.yaml --tags deploy

# Bootstrap cluster only
ansible-playbook playbooks/bootstrap.yaml --tags bootstrap
```

## Notes

- All 3 nodes are control planes (no dedicated worker nodes)
- Talos configurations are encrypted with SOPS and Age
- Decrypted files are automatically removed after deployment
- Kubeconfig is generated at `{{ kubeconfig }}`
