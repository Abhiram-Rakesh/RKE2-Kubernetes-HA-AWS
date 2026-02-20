#!/usr/bin/env bash
# =============================================================================
# Phase 2 — Bootstrap Initial RKE2 Control Plane
# =============================================================================
# This script bootstraps the first control plane node (control-plane-1) with:
#   1. Install RKE2 server package
#   2. Configure RKE2 with cluster-init mode (initializes embedded etcd)
#   3. Add TLS SAN for the load balancer IP
#   4. Start the rke2-server service
#
# The cluster-init flag tells RKE2 to initialize a new cluster with embedded
# etcd (distributed database) - this forms the foundation for HA.
# =============================================================================

set -euo pipefail

# Load inventory for configuration
INV="$REPO_ROOT/inventory/inventory.json"

# Resolve SSH key path
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

# Get bastion (jump host) public IP for SSH tunneling
BASTION_IP="$(jq -r .nginx_lb.public_ip "$INV")"

# Get the first control plane IP - this will be the initial node
CP1_IP="$(jq -r '.control_plane[0]' "$INV")"

# Get RKE2 version to install (from inventory)
RKE2_VERSION="$(jq -r .rke2_version "$INV")"

# Get NGINX load balancer private IP - used as TLS SAN
# This allows the API server to be accessed via the load balancer
LB_PRIVATE_IP="$(jq -r .nginx_lb.private_ip "$INV")"

# =============================================================================
# Logging helpers (pure Bash)
# =============================================================================
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

# =============================================================================
# Phase 2: Bootstrap Initial RKE2 Control Plane
# =============================================================================

separator
log_info "Phase 2: Bootstrap initial RKE2 control plane"
log_info "Target node: control-plane-1 (${CP1_IP})"
log_info "RKE2 version: ${RKE2_VERSION}"
separator

# -----------------------------------------------------------------------------
# Step 1: Install RKE2 server package on control-plane-1
# -----------------------------------------------------------------------------

log_info "Installing RKE2 server on control-plane-1"

# SSH to control-plane-1 via bastion jump host
# Use ProxyCommand to tunnel SSH through the bastion (required for private subnet)
# Install RKE2 using the official installer script
# curl -sfL: Silent download, follow redirects, fail silently on errors
# https://get.rke2.io: Official RKE2 installation script
# INSTALL_RKE2_VERSION: Environment variable to specify version
ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<EOF
# Download and execute the official RKE2 installer
# This installs the rke2-server binary and related components
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} sudo sh -
EOF

log_success "RKE2 server package installed on control-plane-1"

# -----------------------------------------------------------------------------
# Step 2: Configure RKE2 with cluster-init
# -----------------------------------------------------------------------------

separator
log_info "Writing RKE2 cluster-init configuration"
separator

# Create RKE2 configuration directory and write config.yaml
# The config.yaml controls how RKE2 starts and joins the cluster
ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<EOF
# Create RKE2 configuration directory
sudo mkdir -p /etc/rancher/rke2

# Write RKE2 configuration
# cluster-init: true - Initialize as the first node in a new cluster
#               This starts embedded etcd in bootstrap mode
# tls-san: Additional IP addresses to include in the API server TLS certificate
#          Adding the load balancer private IP allows kubectl access via LB
cat <<CFG | sudo tee /etc/rancher/rke2/config.yaml >/dev/null
cluster-init: true
tls-san:
  - ${LB_PRIVATE_IP}
CFG
EOF

log_success "RKE2 configuration written (cluster-init enabled)"

# -----------------------------------------------------------------------------
# Step 3: Start RKE2 server service
# -----------------------------------------------------------------------------

separator
log_info "Starting rke2-server service"
separator

# Enable and start the rke2-server systemd service
# systemctl enable: Start service on boot
# systemctl start: Start service immediately
ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<EOF
# Enable rke2-server to start on boot
sudo systemctl enable rke2-server

# Start the RKE2 server service immediately
# This will:
#   1. Initialize embedded etcd cluster
#   2. Start Kubernetes API server on port 6443
#   3. Start RKE2 supervisor on port 9345
#   4. Start kubelet, kube-proxy, and other control plane components
sudo systemctl start rke2-server
EOF

log_success "rke2-server started successfully on control-plane-1"

# =============================================================================
# Phase completion
# =============================================================================

separator
log_success "Phase 2 completed: Initial RKE2 control plane is up"
separator
