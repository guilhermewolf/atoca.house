# ProtonVPN Port Forwarding Setup for Unifi Gateway

## Overview
This setup runs the NAT-PMP port forwarding script directly on your Unifi Cloud Gateway Max, which has direct access to the ProtonVPN WireGuard tunnel (10.2.0.1).

## Installation Steps

### 1. Copy the script to your Unifi Gateway

```bash
# From your local machine
scp unifi-portforward.sh root@192.168.40.1:/root/
```

### 2. SSH into your Unifi Gateway

```bash
ssh root@192.168.40.1
```

### 3. Make the script executable

```bash
chmod +x /root/unifi-portforward.sh
```

### 4. Test the script manually first

```bash
/root/unifi-portforward.sh
```

You should see output like:
```
2026-01-18 14:00:00 - Installing natpmpc...
2026-01-18 14:00:05 - Starting NAT-PMP port forwarding loop...
2026-01-18 14:00:05 - Requesting port from Proton VPN gateway 10.2.0.1...
2026-01-18 14:00:06 - Got port 12345 from Proton VPN
2026-01-18 14:00:06 - Updating qBittorrent at http://192.168.90.10:80 to use port 12345...
2026-01-18 14:00:06 - Successfully updated qBittorrent to port 12345
```

Press Ctrl+C to stop the test.

### 5. Install as a systemd service (optional but recommended)

```bash
# Copy the service file to your gateway
exit  # Exit SSH first
scp protonvpn-portforward.service root@192.168.40.1:/etc/systemd/system/
ssh root@192.168.40.1

# Enable and start the service
systemctl daemon-reload
systemctl enable protonvpn-portforward.service
systemctl start protonvpn-portforward.service

# Check the status
systemctl status protonvpn-portforward.service

# View logs
journalctl -u protonvpn-portforward.service -f
```

### 6. Verify it's working

```bash
# Check the current port
cat /tmp/protonvpn-port

# Check logs
tail -f /var/log/protonvpn-portforward.log
```

## Configuration

Edit `/root/unifi-portforward.sh` if you need to change:

- `PROTON_GW`: ProtonVPN gateway address (default: 10.2.0.1)
- `QBIT_POD_IP`: Your qBittorrent pod's VPN network IP (default: 192.168.90.10)
- `QBIT_API`: qBittorrent API endpoint (default: http://192.168.90.10:80)

## Troubleshooting

### Script can't reach 10.2.0.1
Make sure your WireGuard tunnel is up:
```bash
wg show
ip addr show
```

### Can't update qBittorrent
Check if the pod is reachable:
```bash
ping 192.168.90.10
curl http://192.168.90.10:80/api/v2/app/version
```

### Check if NAT-PMP is working
```bash
natpmpc -g 10.2.0.1 -a 1 0 tcp 60
```

## Uninstalling

```bash
# Stop and disable the service
systemctl stop protonvpn-portforward.service
systemctl disable protonvpn-portforward.service

# Remove files
rm /etc/systemd/system/protonvpn-portforward.service
rm /root/unifi-portforward.sh
rm /tmp/protonvpn-port
rm /var/log/protonvpn-portforward.log

systemctl daemon-reload
```
