#!/usr/bin/env bash
set -euo pipefail

# Generate Ansible inventory from OpenTofu outputs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TOFU_DIR="${PROJECT_DIR}/tofu"
INVENTORY_DIR="${PROJECT_DIR}/ansible/inventory"
INVENTORY_FILE="${INVENTORY_DIR}/hosts.yml"

# ── Validate tofu directory ───────────────────────────────────────────────────
if [[ ! -d "$TOFU_DIR" ]]; then
    echo "ERROR: OpenTofu directory not found at $TOFU_DIR"
    exit 1
fi

# ── Get OpenTofu outputs ─────────────────────────────────────────────────────
echo "Reading OpenTofu outputs..."
TOFU_OUTPUT=$(cd "$TOFU_DIR" && tofu output -json)

# ── Parse outputs ─────────────────────────────────────────────────────────────
HAPROXY_IP=$(echo "$TOFU_OUTPUT" | jq -r '.haproxy_ip.value')
CLUSTER_ENDPOINT=$(echo "$TOFU_OUTPUT" | jq -r '.cluster_endpoint.value')
METALLB_RANGE=$(echo "$TOFU_OUTPUT" | jq -r '.metallb_range.value')
GATEWAY=$(echo "$TOFU_OUTPUT" | jq -r '.gateway.value')
DNS_SERVER=$(echo "$TOFU_OUTPUT" | jq -r '.dns_server.value')

# Control plane IPs as array
mapfile -t CP_IPS < <(echo "$TOFU_OUTPUT" | jq -r '.controlplane_ips.value[]')

# Worker IPs as array
mapfile -t WORKER_IPS < <(echo "$TOFU_OUTPUT" | jq -r '.worker_ips.value[]')

echo "Parsed values:"
echo "  HAProxy IP:        $HAPROXY_IP"
echo "  Cluster endpoint:  $CLUSTER_ENDPOINT"
echo "  MetalLB range:     $METALLB_RANGE"
echo "  Gateway:           $GATEWAY"
echo "  DNS server:        $DNS_SERVER"
echo "  Control plane IPs: ${CP_IPS[*]}"
echo "  Worker IPs:        ${WORKER_IPS[*]}"

# ── Generate inventory ───────────────────────────────────────────────────────
mkdir -p "$INVENTORY_DIR"

CLUSTER_NAME=$(echo "$TOFU_OUTPUT" | jq -r '.cluster_name.value')

cat > "$INVENTORY_FILE" <<YAML
---
all:
  vars:
    cluster_name: "${CLUSTER_NAME}"
    cluster_endpoint: "${CLUSTER_ENDPOINT}"
    haproxy_ip: "${HAPROXY_IP}"
    metallb_pool_range: "${METALLB_RANGE}"
    gateway: "${GATEWAY}"
    dns_server: "${DNS_SERVER}"
    talos_config_dir: "{{ playbook_dir }}/../talos-generated"

  children:
    haproxy:
      hosts:
        haproxy-01:
          ansible_host: "${HAPROXY_IP}"
          ansible_user: alpine
          ansible_become: true
          ansible_become_method: doas
          ansible_connection: ssh

    controlplane:
      vars:
        ansible_connection: local
      hosts:
YAML

# Add control plane hosts
for i in "${!CP_IPS[@]}"; do
    cat >> "$INVENTORY_FILE" <<YAML
        cp-$((i + 1)):
          ansible_host: "${CP_IPS[$i]}"
          node_ip: "${CP_IPS[$i]}"
YAML
done

cat >> "$INVENTORY_FILE" <<YAML

    workers:
      vars:
        ansible_connection: local
      hosts:
YAML

# Add worker hosts
for i in "${!WORKER_IPS[@]}"; do
    cat >> "$INVENTORY_FILE" <<YAML
        worker-$((i + 1)):
          ansible_host: "${WORKER_IPS[$i]}"
          node_ip: "${WORKER_IPS[$i]}"
YAML
done

echo ""
echo "Inventory written to $INVENTORY_FILE"
echo ""
cat "$INVENTORY_FILE"
