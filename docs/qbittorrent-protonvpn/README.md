# qBittorrent ProtonVPN Port Forwarding Setup

This directory contains the configuration and scripts needed to set up automatic port forwarding for qBittorrent through ProtonVPN NAT-PMP on a Unifi Cloud Gateway Max.

## Problem

qBittorrent runs in a Kubernetes pod connected to a VPN network via Multus (192.168.90.x). The pod cannot directly access the ProtonVPN WireGuard interface (10.2.0.x) that's running on the Unifi Gateway, which is needed for NAT-PMP port forwarding.

## Solution

Run the NAT-PMP port forwarding script directly on the Unifi Gateway, which has access to both:
- ProtonVPN's NAT-PMP service (10.2.0.1) via the WireGuard interface
- qBittorrent's API (https://qbittorrent.atoca.house) via the VPN network

The script:
1. Adds a route to reach ProtonVPN's gateway (10.2.0.1) via the WireGuard interface
2. Requests port forwarding from ProtonVPN via NAT-PMP
3. Updates qBittorrent's listening port via its API
4. Renews the port lease every 45 seconds

## Files

- **`unifi-portforward.sh`** - Main script that handles port forwarding
- **`protonvpn-portforward.service`** - Systemd service file for auto-start
- **`INSTALL_UNIFI.md`** - Complete installation instructions

## Quick Install

```bash
# From the repository root
cd docs/qbittorrent-protonvpn

# Copy files to Unifi Gateway
scp unifi-portforward.sh root@192.168.40.1:/root/portforward.sh
scp protonvpn-portforward.service root@192.168.40.1:/etc/systemd/system/

# SSH into gateway and set up service
ssh root@192.168.40.1

# Make script executable
chmod +x /root/portforward.sh

# Enable and start service
systemctl daemon-reload
systemctl enable protonvpn-portforward.service
systemctl start protonvpn-portforward.service

# Check status
systemctl status protonvpn-portforward.service
journalctl -u protonvpn-portforward.service -f
```

## Monitoring

```bash
# Check current port
ssh root@192.168.40.1 'cat /tmp/protonvpn-port'

# View logs
ssh root@192.168.40.1 'tail -f /var/log/protonvpn-portforward.log'

# Check service status
ssh root@192.168.40.1 'systemctl status protonvpn-portforward'
```

## Configuration

Edit `/root/portforward.sh` on the gateway if you need to change:

- `PROTON_GW`: ProtonVPN gateway address (default: 10.2.0.1)
- `QBIT_POD_IP`: qBittorrent pod's VPN IP (default: 192.168.90.10)
- `QBIT_API`: qBittorrent API endpoint (default: https://qbittorrent.atoca.house)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Unifi Cloud Gateway Max                   │
│  ┌──────────────┐            ┌──────────────────────────┐   │
│  │ WireGuard    │            │ Port Forwarding Script   │   │
│  │ (wgclt1)     │◄───────────│ /root/portforward.sh     │   │
│  │ 10.2.0.2     │ NAT-PMP    │                          │   │
│  └──────┬───────┘            └───────────┬──────────────┘   │
│         │                                │                  │
│         │ 10.2.0.1                      │ HTTPS API        │
│         ▼                                ▼                  │
│  ┌──────────────┐            ┌──────────────────────────┐   │
│  │ ProtonVPN    │            │ VPN Network              │   │
│  │ Gateway      │            │ 192.168.90.x             │   │
│  └──────────────┘            └───────────┬──────────────┘   │
└─────────────────────────────────────────┼──────────────────┘
                                          │
                              ┌───────────▼──────────────┐
                              │ Kubernetes Pod           │
                              │ qBittorrent              │
                              │ 192.168.90.10:80         │
                              └──────────────────────────┘
```

## Date Created

2026-01-18

## Related Files

- Helm values: `apps/media/qbittorrent/values.yaml`
- Helm chart: `app-template` v4.5.0
