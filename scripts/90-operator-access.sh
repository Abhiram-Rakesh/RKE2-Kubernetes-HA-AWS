#!/usr/bin/env bash
set -euo pipefail

# Phase 6 — Operator kubectl Access (Bastion)

INV="$REPO_ROOT/inventory/inventory.json"
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

BASTION_PUBLIC_IP="$(jq -r .nginx_lb.public_ip "$INV")"
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
log_info "Phase 6: Enabling kubectl access on bastion host"
log_info "Bastion host: ${BASTION_PUBLIC_IP}"
log_info "Source control plane: ${CP1_IP}"
separator

# 1. Install kubectl on bastion

log_info "Ensuring kubectl is installed on bastion"

ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" <<'EOF'
if ! command -v kubectl >/dev/null 2>&1; then
  curl -LO https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
fi
EOF

log_success "kubectl is available on bastion"

# 2. Prepare kubeconfig on control-plane-1

separator
log_info "Preparing kubeconfig on primary control plane"
separator

ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_PUBLIC_IP" \
    ubuntu@"$CP1_IP" <<'EOF'
sudo mkdir -p /home/ubuntu/.kube
sudo cp /etc/rancher/rke2/rke2.yaml /home/ubuntu/.kube/config
sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube
sudo chmod 600 /home/ubuntu/.kube/config
EOF

log_success "kubeconfig prepared on control-plane-1"

# 3. Stream kubeconfig to bastion (SAFE)

separator
log_info "Transferring kubeconfig to bastion"
separator

ssh $SSH_OPTS -i "$KEY" \
    -o ProxyCommand="ssh $SSH_OPTS -i $KEY -W %h:%p ubuntu@$BASTION_PUBLIC_IP" \
    ubuntu@"$CP1_IP" "cat /home/ubuntu/.kube/config" |
    ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" \
        "mkdir -p /home/ubuntu/.kube && cat > /home/ubuntu/.kube/config"

log_success "kubeconfig transferred to bastion"

# 4. Fix permissions on bastion

ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" <<'EOF'
chmod 600 /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
EOF

log_success "kubeconfig permissions set correctly on bastion"

# 5. Rewrite kubeconfig to point to NGINX LB

separator
log_info "Rewriting kubeconfig API endpoint to use NGINX load balancer"
separator

ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" <<'EOF'
sed -i 's|server: https://.*:6443|server: https://127.0.0.1:6443|' /home/ubuntu/.kube/config
EOF

log_success "kubeconfig updated to use local NGINX load balancer"

# 6. Validate operator experience

separator
log_info "Validating kubectl access from bastion"
separator

ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_PUBLIC_IP" <<'EOF'
kubectl get nodes >/dev/null
EOF

log_success "kubectl access validated successfully from bastion"

# Phase completion

separator
log_success "Phase 6 completed: Operator kubectl access is ready"
separator
