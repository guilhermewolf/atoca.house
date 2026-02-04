#!/bin/bash
# NAT-PMP Port Forwarding Script for Unifi Gateway + ProtonVPN
# This script runs ON the Unifi Gateway itself
# Version: 2.0 - Bulletproof Edition

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
PROTON_GW="10.2.0.1"
QBIT_POD_IP="192.168.90.10"
QBIT_API="https://qbittorrent.atoca.house"
PORT_FILE="/tmp/protonvpn-port"
LOG_FILE="/var/log/protonvpn-portforward.log"
VPN_BRIDGE_INTERFACE="br6"

# Safety limits
# Current healthy baseline: ~395 filter rules, ~54 NAT rules
# These limits are 2x normal to allow for growth while catching runaway issues
MAX_RULES_PER_IP=10          # Maximum rules allowed for our IP (6 needed normally)
MAX_TOTAL_FILTER_RULES=800   # Maximum total filter rules (2x normal baseline)
MAX_TOTAL_NAT_RULES=200      # Maximum total NAT rules (3.7x normal baseline)
MAX_QBIT_RETRIES=5           # Maximum retries for qBittorrent API
QBIT_RETRY_DELAY=5           # Initial retry delay in seconds
HEALTH_CHECK_INTERVAL=300    # Health check every 5 minutes

# Global state
SCRIPT_PID=$$
CLEANUP_DONE=0

# Function to log messages with levels
log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

# Function to safely count rules
count_rules_for_ip() {
    local ip="$1"
    local table="${2:-filter}"
    iptables -t "$table" -S 2>/dev/null | grep "$ip" | wc -l | xargs || echo "0"
}

count_total_rules() {
    local table="${1:-filter}"
    iptables -t "$table" -S 2>/dev/null | wc -l | tr -d '\n'
}

# Function to validate system health before proceeding
validate_system_health() {
    log_info "Performing system health check..."

    # Check if iptables is responding
    if ! iptables -L -n >/dev/null 2>&1; then
        log_error "iptables is not responding!"
        return 1
    fi

    # Check current rule counts
    local filter_count=$(count_total_rules filter)
    local nat_count=$(count_total_rules nat)
    local our_filter_count=$(count_rules_for_ip "$QBIT_POD_IP" filter)
    local our_nat_count=$(count_rules_for_ip "$QBIT_POD_IP" nat)

    log_info "Current rules: Filter=$filter_count, NAT=$nat_count"
    log_info "Rules for $QBIT_POD_IP: Filter=$our_filter_count, NAT=$our_nat_count"

    # Check if we're approaching limits
    if [ "$filter_count" -gt "$MAX_TOTAL_FILTER_RULES" ]; then
        log_error "Total filter rules ($filter_count) exceed maximum ($MAX_TOTAL_FILTER_RULES)!"
        return 1
    fi

    if [ "$nat_count" -gt "$MAX_TOTAL_NAT_RULES" ]; then
        log_error "Total NAT rules ($nat_count) exceed maximum ($MAX_TOTAL_NAT_RULES)!"
        return 1
    fi

    if [ "$our_filter_count" -gt "$MAX_RULES_PER_IP" ]; then
        log_warn "Too many rules for $QBIT_POD_IP ($our_filter_count), cleaning up..."
        cleanup_all_port_forwards
        return 1
    fi

    if [ "$our_nat_count" -gt "$MAX_RULES_PER_IP" ]; then
        log_warn "Too many NAT rules for $QBIT_POD_IP ($our_nat_count), cleaning up..."
        cleanup_all_port_forwards
        return 1
    fi

    log_info "System health check passed"
    return 0
}

# Function to ensure route to ProtonVPN gateway exists
ensure_route() {
    if ! ip route get "$PROTON_GW" 2>/dev/null | grep -q "dev wgclt1"; then
        log_info "Adding route to $PROTON_GW via wgclt1..."
        ip route add "$PROTON_GW/32" dev wgclt1 2>/dev/null || true

        if ip route get "$PROTON_GW" 2>/dev/null | grep -q "dev wgclt1"; then
            log_info "Route to $PROTON_GW successfully added"
        else
            log_error "Could not add route to $PROTON_GW"
            return 1
        fi
    fi
    return 0
}

