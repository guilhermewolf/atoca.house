# ArgoCD Role

This role installs and configures ArgoCD for GitOps continuous deployment.

## Responsibilities

1. **Setup Secrets** - Retrieves and creates ArgoCD Redis secret from 1Password
2. **Install ArgoCD** - Deploys ArgoCD components via Helm:
   - Server (Deployment)
   - Repo Server (Deployment)
   - Application Controller (StatefulSet)
   - ApplicationSet Controller (Deployment)
   - Notifications Controller (Deployment)
   - Redis (Deployment)
3. **Verify Components** - Waits for all deployments and statefulsets to be ready
4. **Apply Applications** - Deploys ArgoCD parent apps and projects (root app-of-apps)
5. **Verify Infrastructure** - Ensures critical infrastructure apps are synced and healthy

## Requirements

- `kubectl` CLI installed
- `helm` CLI installed
- `op` (1Password CLI) installed and authenticated
- Kubeconfig configured
- ArgoCD values file at `{{ argocd_dir }}/install/values.yaml`
- ArgoCD Redis secret in 1Password at `{{ op_argocd_redis_id }}`
- Sealed Secrets controller running (for secret management)
- Envoy Gateway installed (provides Gateway API CRDs for HTTPRoute)

## Variables

See `inventory/group_vars/all.yaml` for configuration:

- `argocd_dir` - Directory containing ArgoCD manifests
- `argocd_namespace` - Namespace for ArgoCD (default: argocd)
- `kubeconfig` - Path to kubeconfig file
- `op_argocd_redis_id` - 1Password path to Redis secret
- `argocd_timeout` - Timeout for ArgoCD readiness (default: 300s)
- `default_retries` - Number of retries for operations
- `default_delay` - Delay between retries

## Tags

- `argocd` - All ArgoCD tasks
- `secrets` - Secret setup only
- `install` - Installation only
- `applications` - Apply applications only
- `verify` - Verification only

## Usage

```bash
# Run full ArgoCD installation
ansible-playbook playbooks/bootstrap.yaml --tags argocd

# Setup secrets only
ansible-playbook playbooks/bootstrap.yaml --tags argocd,secrets

# Apply applications only
ansible-playbook playbooks/bootstrap.yaml --tags argocd,applications
```

## Notes

- ArgoCD enables GitOps - all infrastructure and apps managed via Git
- Root app-of-apps pattern: single root app discovers all category parent apps
- Parent apps automatically discover and deploy child applications
- After ArgoCD is running, all changes should be made via Git commits
- Access ArgoCD UI: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
- Get admin password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
