#!/usr/bin/env bash
# =============================================================================
# Phase 4 — Join Worker Nodes
# =============================================================================
# This script joins worker (agent) nodes to the existing RKE2 cluster:
#   1. Retrieve the join token from the first control plane
#   2. For each worker node:
#      - Install RKE2 agent package (not server)
#      - Configure with server URL and token
#      - Start rke2-agent service
#
# Worker nodes run the kubelet and kube-proxy to execute workloads,
# but do not run control plane components or etcd.
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

# Get all worker node IPs from inventory
WORKER_NODES="$(jq -r '.workers[]' "$INV")"

# Get RKE2 version to install (must match control plane nodes)
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
# Phase 4: Join Worker Nodes
# =============================================================================

separator
log_info "Phase 4: Joining worker nodes"
log_info "Primary control plane: ${CP1_IP}"
log_info "Worker targets: ${WORKER_NODES:-none}"
log_info "RKE2 version: ${RKE2_VERSION}"
separator

# -----------------------------------------------------------------------------
# Step 1: Retrieve join token from first control plane
# -----------------------------------------------------------------------------

log_info "Retrieving RKE2 join token from primary control plane"

# The join token is stored on the first control plane after initialization
# Workers use the same token to authenticate with the cluster
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
# Step 2: Join each worker node to the cluster
# -----------------------------------------------------------------------------

# Iterate through all worker nodes
for IP in $WORKER_NODES; do
    separator
    log_info "Joining worker node: ${IP}"
    separator

    # SSH to the worker node via bastion
    # Execute the following on the remote node:
    #   1. Install RKE2 agent package (not server - worker nodes are agents)
    #   2. Create config.yaml with server URL and token
    #   3. Enable and start rke2-agent
    ssh $SSH_OPTS -i "$KEY" \
        -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
        ubuntu@"$IP" <<EOF
# Install RKE2 agent package (rke2-agent, not rke2-server)
# The agent package contains kubelet and kube-proxy but not control plane components
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} sudo sh -

# Create RKE2 configuration directory
sudo mkdir -p /etc/rancher/rke2

# Write configuration to join the cluster
# server: URL of the load balancer (reaches any control plane node)
#         Port 9345 is the RKE2 supervisor API for agent registration
# token: The join token from control-plane-1
cat <<CFG | sudo tee /etc/rancher/rke2/config.yaml >/dev/null
server: https://${LB_PRIVATE_IP}:9345
token: ${TOKEN}
CFG

# Enable and start RKE2 agent service
# This will:
#   1. Register with the Kubernetes API server via the load balancer
#   2. Start kubelet (node agent that runs pods)
#   3. Start kube-proxy (network proxy for services)
#   4. Receive pod specifications from the API server
sudo systemctl enable rke2-agent
sudo systemctl start rke2-agent
EOF

    log_success "Worker node joined successfully: ${IP}"
done

# =============================================================================
# Phase completion
# =============================================================================

separator
log_success "Phase 4 completed: All worker nodes have joined the cluster"
separator