# Function to get current qBittorrent listening port with retry logic
get_qbittorrent_port() {
    local retries=0
    local delay=$QBIT_RETRY_DELAY
    local prefs

    while [ $retries -lt $MAX_QBIT_RETRIES ]; do
        prefs=$(curl -s --max-time 5 "$QBIT_API/api/v2/app/preferences" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$prefs" ]; then
            local port=$(echo "$prefs" | grep -o '"listen_port":[0-9]*' | cut -d: -f2)
            if [ -n "$port" ] && [ "$port" -gt 0 ]; then
                echo "$port"
                return 0
            fi
        fi

        retries=$((retries + 1))
        if [ $retries -lt $MAX_QBIT_RETRIES ]; then
            log_warn "qBittorrent not responding (attempt $retries/$MAX_QBIT_RETRIES), retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
    done

    log_error "qBittorrent is not reachable after $MAX_QBIT_RETRIES attempts"
    echo "0"
    return 1
}

# Function to update qBittorrent port with retry logic
update_qbittorrent_port() {
    local port=$1
    local retries=0
    local delay=$QBIT_RETRY_DELAY

    if [ -z "$port" ] || [ "$port" -eq 0 ]; then
        log_error "Invalid port: $port"
        return 1
    fi

    log_info "Updating qBittorrent to use port $port..."

    while [ $retries -lt $MAX_QBIT_RETRIES ]; do
        local curl_output=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
            --max-time 5 \
            --data "json={\"listen_port\":$port}" \
            "$QBIT_API/api/v2/app/setPreferences" 2>&1)

        local http_code=$(echo "$curl_output" | grep "HTTP_CODE:" | cut -d: -f2)

        if [ "$http_code" = "200" ] || [ -z "$http_code" ]; then
            log_info "Successfully updated qBittorrent to port $port"
            return 0
        fi

        retries=$((retries + 1))
        if [ $retries -lt $MAX_QBIT_RETRIES ]; then
            log_warn "Failed to update qBittorrent (HTTP $http_code), retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi
    done

    log_error "Failed to update qBittorrent after $MAX_QBIT_RETRIES attempts"
    return 1
}

# Function to check if a specific rule exists
rule_exists() {
    "$@" -C "${@:2}" 2>/dev/null
}

# Function to cleanup ALL port forwarding rules for our IP
cleanup_all_port_forwards() {
    log_info "Cleaning up ALL port forwarding rules for $QBIT_POD_IP..."

    local removed_filter=0
    local removed_nat=0

    # Use iptables-save/restore for bulk operations (much faster)
    local temp_filter="/tmp/iptables-filter-$$.tmp"
    local temp_nat="/tmp/iptables-nat-$$.tmp"

    # Backup and filter rules
    iptables-save > "$temp_filter" 2>/dev/null || true
    iptables-save -t nat > "$temp_nat" 2>/dev/null || true

    # Count before
    removed_filter=$(grep -c "$QBIT_POD_IP" "$temp_filter" 2>/dev/null || echo "0")
    removed_nat=$(grep -c "$QBIT_POD_IP" "$temp_nat" 2>/dev/null || echo "0")

    # Remove lines with our IP and restore
    grep -v "$QBIT_POD_IP" "$temp_filter" | iptables-restore 2>/dev/null || true
    grep -v "$QBIT_POD_IP" "$temp_nat" | iptables-restore -t nat 2>/dev/null || true

    # Cleanup temp files
    rm -f "$temp_filter" "$temp_nat"

    log_info "Removed $removed_filter filter rules and $removed_nat NAT rules for $QBIT_POD_IP"
}

# Function to remove port forwarding for a specific port (safe, idempotent)
remove_port_forward() {
    local port=$1
    if [ -z "$port" ] || [ "$port" -eq 0 ]; then
        return 0
    fi

    log_info "Removing port forwarding rules for port $port..."

    local removed=0

    # Remove ALL duplicate DNAT rules (loop until none exist)
    while iptables -t nat -D PREROUTING -i wgclt1 -p tcp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port" 2>/dev/null; do
        removed=$((removed + 1))
    done
    while iptables -t nat -D PREROUTING -i wgclt1 -p udp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port" 2>/dev/null; do
        removed=$((removed + 1))
    done

    # Remove ALL duplicate FORWARD rules
    while iptables -D FORWARD -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p tcp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT 2>/dev/null; do
        removed=$((removed + 1))
    done
    while iptables -D FORWARD -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p udp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT 2>/dev/null; do
        removed=$((removed + 1))
    done

    # Remove ALL duplicate MASQUERADE rules
    while iptables -t nat -D POSTROUTING -s "$QBIT_POD_IP" -p tcp --sport "$port" -o wgclt1 -j MASQUERADE 2>/dev/null; do
        removed=$((removed + 1))
    done
    while iptables -t nat -D POSTROUTING -s "$QBIT_POD_IP" -p udp --sport "$port" -o wgclt1 -j MASQUERADE 2>/dev/null; do
        removed=$((removed + 1))
    done

    if [ $removed -gt 0 ]; then
        log_info "Removed $removed duplicate rules for port $port"
    fi
}

