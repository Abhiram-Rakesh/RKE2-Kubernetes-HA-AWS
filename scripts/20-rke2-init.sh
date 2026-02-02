#!/usr/bin/env bash
set -euo pipefail

# Phase 2 — Bootstrap Initial RKE2 Control Plane

INV="$REPO_ROOT/inventory/inventory.json"
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"
BASTION_IP="$(jq -r .nginx_lb.public_ip "$INV")"
CP1_IP="$(jq -r '.control_plane[0]' "$INV")"
RKE2_VERSION="$(jq -r .rke2_version "$INV")"
LB_PRIVATE_IP="$(jq -r .nginx_lb.private_ip "$INV")"

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
log_info "Phase 2: Bootstrap initial RKE2 control plane"
log_info "Target node: control-plane-1 (${CP1_IP})"
log_info "RKE2 version: ${RKE2_VERSION}"
separator

# Install and initialize RKE2 on CP1

log_info "Installing RKE2 server on control-plane-1"

ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<EOF
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} sudo sh -
EOF

log_success "RKE2 server package installed on control-plane-1"

separator
log_info "Writing RKE2 cluster-init configuration"
separator

ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<EOF
sudo mkdir -p /etc/rancher/rke2
cat <<CFG | sudo tee /etc/rancher/rke2/config.yaml >/dev/null
cluster-init: true
tls-san:
  - ${LB_PRIVATE_IP}
CFG
EOF

log_success "RKE2 configuration written (cluster-init enabled)"

separator
log_info "Starting rke2-server service"
separator

ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<EOF
sudo systemctl enable rke2-server
sudo systemctl start rke2-server
EOF

log_success "rke2-server started successfully on control-plane-1"

# Phase completion

separator
log_success "Phase 2 completed: Initial RKE2 control plane is up"
separator
