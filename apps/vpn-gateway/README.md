# VPN Gateway with Gluetun

Centralized VPN gateway using Gluetun and Cilium Egress Gateway for transparent VPN routing.

## Architecture

This setup provides a centralized VPN gateway that routes traffic from labeled pods through a VPN tunnel transparently using Cilium's Egress Gateway feature.

```
┌─────────────┐
│  ZNC Pod    │  (vpn-egress: "true")
│  (or any    │
│   other)    │
└──────┬──────┘
       │ Traffic automatically routed
       ↓
┌──────────────────────┐
│  Cilium eBPF         │  (Egress Gateway Policy)
└──────┬───────────────┘
       │
       ↓
┌──────────────────────┐
│  Gluetun VPN Gateway │
│  (PIA WireGuard)     │
└──────┬───────────────┘
       │
       ↓
    Internet (via VPN)
```

## Prerequisites

1. **Label a node** for running the VPN gateway:
   ```bash
   kubectl label node <your-node-name> vpn-gateway-node=true
   ```

2. **Create 1Password secret** for VPN credentials with name `gluetun-pia-vpn` containing:
   - `username`: Your PIA username
   - `password`: Your PIA password

3. **Update Cilium** - Ensure the egress gateway feature is enabled (already updated in `/infra/helm/cilium/values.yaml`)

4. **Configure the server** - Edit `configmap.yaml` and set your preferred PIA server location

## Deployment

### Phase 1: Update Cilium (Required First)

Before deploying the VPN gateway, Cilium must be updated with egress gateway support:

```bash
# Update Cilium configuration (already done in infra/helm/cilium/values.yaml)
kubectl apply -k infra/helm/cilium/

# Or via GitOps - commit and push the Cilium changes
git add infra/helm/cilium/values.yaml
git commit -m "Enable Cilium egress gateway and BPF masquerade"
git push

# Wait for Cilium to restart (this may take a few minutes)
kubectl rollout status -n cilium daemonset/cilium
# Or check your Cilium deployment method
```

### Phase 2: Deploy VPN Gateway

Once Cilium is updated, deploy the VPN gateway:

```bash
# Via GitOps (recommended)
git add apps/vpn-gateway/
git commit -m "Add VPN gateway"
git push

# Or manually
kubectl apply -k apps/vpn-gateway/
```

### Phase 3: Enable Cilium Policies (Optional)

After VPN gateway is running and Cilium CRDs are available:

```bash
# Uncomment the Cilium policies in kustomization.yaml:
# - cilium-egress-gateway.yaml
# - network-policies.yaml

# Then apply
kubectl apply -k apps/vpn-gateway/
```

**Note**: Until Cilium egress gateway is configured, applications can use the HTTP/SOCKS5 proxy directly (see "Usage" section below).

## Usage

To route any application through the VPN, simply add the label to its pod template:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      labels:
        vpn-egress: "true"  # This label enables VPN routing
```

## Verification

### Check VPN Connection

```bash
# Check Gluetun logs
kubectl logs -n vpn-gateway -l app=gluetun -f

# Verify VPN connection is active (should show VPN exit IP)
kubectl exec -n vpn-gateway deploy/gluetun -- wget -qO- https://api.ipify.org
```

### Test VPN Routing

```bash
# From a pod with vpn-egress label (e.g., ZNC)
kubectl exec -n media deploy/znc -- wget -qO- https://api.ipify.org
# Should show VPN IP

# From a pod without the label
kubectl run test --rm -it --image=curlimages/curl -- curl https://api.ipify.org
# Should show your regular IP
```

### Monitor with Hubble

```bash
# Install Hubble CLI
kubectl port-forward -n kube-system svc/hubble-ui 12000:80

# Watch traffic flow
hubble observe --namespace vpn-gateway
hubble observe --namespace media --label vpn-egress=true
```

## Configuration

### Change VPN Server Location

Edit `configmap.yaml`:
```yaml
data:
  server_names: "amsterdam"  # or any other PIA server
```

### Adjust Firewall Rules

Edit the `FIREWALL_OUTBOUND_SUBNETS` in `configmap.yaml` to allow access to your local networks.

### Node Affinity

By default, the deployment prefers to run on `pi-node-1`. Update `deployment.yaml` to change this:
```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - your-preferred-node
```

## Troubleshooting

### VPN Not Connecting

```bash
# Check Gluetun logs
kubectl logs -n vpn-gateway -l app=gluetun --tail=100

# Check secrets are present
kubectl get secret -n vpn-gateway gluetun-credentials
kubectl get secret -n vpn-gateway gluetun-credentials -o jsonpath='{.data.username}' | base64 -d
```

### Traffic Not Routing Through VPN

```bash
# Verify pod has the label
kubectl get pod -n media -l vpn-egress=true --show-labels

# Check Cilium egress gateway status
kubectl get ciliumegressgatewaypolicy -A

# Verify node is labeled
kubectl get nodes -l vpn-gateway-node=true

# Check Cilium agent logs
kubectl logs -n kube-system -l k8s-app=cilium --tail=50 | grep egress
```

### DNS Issues

```bash
# Test DNS resolution from VPN pod
kubectl exec -n vpn-gateway deploy/gluetun -- nslookup google.com

# Check network policies
kubectl get ciliumnetworkpolicy -n vpn-gateway
```

## Cleanup

To remove the VPN gateway:

```bash
kubectl delete -k apps/vpn-gateway/
kubectl label node <node-name> vpn-gateway-node-
```

## Advanced: Using HTTP/SOCKS5 Proxy Directly

If Cilium Egress Gateway is not available or you prefer explicit proxy configuration:

```yaml
env:
  - name: HTTP_PROXY
    value: "http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888"
  - name: HTTPS_PROXY
    value: "http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888"
  - name: NO_PROXY
    value: "localhost,127.0.0.1,.svc,.cluster.local"
```

Or use SOCKS5:
```yaml
# For applications that support SOCKS5
value: "socks5://gluetun-socks5-proxy.vpn-gateway.svc.cluster.local:1080"
```
