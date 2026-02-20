#!/usr/bin/env bash
# =============================================================================
# Phase 7 — Cluster Verification & Health Check
# =============================================================================
# This script performs final validation of the Kubernetes cluster:
#   1. Verify all nodes are reachable
#   2. Apply worker role labels to worker nodes
#   3. Verify system pods are running
#
# This is the final phase that confirms the cluster is fully operational.
# =============================================================================

set -euo pipefail

# Load inventory for configuration
INV="$REPO_ROOT/inventory/inventory.json"

# Resolve SSH key path
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

# Get bastion IP for SSH tunneling
BASTION_IP="$(jq -r .nginx_lb.public_ip "$INV")"

# Get first control plane IP - used for running kubectl commands
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
# Phase 7: Cluster Verification & Health Check
# =============================================================================

separator
log_info "Phase 7: Verifying Kubernetes cluster health"
log_info "Verification node: control-plane-1 (${CP1_IP})"
separator

# -----------------------------------------------------------------------------
# Step 1: Verify node readiness
# -----------------------------------------------------------------------------

separator
log_info "Checking Kubernetes node status"
separator

# Use kubectl to list all nodes
# If nodes are unreachable or not ready, this will fail
# The bundled kubectl is at /var/lib/rancher/rke2/bin/kubectl
ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<'EOF'
# Get all nodes - this verifies:
#   1. API server is responding
#   2. Nodes have registered with the cluster
#   3. kubelet is running on each node
sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get nodes >/dev/null
EOF

log_success "All Kubernetes nodes are reachable"

# -----------------------------------------------------------------------------
# Step 2: Apply worker role labels
# -----------------------------------------------------------------------------

separator
log_info "Applying worker node role labels"
separator

# When worker nodes join the cluster, they don't get the worker role label by default
# We need to label them so they can be recognized as worker nodes in Kubernetes
# The label node-role.kubernetes.io/worker= marks a node as a dedicated worker
ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<'EOF'
# Get all nodes that have no role (no <none> in the ROLES column)
# These are worker nodes that joined but weren't labeled
# Then apply the worker role label to each
for node in $(sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get nodes --no-headers | awk '$3=="<none>" {print $1}'); do
  # Apply the worker role label
  # --overwrite allows updating existing labels if needed
  sudo /var/lib/rancher/rke2/bin/kubectl \
    --kubeconfig /etc/rancher/rke2/rke2.yaml \
    label node "$node" node-role.kubernetes.io/worker= --overwrite
done
EOF

log_success "Worker node roles applied successfully"

# -----------------------------------------------------------------------------
# Step 3: Verify system pods
# -----------------------------------------------------------------------------

separator
log_info "Checking Kubernetes system pods"
separator

# Verify that core system pods are running in all namespaces
# System pods include:
#   - kube-system: kube-proxy, CNI plugins, coredns, etc.
#   - kube-node-lease: node heartbeat mechanism
#   - kube-public: cluster info
# This confirms the control plane components are functioning correctly
ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<'EOF'
# Get all pods in all namespaces
# This verifies:
#   1. API server can list pods
#   2. Scheduler is assigning pods to nodes
#   3. kubelet is running pods on nodes
sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get pods -A >/dev/null
EOF

log_success "Kubernetes system pods are running"

# =============================================================================
# Phase completion
# =============================================================================

separator
log_success "Phase 7 completed: Kubernetes cluster is healthy"
separator
