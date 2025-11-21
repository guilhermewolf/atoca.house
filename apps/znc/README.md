# ZNC IRC Bouncer

ZNC is an advanced IRC bouncer that maintains persistent IRC connections and provides features like message playback, multiple clients, and SSL support.

## Features

- **VPN Routing**: All traffic automatically routed through VPN gateway (Gluetun)
- **TLS Termination**: Accessible via HTTPS at `znc.atoca.house`
- **Persistent Storage**: Configuration stored on Longhorn
- **Automatic Deployment**: Managed by ArgoCD

## Access

- **Web Interface**: https://znc.atoca.house
- **IRC Connection**: `znc.atoca.house:6501` (via HTTPS proxy or direct with proper port-forwarding)

## Initial Setup

### First Time Configuration

1. Deploy the application (ArgoCD will handle this automatically)

2. Access ZNC web interface at https://znc.atoca.house

3. Create an admin user:
   ```bash
   # Get initial setup URL from logs
   kubectl logs -n media -l app=znc --tail=50
   ```

4. Follow the web wizard to:
   - Create your admin account
   - Add IRC networks
   - Configure modules

## Usage

### Connect with IRC Client

Once configured, connect your IRC client:

**Connection Details:**
- Server: `znc.atoca.house`
- Port: `6501`
- SSL: Yes
- Username: `username/network` (e.g., `john/libera`)
- Password: `your-znc-password`

**Popular IRC Clients:**
- WeeChat
- Irssi
- HexChat
- mIRC
- Textual (macOS)

### Example: WeeChat Connection

```
/server add atoca znc.atoca.house/6501 -ssl -username=john/libera -password=yourpassword
/connect atoca
```

## Configuration

### Add New IRC Network

1. Go to https://znc.atoca.house
2. Click "Your Settings"
3. Click "Add" under Networks
4. Fill in network details (e.g., Libera.Chat, OFTC, etc.)
5. Save

### Enable Modules

Common useful modules:
- **backlog**: Replay missed messages
- **controlpanel**: Web-based control panel
- **perform**: Execute commands on connect
- **simple_away**: Auto-away status

## Verification

### Check VPN Routing

Verify ZNC is using the VPN:

```bash
# Check what IP ZNC sees
kubectl exec -n media deploy/znc -- wget -qO- https://api.ipify.org

# Should show your VPN provider's IP, not your home IP
```

### Check Logs

```bash
# View ZNC logs
kubectl logs -n media -l app=znc -f

# View VPN gateway logs
kubectl logs -n vpn-gateway -l app=gluetun -f
```

## Troubleshooting

### Cannot Connect to IRC Networks

1. Check VPN is working:
   ```bash
   kubectl exec -n media deploy/znc -- ping -c 3 libera.chat
   ```

2. Verify VPN label is applied:
   ```bash
   kubectl get pod -n media -l app=znc --show-labels
   # Should show: vpn-egress=true
   ```

3. Check network policies:
   ```bash
   kubectl get ciliumnetworkpolicy -A | grep vpn
   ```

### Web Interface Not Accessible

1. Check HTTPRoute:
   ```bash
   kubectl get httproute -n media znc
   kubectl describe httproute -n media znc
   ```

2. Verify Gateway:
   ```bash
   kubectl get gateway -n kube-system atoca-gateway
   ```

3. Check certificate:
   ```bash
   kubectl get certificate -n kube-system atoca-house-tls
   ```

### Configuration Lost

ZNC configuration is stored in a PersistentVolumeClaim. Check storage:

```bash
# Check PVC status
kubectl get pvc -n media znc-config

# If needed, restore from backup (if VolSync is configured)
kubectl get volumesnapshot -n media
```

## Migration from Docker

If migrating from the Docker setup:

1. Copy your existing configuration:
   ```bash
   # On your NAS/server
   kubectl cp /mnt/blaze/appdata/znc/ media/znc-xxxxx:/config/
   ```

2. Restart the pod:
   ```bash
   kubectl rollout restart -n media deploy/znc
   ```

## Advanced Configuration

### Custom Port for Direct IRC Access

If you need direct IRC access (not via web), add a port to the Gateway:

```yaml
# Edit gateway.yaml
- name: irc-znc
  protocol: TCP
  port: 6501
  hostname: znc.atoca.house
```

### Multiple ZNC Instances

To run multiple ZNC instances for different users:

```bash
# Copy the app directory
cp -r apps/znc apps/znc-user2

# Edit the new directory and change:
# - Deployment name
# - Service name
# - PVC name
# - HTTPRoute hostname (znc-user2.atoca.house)
```

## Resource Usage

Default resource allocation:
- CPU Limit: 1 core
- Memory Limit: 1GB
- Storage: 1GB

Adjust in `deployment.yaml` if needed.

## Backup

If VolSync is configured, backups are automatic. To manually backup:

```bash
# Create a snapshot
kubectl create -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: znc-backup-$(date +%Y%m%d)
  namespace: media
spec:
  volumeSnapshotClassName: longhorn
  source:
    persistentVolumeClaimName: znc-config
EOF
```
