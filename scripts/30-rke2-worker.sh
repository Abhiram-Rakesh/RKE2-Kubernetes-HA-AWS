#!/usr/bin/env bash
set -euo pipefail

# Phase 4 — Join Worker Nodes

INV="$REPO_ROOT/inventory/inventory.json"
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

BASTION_IP="$(jq -r .nginx_lb.public_ip "$INV")"
LB_PRIVATE_IP="$(jq -r .nginx_lb.private_ip "$INV")"

CP1_IP="$(jq -r '.control_plane[0]' "$INV")"
WORKER_NODES="$(jq -r '.workers[]' "$INV")"

RKE2_VERSION="$(jq -r .rke2_version "$INV")"

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
log_info "Phase 4: Joining worker nodes"
log_info "Primary control plane: ${CP1_IP}"
log_info "Worker targets: ${WORKER_NODES:-none}"
log_info "RKE2 version: ${RKE2_VERSION}"
separator

# Fetch join token from control-plane-1

log_info "Retrieving RKE2 join token from primary control plane"

TOKEN="$(ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" \
    sudo cat /var/lib/rancher/rke2/server/node-token)"

if [[ -z "$TOKEN" ]]; then
    log_error "Failed to retrieve RKE2 join token from control-plane-1"
    exit 1
fi

log_success "RKE2 join token retrieved successfully"

# Join worker nodes

for IP in $WORKER_NODES; do
    separator
    log_info "Joining worker node: ${IP}"
    separator

    ssh $SSH_OPTS -i "$KEY" \
        -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
        ubuntu@"$IP" <<EOF
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} sudo sh -

sudo mkdir -p /etc/rancher/rke2
cat <<CFG | sudo tee /etc/rancher/rke2/config.yaml >/dev/null
server: https://${LB_PRIVATE_IP}:9345
token: ${TOKEN}
CFG

sudo systemctl enable rke2-agent
sudo systemctl start rke2-agent
EOF

    log_success "Worker node joined successfully: ${IP}"
done

# Phase completion

separator
log_success "Phase 4 completed: All worker nodes have joined the cluster"
separator
