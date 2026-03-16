#!/usr/bin/env bash
set -euo pipefail

# Poll until specified nodes are reachable on a given port.
# Usage: wait-for-nodes.sh <port> <ip1> <ip2> ...

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <port> <ip1> [ip2] [ip3] ..."
    echo "Example: $0 50000 192.168.122.101 192.168.122.102 192.168.122.103"
    exit 1
fi

PORT="$1"
shift
IPS=("$@")

MAX_WAIT=300   # 5 minutes total
INTERVAL=5     # start with 5 seconds
MAX_INTERVAL=30

check_host() {
    local ip="$1"
    local port="$2"
    timeout 2 bash -c "echo >/dev/tcp/${ip}/${port}" 2>/dev/null
}

echo "Waiting for ${#IPS[@]} node(s) to become reachable on port ${PORT}..."
echo "Nodes: ${IPS[*]}"
echo ""

declare -A REACHED
for ip in "${IPS[@]}"; do
    REACHED[$ip]=0
done

elapsed=0
current_interval=$INTERVAL

while [[ $elapsed -lt $MAX_WAIT ]]; do
    all_up=true
    for ip in "${IPS[@]}"; do
        if [[ ${REACHED[$ip]} -eq 1 ]]; then
            continue
        fi
        if check_host "$ip" "$PORT"; then
            echo "[$(date +%H:%M:%S)] $ip:$PORT is reachable"
            REACHED[$ip]=1
        else
            all_up=false
        fi
    done

    if $all_up; then
        echo ""
        echo "All nodes are reachable on port ${PORT}."
        exit 0
    fi

    # Show progress for nodes still unreachable
    pending=()
    for ip in "${IPS[@]}"; do
        if [[ ${REACHED[$ip]} -eq 0 ]]; then
            pending+=("$ip")
        fi
    done
    echo "[$(date +%H:%M:%S)] Waiting for: ${pending[*]} (${elapsed}s/${MAX_WAIT}s)"

    sleep "$current_interval"
    elapsed=$((elapsed + current_interval))

    # Backoff: increase interval up to max
    if [[ $current_interval -lt $MAX_INTERVAL ]]; then
        current_interval=$((current_interval + 5))
        if [[ $current_interval -gt $MAX_INTERVAL ]]; then
            current_interval=$MAX_INTERVAL
        fi
    fi
done

echo ""
echo "ERROR: Timed out after ${MAX_WAIT}s. Unreachable nodes:"
for ip in "${IPS[@]}"; do
    if [[ ${REACHED[$ip]} -eq 0 ]]; then
        echo "  - $ip:$PORT"
    fi
done
exit 1
