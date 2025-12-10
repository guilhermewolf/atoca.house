# 1Password Role

This role retrieves secrets from 1Password, creates Kubernetes secrets, and seals them with Sealed Secrets for safe storage in Git.

## Responsibilities

1. **Retrieve Secrets** - Fetches 1Password token and credentials from 1Password
2. **Create Secrets** - Generates Kubernetes secret manifests (unsealed)
3. **Seal Secrets** - Encrypts secrets using kubeseal
4. **Cleanup** - Removes all temporary files containing sensitive data

## Requirements

- `kubectl` CLI installed
- `kubeseal` CLI installed
- `op` (1Password CLI) installed and authenticated
- Kubeconfig configured
- Sealed Secrets controller running in cluster
- 1Password secrets exist at configured paths

## Variables

See `inventory/group_vars/all.yaml` for configuration:

- `k8s_infra_dir` - Directory containing infrastructure manifests
- `kubeconfig` - Path to kubeconfig file
- `onepassword_namespace` - Namespace for 1Password operator (default: one-password)
- `sealed_secrets_namespace` - Namespace for Sealed Secrets controller
- `op_token_id` - 1Password path to operator token
- `op_credential_file_id` - 1Password path to credentials file

## Output

Sealed secrets are written to:
- `{{ k8s_infra_dir }}/security/one-password/onepassword-token.yaml`
- `{{ k8s_infra_dir }}/security/one-password/op-credentials.yaml`

## Tags

- `onepassword` - All 1Password tasks
- `retrieve` - Retrieve secrets only
- `create` - Create Kubernetes secrets only
- `seal` - Seal secrets only
- `cleanup` - Cleanup only

## Usage

```bash
# Run full workflow (via dedicated playbook)
ansible-playbook playbooks/seal-secrets.yaml

# Retrieve secrets only
ansible-playbook playbooks/seal-secrets.yaml --tags retrieve

# Seal existing secrets
ansible-playbook playbooks/seal-secrets.yaml --tags seal
```

## Important Notes

- **Path Fixed**: Original playbook had wrong path `helm/one-password` - now correctly uses `infra/k8s/security/one-password`
- **No Git Automation**: Unlike original, this does NOT automatically commit to Git (anti-pattern)
- **Manual Git Workflow**: You must manually review, commit, and push sealed secrets
- **Idempotent**: Safe to run multiple times - kubeseal overwrites existing files
- **Security**: All temporary files are removed after sealing
- **One-Time Setup**: Typically run once, then only when rotating secrets

## Differences from Original

Original `one-password.yaml` issues fixed:
- ❌ Wrong path: `helm/one-password` → ✅ `infra/k8s/security/one-password`
- ❌ Typos: "onepasword", "credentail", "Maniputate" → ✅ Fixed
- ❌ Automatic git commit → ✅ Manual review required
- ❌ Single large playbook → ✅ Modular role with subtasks
