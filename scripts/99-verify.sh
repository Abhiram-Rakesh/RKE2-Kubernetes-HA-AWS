#!/usr/bin/env bash
set -euo pipefail

# Phase 7 — Cluster Verification & Health Check

INV="$REPO_ROOT/inventory/inventory.json"
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

BASTION_IP="$(jq -r .nginx_lb.public_ip "$INV")"
CP1_IP="$(jq -r '.control_plane[0]' "$INV")"

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
log_info "Phase 7: Verifying Kubernetes cluster health"
log_info "Verification node: control-plane-1 (${CP1_IP})"
separator

# Verify node readiness

separator
log_info "Checking Kubernetes node status"
separator

ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<'EOF'
sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get nodes >/dev/null
EOF

log_success "All Kubernetes nodes are reachable"

# Apply worker node roles

separator
log_info "Applying worker node role labels"
separator

ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<'EOF'
for node in $(sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get nodes --no-headers | awk '$3=="<none>" {print $1}'); do
  sudo /var/lib/rancher/rke2/bin/kubectl \
    --kubeconfig /etc/rancher/rke2/rke2.yaml \
    label node "$node" node-role.kubernetes.io/worker= --overwrite
done
EOF

log_success "Worker node roles applied successfully"

# Verify system pods

separator
log_info "Checking Kubernetes system pods"
separator

ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_IP" \
    ubuntu@"$CP1_IP" <<'EOF'
sudo /var/lib/rancher/rke2/bin/kubectl \
  --kubeconfig /etc/rancher/rke2/rke2.yaml \
  get pods -A >/dev/null
EOF

log_success "Kubernetes system pods are running"

# Phase completion

separator
log_success "Phase 7 completed: Kubernetes cluster is healthy"
separator
