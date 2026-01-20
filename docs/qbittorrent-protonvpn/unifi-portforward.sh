#!/bin/bash
# NAT-PMP Port Forwarding Script for Unifi Gateway + ProtonVPN
# This script runs ON the Unifi Gateway itself

set -e

# Configuration
PROTON_GW="10.2.0.1"
QBIT_POD_IP="192.168.90.10"  # The pod's VPN network IP
QBIT_API="https://qbittorrent.atoca.house"
PORT_FILE="/tmp/protonvpn-port"
LOG_FILE="/var/log/protonvpn-portforward.log"
VPN_BRIDGE_INTERFACE="br6"  # Interface to reach VPN network (192.168.90.x)

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to ensure route to ProtonVPN gateway exists
ensure_route() {
    # Check if route exists
    if ! ip route get "$PROTON_GW" 2>/dev/null | grep -q "dev wgclt1"; then
        log "Adding route to $PROTON_GW via wgclt1..."
        ip route add "$PROTON_GW/32" dev wgclt1 2>/dev/null || true

        # Verify route was added
        if ip route get "$PROTON_GW" 2>/dev/null | grep -q "dev wgclt1"; then
            log "Route to $PROTON_GW successfully added"
        else
            log "WARNING: Could not add route to $PROTON_GW"
        fi
    fi
}

# Function to get current qBittorrent listening port
get_qbittorrent_port() {
    local prefs
    prefs=$(curl -s --max-time 5 "$QBIT_API/api/v2/app/preferences" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$prefs" ]; then
        echo "$prefs" | grep -o '"listen_port":[0-9]*' | cut -d: -f2
    else
        echo "0"
    fi
}

# Function to update qBittorrent port
update_qbittorrent_port() {
    local port=$1
    if [ -z "$port" ] || [ "$port" -eq 0 ]; then
        return 1
    fi

    log "Updating qBittorrent at $QBIT_API to use port $port..."

    CURL_OUTPUT=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        --max-time 5 \
        --data "json={\"listen_port\":$port}" \
        "$QBIT_API/api/v2/app/setPreferences" 2>&1)

    HTTP_CODE=$(echo "$CURL_OUTPUT" | grep "HTTP_CODE:" | cut -d: -f2)

    if [ "$HTTP_CODE" = "200" ] || [ -z "$HTTP_CODE" ]; then
        log "Successfully updated qBittorrent to port $port"
        return 0
    else
        log "WARNING: Failed to update qBittorrent (HTTP $HTTP_CODE)"
        return 1
    fi
}

# Function to remove iptables rules for old port
remove_port_forward() {
    local port=$1
    if [ -z "$port" ] || [ "$port" -eq 0 ]; then
        return
    fi

    log "Removing iptables rules for old port $port..."

    # Remove DNAT rules
    iptables -t nat -D PREROUTING -i wgclt1 -p tcp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port" 2>/dev/null || true
    iptables -t nat -D PREROUTING -i wgclt1 -p udp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port" 2>/dev/null || true

    # Remove FORWARD rules (try both INSERT and APPEND positions)
    iptables -D FORWARD -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p tcp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p udp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT 2>/dev/null || true

    # Remove MASQUERADE rules
    iptables -t nat -D POSTROUTING -s "$QBIT_POD_IP" -p tcp --sport "$port" -o wgclt1 -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s "$QBIT_POD_IP" -p udp --sport "$port" -o wgclt1 -j MASQUERADE 2>/dev/null || true
}

# Function to add iptables rules for new port
add_port_forward() {
    local port=$1
    if [ -z "$port" ] || [ "$port" -eq 0 ]; then
        return
    fi

    log "Adding iptables rules to forward port $port to $QBIT_POD_IP..."

    # Add DNAT rules to forward from WireGuard interface to qBittorrent pod
    iptables -t nat -A PREROUTING -i wgclt1 -p tcp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port"
    iptables -t nat -A PREROUTING -i wgclt1 -p udp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port"

    # INSERT at position 1 to bypass Unifi security chains
    iptables -I FORWARD 1 -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p tcp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT
    iptables -I FORWARD 1 -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p udp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT

    # Add MASQUERADE for return traffic
    iptables -t nat -I POSTROUTING 1 -s "$QBIT_POD_IP" -p tcp --sport "$port" -o wgclt1 -j MASQUERADE
    iptables -t nat -I POSTROUTING 1 -s "$QBIT_POD_IP" -p udp --sport "$port" -o wgclt1 -j MASQUERADE

    log "iptables port forwarding rules added for port $port"
}

# Ensure route exists on startup
ensure_route

# Read old port if exists
OLD_PORT=0
if [ -f "$PORT_FILE" ]; then
    OLD_PORT=$(cat "$PORT_FILE")
    if [ "$OLD_PORT" -gt 0 ]; then
        log "Found existing port $OLD_PORT, setting up port forwarding..."
        add_port_forward "$OLD_PORT"
    fi
fi

log "Starting NAT-PMP port forwarding loop..."

while true; do
    # Ensure route is still present
    ensure_route

    log "Requesting port from Proton VPN gateway $PROTON_GW..."

    # Request port from Proton (TCP, 60 second lease)
    PROTON_OUTPUT=$(natpmpc -g "$PROTON_GW" -a 1 0 tcp 60 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        # Extract the port number
        PORT=$(echo "$PROTON_OUTPUT" | grep "Mapped public port" | awk '{print $4}')

        if [ -n "$PORT" ] && [ "$PORT" -gt 0 ]; then
            # Check qBittorrent's current port
            QBIT_CURRENT_PORT=$(get_qbittorrent_port)
            log "VPN port: $PORT, qBittorrent port: $QBIT_CURRENT_PORT"

            # Update iptables if VPN port changed
            if [ "$PORT" -ne "$OLD_PORT" ]; then
                log "VPN port changed from $OLD_PORT to $PORT"

                # Also request UDP
                natpmpc -g "$PROTON_GW" -a 1 0 udp 60 >/dev/null 2>&1

                # Remove old port forwarding rules if port changed
                if [ "$OLD_PORT" -gt 0 ]; then
                    remove_port_forward "$OLD_PORT"
                fi

                # Add new port forwarding rules
                add_port_forward "$PORT"

                # Save port to file
                echo "$PORT" > "$PORT_FILE"

                OLD_PORT=$PORT
            fi

            # Always check if qBittorrent needs updating
            if [ "$QBIT_CURRENT_PORT" != "$PORT" ]; then
                log "qBittorrent port ($QBIT_CURRENT_PORT) differs from VPN port ($PORT), updating..."
                update_qbittorrent_port "$PORT"
            else
                log "Port unchanged and qBittorrent already configured: $PORT"
            fi
        else
            log "ERROR: Failed to extract port from NAT-PMP response"
            log "Response: $PROTON_OUTPUT"
        fi
    else
        log "ERROR: NAT-PMP request failed (exit code: $EXIT_CODE)"
        log "Output: $PROTON_OUTPUT"
    fi

    # Renew every 45 seconds (before 60s timeout)
    sleep 45
done
