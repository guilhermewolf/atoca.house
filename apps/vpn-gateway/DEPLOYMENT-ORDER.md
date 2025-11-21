# Deployment Order for VPN Gateway

## Issues Fixed

1. ✅ Invalid label `io.cilium.no-track-port: "1080,8888"` - removed (commas not allowed in labels)
2. ✅ `CiliumEgressGatewayPolicy` API - changed `egressGroups` to `egressGateway`
3. ✅ ExternalSecret API version - updated to `v1` (you already did this)
4. ✅ Missing Cilium masquerade settings - added to `infra/helm/cilium/values.yaml`

## Deployment Steps (IN THIS ORDER!)

### Step 1: Update Cilium First ⚠️

Cilium MUST be updated before deploying VPN gateway:

```bash
# Commit Cilium configuration changes
cd /home/jwolf@sector-orange.com/Documents/atoca.house
git add infra/helm/cilium/values.yaml
git commit -m "Enable Cilium egress gateway with BPF masquerade"
git push

# Cilium will restart - wait for it
# Check how your cluster manages Cilium (Helm, ArgoCD, etc.)
# Example checks:
kubectl get helmrelease -n kube-system cilium
kubectl get application -n argocd cilium
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get pods -n cilium -l k8s-app=cilium
```

### Step 2: Label a Node

Label the node where VPN gateway will run:

```bash
# List nodes
kubectl get nodes

# Label your chosen node
kubectl label node <node-name> vpn-gateway-node=true

# Verify
kubectl get nodes -l vpn-gateway-node=true
```

### Step 3: Create 1Password Secret

In your 1Password "K8s" vault, create an item:
- Name: `gluetun-pia-vpn`
- Fields:
  - `username`: Your PIA username
  - `password`: Your PIA password

### Step 4: Deploy VPN Gateway (Bootstrap Mode)

The kustomization is already configured to skip Cilium policies:

```bash
# Deploy VPN gateway
cd /home/jwolf@sector-orange.com/Documents/atoca.house
git add apps/vpn-gateway/
git commit -m "Add VPN gateway (bootstrap without Cilium policies)"
git push

# Or manually:
kubectl apply -k apps/vpn-gateway/
```

### Step 5: Verify VPN Works

```bash
# Wait for pod to be ready
kubectl wait --for=condition=ready pod -n vpn-gateway -l app=gluetun --timeout=300s

# Check logs
kubectl logs -n vpn-gateway -l app=gluetun --tail=50

# Verify VPN IP (should NOT be your home IP)
kubectl exec -n vpn-gateway deploy/gluetun -- wget -qO- https://api.ipify.org
```

### Step 6: Deploy ZNC

```bash
git add apps/znc/
git commit -m "Add ZNC IRC bouncer"
git push

# Or manually:
kubectl apply -k apps/znc/
```

### Step 7: Enable Cilium Policies (Later, Optional)

After everything works, you can enable egress gateway:

1. Edit `apps/vpn-gateway/kustomization.yaml`
2. Uncomment these lines:
   ```yaml
   - cilium-egress-gateway.yaml
   - network-policies.yaml
   ```
3. Apply:
   ```bash
   kubectl apply -k apps/vpn-gateway/
   ```

## Using HTTP Proxy Instead of Egress Gateway

If you prefer not to use Cilium egress gateway, or if it's not working:

**Edit `apps/znc/deployment.yaml`** and uncomment:
```yaml
- name: HTTP_PROXY
  value: "http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888"
- name: HTTPS_PROXY
  value: "http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888"
- name: NO_PROXY
  value: "localhost,127.0.0.1,.svc,.cluster.local"
```

This will route ZNC traffic through the VPN using HTTP proxy protocol.

## Verification

### Check VPN is Working
```bash
# From inside Gluetun pod
kubectl exec -n vpn-gateway deploy/gluetun -- wget -qO- https://api.ipify.org
# Should show VPN IP

# From ZNC pod (with HTTP proxy env vars)
kubectl exec -n media deploy/znc -- wget -qO- https://api.ipify.org
# Should show VPN IP
```

### Check Services
```bash
# VPN Gateway
kubectl get pods -n vpn-gateway
kubectl get svc -n vpn-gateway

# ZNC
kubectl get pods -n media
kubectl get svc -n media
kubectl get httproute -n media znc
```

### Access ZNC
Open: https://znc.atoca.house

## Troubleshooting

### Cilium Not Starting
Error: `egress gateway requires --enable-ipv4-masquerade="true" and --enable-bpf-masquerade="true"`

**Solution**: The values.yaml has been updated. Make sure Cilium picks up the changes:
```bash
# Force Cilium to reload config (method depends on how it's deployed)
kubectl rollout restart -n kube-system daemonset/cilium
# Or
kubectl delete pods -n kube-system -l k8s-app=cilium
```

### VPN Not Connecting
```bash
# Check logs
kubectl logs -n vpn-gateway -l app=gluetun --tail=100

# Check secrets
kubectl get secret -n vpn-gateway gluetun-credentials
kubectl get externalsecret -n vpn-gateway gluetun-credentials

# Common issues:
# - Wrong PIA credentials in 1Password
# - Server name not valid (check configmap)
# - Network connectivity issues
```

### ZNC Not Routing Through VPN
```bash
# Check if HTTP proxy env vars are set
kubectl get pod -n media -l app=znc -o yaml | grep -A 3 HTTP_PROXY

# Check connectivity to proxy
kubectl exec -n media deploy/znc -- wget -qO- http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888

# Check IP from ZNC
kubectl exec -n media deploy/znc -- wget -qO- https://api.ipify.org
```

## Current Status

- ✅ Cilium values.yaml updated with masquerade settings
- ✅ VPN gateway deployment fixed (invalid label removed)
- ✅ CiliumEgressGatewayPolicy API corrected
- ✅ Kustomization configured for bootstrap (Cilium policies commented out)
- ✅ ZNC configured with HTTP proxy fallback option
- ⏳ Waiting for Cilium to be updated in cluster
- ⏳ Waiting for node to be labeled
- ⏳ Waiting for 1Password secret to be created

Next: Update Cilium, then deploy VPN gateway!