# Function to add port forwarding rules (safe, idempotent)
add_port_forward() {
    local port=$1
    if [ -z "$port" ] || [ "$port" -eq 0 ]; then
        log_error "Invalid port: $port"
        return 1
    fi

    # Validate system health before adding rules
    if ! validate_system_health; then
        log_error "System health check failed, not adding rules"
        return 1
    fi

    log_info "Adding port forwarding rules for port $port to $QBIT_POD_IP..."

    local added=0

    # Add DNAT rules (only if not exists)
    if ! rule_exists iptables -t nat PREROUTING -i wgclt1 -p tcp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port"; then
        if iptables -t nat -A PREROUTING -i wgclt1 -p tcp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port" 2>/dev/null; then
            log_info "Added DNAT TCP rule"
            added=$((added + 1))
        else
            log_error "Failed to add DNAT TCP rule"
        fi
    fi

    if ! rule_exists iptables -t nat PREROUTING -i wgclt1 -p udp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port"; then
        if iptables -t nat -A PREROUTING -i wgclt1 -p udp --dport "$port" -j DNAT --to-destination "$QBIT_POD_IP:$port" 2>/dev/null; then
            log_info "Added DNAT UDP rule"
            added=$((added + 1))
        else
            log_error "Failed to add DNAT UDP rule"
        fi
    fi

    # Add FORWARD rules (only if not exists)
    if ! rule_exists iptables FORWARD -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p tcp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT; then
        if iptables -I FORWARD 1 -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p tcp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT 2>/dev/null; then
            log_info "Added FORWARD TCP rule"
            added=$((added + 1))
        else
            log_error "Failed to add FORWARD TCP rule"
        fi
    fi

    if ! rule_exists iptables FORWARD -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p udp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT; then
        if iptables -I FORWARD 1 -i wgclt1 -o "$VPN_BRIDGE_INTERFACE" -p udp --dport "$port" -d "$QBIT_POD_IP" -j ACCEPT 2>/dev/null; then
            log_info "Added FORWARD UDP rule"
            added=$((added + 1))
        else
            log_error "Failed to add FORWARD UDP rule"
        fi
    fi

    # Add MASQUERADE rules (only if not exists)
    if ! rule_exists iptables -t nat POSTROUTING -s "$QBIT_POD_IP" -p tcp --sport "$port" -o wgclt1 -j MASQUERADE; then
        if iptables -t nat -I POSTROUTING 1 -s "$QBIT_POD_IP" -p tcp --sport "$port" -o wgclt1 -j MASQUERADE 2>/dev/null; then
            log_info "Added MASQUERADE TCP rule"
            added=$((added + 1))
        else
            log_error "Failed to add MASQUERADE TCP rule"
        fi
    fi

    if ! rule_exists iptables -t nat POSTROUTING -s "$QBIT_POD_IP" -p udp --sport "$port" -o wgclt1 -j MASQUERADE; then
        if iptables -t nat -I POSTROUTING 1 -s "$QBIT_POD_IP" -p udp --sport "$port" -o wgclt1 -j MASQUERADE 2>/dev/null; then
            log_info "Added MASQUERADE UDP rule"
            added=$((added + 1))
        else
            log_error "Failed to add MASQUERADE UDP rule"
        fi
    fi

    if [ $added -gt 0 ]; then
        log_info "Successfully added $added new rules for port $port"
    else
        log_info "All rules for port $port already exist (idempotent check)"
    fi

    return 0
}

# Cleanup function for graceful shutdown
cleanup_on_exit() {
    if [ $CLEANUP_DONE -eq 1 ]; then
        return
    fi
    CLEANUP_DONE=1

    log_info "Received termination signal, cleaning up..."

    # Optionally remove all port forwarding rules on exit
    # Uncomment the next line if you want rules removed when script stops
    # cleanup_all_port_forwards

    log_info "Cleanup complete, exiting."
    exit 0
}

# Trap signals for graceful shutdown
trap cleanup_on_exit SIGTERM SIGINT SIGHUP

# Main startup
log_info "=== ProtonVPN Port Forwarding Script Starting (PID: $SCRIPT_PID) ==="
log_info "Configuration: QBIT_POD_IP=$QBIT_POD_IP, VPN_GW=$PROTON_GW"
log_info "Safety limits: MAX_RULES_PER_IP=$MAX_RULES_PER_IP, MAX_FILTER=$MAX_TOTAL_FILTER_RULES, MAX_NAT=$MAX_TOTAL_NAT_RULES"

# Initial system health check
if ! validate_system_health; then
    log_error "Initial system health check failed, exiting!"
    exit 1
fi

