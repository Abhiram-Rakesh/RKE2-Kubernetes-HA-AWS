#!/usr/bin/env bash
set -euo pipefail

# Phase 0 — Common Node Preparation

INV="$REPO_ROOT/inventory/inventory.json"
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"
BASTION_IP="$(jq -r .nginx_lb.public_ip "$INV")"
ALL_NODES="$(jq -r '.control_plane[], .workers[]' "$INV")"

# Logging helpers (pure Bash)

BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

log_info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

separator() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${RESET}"
}

# Phase banner

separator
log_info "Phase 0: Common node preparation"
log_info "Target nodes: control planes + workers"
separator

# Execute preparation on each node

for IP in $ALL_NODES; do
    separator
    log_info "Preparing node: ${IP}"
    separator

    ssh $SSH_OPTS -i "$KEY" \
        -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
        ubuntu@"$IP" <<'EOF'
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

sudo apt-get update -y
sudo apt-get install -y curl jq
EOF

    log_success "Node prepared successfully: ${IP}"
done

# Phase completion

separator
log_success "Phase 0 completed: Common node preparation successful"
separator
