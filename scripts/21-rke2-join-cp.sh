#!/usr/bin/env bash
# =============================================================================
# Phase 3 — Join Remaining Control Plane Nodes
# =============================================================================
# This script joins additional control plane nodes to the existing cluster:
#   1. Retrieve the join token from the first control plane
#   2. For each remaining control plane node:
#      - Install RKE2 server package
#      - Configure with server URL and token
#      - Start rke2-server service
#
# The new nodes will connect to the existing etcd cluster and form a HA control plane.
# =============================================================================

set -euo pipefail

# Load inventory for configuration
INV="$REPO_ROOT/inventory/inventory.json"

# Resolve SSH key path
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

# Get bastion public IP for SSH tunneling
BASTION_IP="$(jq -r .nginx_lb.public_ip "$INV")"

# Get load balancer private IP - used as the server URL for joining
LB_PRIVATE_IP="$(jq -r .nginx_lb.private_ip "$INV")"

# Get first control plane IP - where to fetch the join token from
CP1_IP="$(jq -r '.control_plane[0]' "$INV")"

# Get remaining control plane IPs (excluding the first one)
# These nodes will join the existing cluster
JOIN_NODES="$(jq -r '.control_plane[1:][]' "$INV")"

# Get RKE2 version to install (must match the first control plane)
RKE2_VERSION="$(jq -r .rke2_version "$INV")"

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
# Phase 3: Join Remaining Control Plane Nodes
# =============================================================================

separator
log_info "Phase 3: Joining remaining control plane nodes"
log_info "Primary control plane: ${CP1_IP}"
log_info "Join targets: ${JOIN_NODES:-none}"
log_info "RKE2 version: ${RKE2_VERSION}"
separator

# -----------------------------------------------------------------------------
# Step 1: Retrieve join token from first control plane
# -----------------------------------------------------------------------------

log_info "Retrieving RKE2 join token from primary control plane"

# The join token is stored on the first control plane after initialization
# This token is required for other nodes to join the cluster
# Format: K10<uuid>::<password>
TOKEN="$(ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" \
    sudo cat /var/lib/rancher/rke2/server/node-token)"

# Validate that we got a token
if [[ -z "$TOKEN" ]]; then
    log_error "Failed to retrieve RKE2 join token from control-plane-1"
    exit 1
fi

log_success "RKE2 join token retrieved successfully"

# -----------------------------------------------------------------------------
# Step 2: Join each remaining control plane node
# -----------------------------------------------------------------------------

# Iterate through remaining control plane nodes
for IP in $JOIN_NODES; do
    separator
    log_info "Joining control plane node: ${IP}"
    separator

    # SSH to the new control plane node via bastion
    # Execute the following on the remote node:
    #   1. Install RKE2 server package
    #   2. Create config.yaml with server URL and token
    #   3. Enable and start rke2-server
    ssh $SSH_OPTS -i "$KEY" \
        -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
        ubuntu@"$IP" <<EOF
# Install RKE2 server package (same version as first control plane)
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} sudo sh -

# Create RKE2 configuration directory
sudo mkdir -p /etc/rancher/rke2

# Write configuration to join the cluster
# server: URL of an existing control plane node (via load balancer)
#         The supervisor API port 9345 is used for cluster communication
# token: The join token retrieved from control-plane-1
#         This authenticates the node and grants it access to the cluster
cat <<CFG | sudo tee /etc/rancher/rke2/config.yaml >/dev/null
server: https://${LB_PRIVATE_IP}:9345
token: ${TOKEN}
CFG

# Enable and start RKE2 server service
# This will:
#   1. Connect to the existing etcd cluster
#   2. Retrieve cluster state and certificates
#   3. Start the API server, controller manager, scheduler
#   4. Join the etcd cluster as a voting member
sudo systemctl enable rke2-server
sudo systemctl start rke2-server
EOF

    log_success "Control plane node joined successfully: ${IP}"
done

# =============================================================================
# Phase completion
# =============================================================================

separator
log_success "Phase 3 completed: All control plane nodes have joined the cluster"
separator
