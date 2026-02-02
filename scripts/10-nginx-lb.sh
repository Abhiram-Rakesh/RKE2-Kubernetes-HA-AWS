#!/usr/bin/env bash
set -euo pipefail

# Phase 1 — NGINX Load Balancer Setup

INV="$REPO_ROOT/inventory/inventory.json"
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"
BASTION_IP=$(jq -r .nginx_lb.public_ip "$INV")
CONTROL_PLANES=$(jq -r '.control_plane[]' "$INV")

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
log_info "Phase 1: Configuring NGINX Load Balancer"
log_info "Target node: NGINX LB (${BASTION_IP})"
separator

# Execute on bastion

log_info "Installing NGINX and stream module"

ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_IP" <<EOF
sudo apt-get update -y
sudo apt-get install -y nginx libnginx-mod-stream
EOF

log_success "NGINX packages installed"

separator
log_info "Rendering NGINX TCP load balancer configuration"
separator

ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_IP" <<EOF
cat <<'NGINX' | sudo tee /etc/nginx/nginx.conf >/dev/null
load_module modules/ngx_stream_module.so;

user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
  worker_connections 1024;
}

stream {
  upstream k8s_api {
$(for ip in $CONTROL_PLANES; do echo "    server $ip:6443;"; done)
  }

  upstream rke2_supervisor {
$(for ip in $CONTROL_PLANES; do echo "    server $ip:9345;"; done)
  }

  server {
    listen 6443;
    proxy_pass k8s_api;
  }

  server {
    listen 9345;
    proxy_pass rke2_supervisor;
  }
}
NGINX
EOF

log_success "NGINX configuration written"

separator
log_info "Validating and restarting NGINX"
separator

ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_IP" <<EOF
sudo nginx -t
sudo systemctl restart nginx
EOF

log_success "NGINX is running and load balancer ports are active"

separator
log_success "Phase 1 completed: NGINX Load Balancer ready"
separator
