# Sealed Secrets Role

This role installs and verifies the Sealed Secrets controller for secure secret management in Git.

## Responsibilities

1. **Apply Sealed Secrets** - Deploys Sealed Secrets controller
2. **Verify Controller** - Ensures controller is available
3. **Display Status** - Shows controller pod status

## Requirements

- `kubectl` CLI installed
- Kubeconfig configured
- Sealed Secrets Helm chart configured in `{{ k8s_infra_dir }}/security/sealed-secrets`
- Kubernetes cluster with CNI installed

## Variables

See `inventory/group_vars/all.yaml` for configuration:

- `k8s_infra_dir` - Directory containing infrastructure manifests
- `kubeconfig` - Path to kubeconfig file
- `sealed_secrets_namespace` - Namespace for controller (default: sealed-secrets)
- `default_retries` - Number of retries for operations
- `default_delay` - Delay between retries

## Tags

- `sealed-secrets` - All Sealed Secrets tasks
- `security` - Security-related tasks

## Usage

```bash
# Run Sealed Secrets installation
ansible-playbook playbooks/bootstrap.yaml --tags sealed-secrets
```

## Notes

- Sealed Secrets encrypts Kubernetes secrets for safe storage in Git
- Uses asymmetric encryption (public key to seal, private key in cluster to unseal)
- Required before deploying applications with secrets
- Controller must be running to unseal SealedSecret resources
- Use `kubeseal` CLI to create SealedSecrets
