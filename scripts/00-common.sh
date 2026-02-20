#!/usr/bin/env bash
# =============================================================================
# Phase 0 — Common Node Preparation
# =============================================================================
# This script prepares all nodes (control plane + workers) with the basic
# requirements for RKE2:
#   1. Disables swap (required for Kubernetes)
#   2. Updates package lists
#   3. Installs curl and jq (needed for installation scripts and JSON parsing)
# =============================================================================

set -euo pipefail

# Load inventory to get node IP addresses and SSH key path
INV="$REPO_ROOT/inventory/inventory.json"

# Resolve absolute path to the SSH private key used for node access
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

# Get the NGINX load balancer (bastion) public IP - used as SSH jump host
BASTION_IP="$(jq -r .nginx_lb.public_ip "$INV")"

# Get all control plane and worker node IPs combined
# This will be used to iterate and prepare each node
ALL_NODES="$(jq -r '.control_plane[], .workers[]' "$INV")"

# =============================================================================
# Logging helpers (pure Bash - no external dependencies)
# =============================================================================
# ANSI color codes for colored output in terminal
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# log_info: Blue colored info messages
log_info() { echo -e "${BLUE}[INFO]${RESET} $1"; }

# log_warn: Yellow colored warning messages
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }

# log_error: Red colored error messages
log_error() { echo -e "${RED}[ERROR]${RESET} $1"; }

# log_success: Green colored success messages
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

# separator: Prints a visual divider line for better output readability
separator() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${RESET}"
}

# =============================================================================
# Phase 0: Common Node Preparation
# =============================================================================

separator
log_info "Phase 0: Common node preparation"
log_info "Target nodes: control planes + workers"
separator

# Iterate through each node (control planes + workers) and prepare them
for IP in $ALL_NODES; do
    separator
    log_info "Preparing node: ${IP}"
    separator

    # SSH into each node via the bastion (ProxyCommand tunnels through BASTION_IP)
    # This is required because control plane and worker nodes are in private subnets
    # Commands executed on remote node:
    #   1. swapoff -a: Disable swap immediately (Kubernetes requires no swap)
    #   2. sed -i: Comment out swap entries in /etc/fstab to prevent swap on reboot
    #   3. apt-get update: Update package lists
    #   4. apt-get install: Install curl (for downloading RKE2) and jq (for JSON parsing)
    ssh $SSH_OPTS -i "$KEY" \
        -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
        ubuntu@"$IP" <<'EOF'
# Disable swap immediately (required for Kubernetes)
sudo swapoff -a

# Comment out swap entries in fstab to prevent swap on reboot
# This ensures swap stays disabled after node restarts
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Update package lists from apt repositories
sudo apt-get update -y

# Install curl (needed to download RKE2 installer) and jq (needed for JSON parsing)
sudo apt-get install -y curl jq
EOF

    log_success "Node prepared successfully: ${IP}"
done

# =============================================================================
# Phase completion
# =============================================================================

separator
log_success "Phase 0 completed: Common node preparation successful"
separator
