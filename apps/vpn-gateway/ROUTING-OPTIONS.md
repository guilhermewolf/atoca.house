# VPN Routing Options

You have two ways to route traffic through the VPN gateway:

## Option 1: HTTP/SOCKS5 Proxy (Simpler, Recommended to Start)

### Pros:
- ✅ No node labeling required
- ✅ No Cilium egress gateway needed
- ✅ Works immediately
- ✅ Gluetun pod can run on any node
- ✅ Standard approach, well-tested

### Cons:
- ⚠️ Applications must support HTTP proxy (most do)
- ⚠️ Requires explicit proxy configuration in each app

### How it works:
Applications set environment variables to use Gluetun's HTTP proxy:
```yaml
env:
  - name: HTTP_PROXY
    value: "http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888"
  - name: HTTPS_PROXY
    value: "http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888"
```

### Setup:
1. Deploy Gluetun (no node label needed)
2. Configure apps with proxy env vars
3. Done!

---

## Option 2: Cilium Egress Gateway (Advanced, Transparent)

### Pros:
- ✅ Transparent routing (no app changes needed)
- ✅ Just add a label: `vpn-egress: "true"`
- ✅ Works for all protocols (not just HTTP)
- ✅ No proxy configuration in apps

### Cons:
- ⚠️ Requires node labeling
- ⚠️ Requires Cilium egress gateway feature
- ⚠️ More complex setup
- ⚠️ Gluetun pod must run on the labeled egress node

### How it works:
Cilium intercepts traffic at the eBPF level and routes it through a specific node that has VPN access.

### Why node labeling is required:
Cilium egress gateway needs to know which physical node's network interface to use for routing. The traffic flow is:

```
Pod with vpn-egress=true
  ↓
Cilium eBPF (detects label)
  ↓
Routes to node with label vpn-gateway-node=true
  ↓
Traffic exits through that node's network interface
  ↓
Gluetun VPN tunnel on that node
  ↓
Internet via VPN
```

**The node label tells Cilium**: "Route VPN-labeled pod traffic through THIS node's network stack, where the Gluetun pod is running with VPN tunnel."

### Setup:
1. Label a node: `kubectl label node <node-name> vpn-gateway-node=true`
2. Deploy Gluetun with node affinity (to ensure it runs on labeled node)
3. Enable Cilium egress gateway policies
4. Add `vpn-egress: "true"` label to pods
5. Done!

---

## Recommended Approach

### Start with Option 1 (HTTP Proxy):
- Simple, reliable, immediate
- Get VPN working first
- No infrastructure changes needed

### Migrate to Option 2 later (if desired):
- Once everything works
- If you want transparent routing
- If you need non-HTTP protocols through VPN

---

## Implementation Changes

### For Option 1 (HTTP Proxy - Simpler):

**1. Remove node affinity from Gluetun deployment:**

Edit `apps/vpn-gateway/deployment.yaml` - Remove or comment out:
```yaml
# Node affinity can be removed for HTTP proxy approach
# affinity:
#   nodeAffinity:
#     preferredDuringSchedulingIgnoredDuringExecution:
#       - weight: 100
#         preference:
#           matchExpressions:
#             - key: kubernetes.io/hostname
#               operator: In
#               values:
#                 - pi-node-1
```

**2. Configure apps to use proxy:**

Edit `apps/znc/deployment.yaml` - Uncomment:
```yaml
- name: HTTP_PROXY
  value: "http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888"
- name: HTTPS_PROXY
  value: "http://gluetun-http-proxy.vpn-gateway.svc.cluster.local:8888"
- name: NO_PROXY
  value: "localhost,127.0.0.1,.svc,.cluster.local"
```

**3. Keep Cilium policies commented out in kustomization.yaml**

You won't need them for HTTP proxy approach.

---

### For Option 2 (Cilium Egress Gateway - Advanced):

Keep the current configuration, but:

**1. Label a node:**
```bash
kubectl label node <your-preferred-node> vpn-gateway-node=true
```

**2. Update node affinity in deployment:**
Change `preferredDuringSchedulingIgnoredDuringExecution` to `requiredDuringSchedulingIgnoredDuringExecution` to ensure Gluetun runs on the labeled node.

**3. Enable Cilium policies:**
Uncomment in `kustomization.yaml`:
- `cilium-egress-gateway.yaml`
- `network-policies.yaml`

**4. Pod labeling:**
Apps just need `vpn-egress: "true"` label (already set in ZNC deployment)

---

## My Recommendation

Start with **Option 1** (HTTP Proxy):

1. Remove node affinity from Gluetun
2. Enable HTTP proxy env vars in ZNC
3. Deploy and test
4. If it works, you're done!
5. If you later want transparent routing, migrate to Option 2

This gets you working faster with less complexity.

Would you like me to update the configurations for Option 1?
