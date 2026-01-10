# Envoy Gateway Role

This role installs and verifies Envoy Gateway for Kubernetes Gateway API support.

## Responsibilities

1. **Install Envoy Gateway** - Deploys Envoy Gateway controller via Helm
2. **Install Gateway API CRDs** - Envoy Gateway chart includes Gateway API CRDs
3. **Verify Controller** - Ensures Envoy Gateway controller is ready
4. **Verify CRDs** - Confirms Gateway API CRDs are installed

## Requirements

- `helm` CLI installed
- `kubectl` CLI installed
- Kubeconfig configured
- Envoy Gateway values file at `{{ k8s_infra_dir }}/networking/envoy-gateway/values.yaml`
- Cilium CNI installed (networking must be functional)

## Variables

See `inventory/group_vars/all.yaml` for configuration:

- `k8s_infra_dir` - Directory containing infrastructure manifests
- `kubeconfig` - Path to kubeconfig file
- `default_delay` - Delay between retries
- `enable_detailed_output` - Show detailed status output

## Tags

- `envoy-gateway` - All Envoy Gateway tasks
- `networking` - Networking tasks

## Usage

```bash
# Run Envoy Gateway installation
ansible-playbook playbooks/bootstrap.yaml --tags envoy-gateway
```

## Notes

- Envoy Gateway provides Gateway API implementation (alternative to Cilium Gateway API)
- Installs Gateway API v1 CRDs (Gateway, HTTPRoute, GRPCRoute, etc.)
- Required before ArgoCD if ArgoCD uses HTTPRoute for ingress
- Typically takes 2-3 minutes to fully initialize
- Creates `envoy-gateway-system` namespace
- Creates `envoy` GatewayClass automatically (if `createGatewayClass: true` in values)

## Gateway API CRDs Installed

The Envoy Gateway Helm chart installs these Gateway API CRDs:
- GatewayClass
- Gateway
- HTTPRoute
- GRPCRoute
- TCPRoute
- TLSRoute
- UDPRoute
- ReferenceGrant
- BackendTLSPolicy