# Ensure route exists on startup
if ! ensure_route; then
    log_error "Failed to ensure route to ProtonVPN gateway, exiting!"
    exit 1
fi

# Read old port if exists and clean up
OLD_PORT=0
if [ -f "$PORT_FILE" ]; then
    OLD_PORT=$(cat "$PORT_FILE")
    if [ "$OLD_PORT" -gt 0 ]; then
        log_info "Found existing port $OLD_PORT from previous run"

        # Clean up any duplicate rules from previous crashes/restarts
        log_info "Cleaning up any stale rules for port $OLD_PORT..."
        remove_port_forward "$OLD_PORT"

        # Verify cleanup worked
        REMAINING=$(count_rules_for_ip "$QBIT_POD_IP" filter | tr -d '\n')
        if [ "$REMAINING" -gt "$MAX_RULES_PER_IP" ]; then
            log_error "Cleanup failed, still have $REMAINING rules. Performing full cleanup..."
            cleanup_all_port_forwards
        fi

        # Now add the rules cleanly (only once)
        if add_port_forward "$OLD_PORT"; then
            log_info "Successfully restored port forwarding for port $OLD_PORT"
        else
            log_error "Failed to restore port forwarding for port $OLD_PORT"
        fi
    fi
fi

log_info "Starting NAT-PMP port forwarding loop..."

# Main loop with health checks
LOOP_COUNT=0
LAST_HEALTH_CHECK=0

while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))
    CURRENT_TIME=$(date +%s)

    # Periodic health check
    if [ $((CURRENT_TIME - LAST_HEALTH_CHECK)) -ge $HEALTH_CHECK_INTERVAL ]; then
        log_info "Periodic health check (loop #$LOOP_COUNT)..."
        if ! validate_system_health; then
            log_error "Health check failed, waiting before retry..."
            sleep 60
            continue
        fi
        LAST_HEALTH_CHECK=$CURRENT_TIME
    fi

    # Ensure route is still present
    if ! ensure_route; then
        log_error "Route check failed, retrying..."
        sleep 30
        continue
    fi

    log_info "Requesting port from ProtonVPN gateway $PROTON_GW (loop #$LOOP_COUNT)..."

    # Request port from ProtonVPN (TCP, 60 second lease)
    PROTON_OUTPUT=$(natpmpc -g "$PROTON_GW" -a 1 0 tcp 60 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        # Extract the port number
        PORT=$(echo "$PROTON_OUTPUT" | grep "Mapped public port" | awk '{print $4}')

        if [ -n "$PORT" ] && [ "$PORT" -gt 0 ]; then
            # Check qBittorrent's current port (with retry logic)
            QBIT_CURRENT_PORT=$(get_qbittorrent_port)

            if [ "$QBIT_CURRENT_PORT" = "0" ]; then
                log_warn "qBittorrent is not responding, will retry on next cycle"
            else
                log_info "VPN port: $PORT, qBittorrent port: $QBIT_CURRENT_PORT"
            fi

            # Update iptables if VPN port changed
            if [ "$PORT" -ne "$OLD_PORT" ]; then
                log_info "VPN port changed from $OLD_PORT to $PORT"

                # Also request UDP
                natpmpc -g "$PROTON_GW" -a 1 0 udp 60 >/dev/null 2>&1

                # Remove old port forwarding rules if port changed
                if [ "$OLD_PORT" -gt 0 ]; then
                    remove_port_forward "$OLD_PORT"
                fi

                # Add new port forwarding rules
                if add_port_forward "$PORT"; then
                    # Save port to file only if rules were added successfully
                    echo "$PORT" > "$PORT_FILE"
                    OLD_PORT=$PORT
                else
                    log_error "Failed to add port forwarding rules, not updating OLD_PORT"
                fi
            fi

            # Always check if qBittorrent needs updating (if reachable)
            if [ "$QBIT_CURRENT_PORT" != "0" ] && [ "$QBIT_CURRENT_PORT" != "$PORT" ]; then
                log_info "qBittorrent port ($QBIT_CURRENT_PORT) differs from VPN port ($PORT), updating..."
                update_qbittorrent_port "$PORT"
            elif [ "$QBIT_CURRENT_PORT" = "$PORT" ]; then
                log_info "Port unchanged and qBittorrent already configured: $PORT"
            fi
        else
            log_error "Failed to extract port from NAT-PMP response"
            log_error "Response: $PROTON_OUTPUT"
        fi
    else
        log_error "NAT-PMP request failed (exit code: $EXIT_CODE)"
        log_error "Output: $PROTON_OUTPUT"
    fi

    # Renew every 45 seconds (before 60s timeout)
    sleep 45
done
