#!/usr/bin/env bash
# =============================================================================
# Phase 6 — Operator kubectl Access (Bastion)
# =============================================================================
# This script sets up kubectl access on the bastion host so operators can
# manage the Kubernetes cluster from there:
#   1. Install kubectl on the bastion (if not already installed)
#   2. Copy kubeconfig from control-plane-1 to bastion
#   3. Modify kubeconfig to point to the local NGINX load balancer
#   4. Validate kubectl works
#
# This allows operators to run kubectl commands from the bastion without
# needing to SSH into control plane nodes directly.
# =============================================================================

set -euo pipefail

# Load inventory for configuration
INV="$REPO_ROOT/inventory/inventory.json"

# Resolve SSH key path
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

# Get bastion public IP (accessible from the internet)
BASTION_PUBLIC_IP="$(jq -r .nginx_lb.public_ip "$INV")"

# Get first control plane IP - source of the kubeconfig
CP1_IP="$(jq -r '.control_plane[0]' "$INV")"

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
# Phase 6: Enable kubectl Access on Bastion
# =============================================================================

separator
log_info "Phase 6: Enabling kubectl access on bastion host"
log_info "Bastion host: ${BASTION_PUBLIC_IP}"
log_info "Source control plane: ${CP1_IP}"
separator

# -----------------------------------------------------------------------------
# Step 1: Install kubectl on bastion
# -----------------------------------------------------------------------------

log_info "Ensuring kubectl is installed on bastion"

# Check if kubectl is already installed; if not, download and install it
# kubectl is the Kubernetes command-line tool for cluster management
ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" <<'EOF'
# Check if kubectl is already available
if ! command -v kubectl >/dev/null 2>&1; then
  # Download the latest stable kubectl binary from Kubernetes releases
  # curl -LO: Download file, keep original filename
  curl -LO https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
  
  # Make it executable
  chmod +x kubectl
  
  # Move to system PATH so it can be run from anywhere
  sudo mv kubectl /usr/local/bin/kubectl
fi
EOF

log_success "kubectl is available on bastion"

# -----------------------------------------------------------------------------
# Step 2: Prepare kubeconfig on control-plane-1
# -----------------------------------------------------------------------------

separator
log_info "Preparing kubeconfig on primary control plane"
separator

# The kubeconfig contains credentials and endpoint information to access the cluster
# RKE2 generates it at /etc/rancher/rke2/rke2.yaml on the control plane
# We need to copy it to a user-accessible location with proper permissions
ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_PUBLIC_IP" \
    ubuntu@"$CP1_IP" <<'EOF'
# Create .kube directory in user's home
sudo mkdir -p /home/ubuntu/.kube

# Copy the generated kubeconfig to user's .kube directory
# /etc/rancher/rke2/rke2.yaml is the default kubeconfig location for RKE2
sudo cp /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/config

# Change ownership to the ubuntu user (so they can read it)
sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Set restrictive permissions (owner read/write only)
# This is required by kubectl - it will refuse to use kubeconfig that's too open
sudo chmod 600 /home/ubuntu/.kube/config
EOF

log_success "kubeconfig prepared on control-plane-1"

# -----------------------------------------------------------------------------
# Step 3: Transfer kubeconfig to bastion
# -----------------------------------------------------------------------------

separator
log_info "Transferring kubeconfig to bastion"
separator

# Stream the kubeconfig file from control-plane-1 through bastion to bastion's ~/.kube/
# This uses SSH piping to avoid storing credentials on disk during transfer
# The kubeconfig contains client certificates for authentication
ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_PUBLIC_IP" \
    ubuntu@"$CP1_IP" "cat /home/ubuntu/.kube/config" |
    ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" \
        "mkdir -p /home/ubuntu/.kube && cat > /home/ubuntu/.kube/config"

log_success "kubeconfig transferred to bastion"

# -----------------------------------------------------------------------------
# Step 4: Fix permissions on bastion
# -----------------------------------------------------------------------------

# Ensure the kubeconfig has correct permissions on the bastion
ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" <<'EOF'
# Set restrictive permissions (owner read/write only)
chmod 600 /home/ubuntu/.kube/config

# Fix ownership to ubuntu user
chown ubuntu:ubuntu /home/ubuntu/.kube/config
EOF

log_success "kubeconfig permissions set correctly on bastion"

# -----------------------------------------------------------------------------
# Step 5: Rewrite kubeconfig to point to NGINX LB
# -----------------------------------------------------------------------------

separator
log_info "Rewriting kubeconfig API endpoint to use NGINX load balancer"
separator

# The original kubeconfig points to the first control plane IP directly
# We need to change it to point to localhost:6443 (where NGINX is listening)
# NGINX will then forward to the actual control plane nodes
ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" <<'EOF'
# Replace the server URL in kubeconfig to use localhost instead of control plane IP
# Original: server: https://<control-plane-ip>:6443
# New:      server: https://127.0.0.1:6443
# This allows kubectl to connect to the local NGINX, which load balances to control planes
sed -i 's|server: https://.*:6443|server: https://127.0.0.1:6443|' /home/ubuntu/.kube/config
EOF

log_success "kubeconfig updated to use local NGINX load balancer"

# -----------------------------------------------------------------------------
# Step 6: Validate kubectl access
# -----------------------------------------------------------------------------

separator
log_info "Validating kubectl access from bastion"
separator

# Test that kubectl can successfully connect to the cluster
# This verifies the kubeconfig is valid and the cluster is accessible
ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" <<'EOF'
# Get nodes to verify cluster connectivity and authentication
# If this succeeds, kubectl is properly configured
kubectl get nodes >/dev/null
EOF

log_success "kubectl access validated successfully from bastion"

# =============================================================================
# Phase completion
# =============================================================================

separator
log_success "Phase 6 completed: Operator kubectl access is ready"
separator
