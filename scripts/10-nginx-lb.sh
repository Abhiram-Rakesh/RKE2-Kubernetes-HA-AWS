#!/usr/bin/env bash
# =============================================================================
# Phase 1 — NGINX Load Balancer Setup
# =============================================================================
# This script configures the NGINX load balancer on the bastion host to:
#   1. Install NGINX with stream module (for TCP proxying)
#   2. Configure TCP load balancing for:
#      - Kubernetes API server (port 6443)
#      - RKE2 supervisor API (port 9345) - needed for node join operations
#   3. Start NGINX and validate configuration
# =============================================================================

set -euo pipefail

# Load inventory for configuration
INV="$REPO_ROOT/inventory/inventory.json"

# Resolve SSH key path
KEY="$(realpath "$(jq -r .ssh_key "$INV")")"

# Get NGINX load balancer (bastion) public IP
BASTION_IP=$(jq -r .nginx_lb.public_ip "$INV")

# Get all control plane IPs - will be used as upstream servers
CONTROL_PLANES=$(jq -r '.control_plane[]' "$INV")

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
# Phase 1: NGINX Load Balancer Setup
# =============================================================================

separator
log_info "Phase 1: Configuring NGINX Load Balancer"
log_info "Target node: NGINX LB (${BASTION_IP})"
separator

# -----------------------------------------------------------------------------
# Step 1: Install NGINX and stream module on bastion
# -----------------------------------------------------------------------------
# The stream module enables NGINX to proxy TCP connections (not just HTTP)
# This is required because Kubernetes API uses raw TCP, not HTTP

log_info "Installing NGINX and stream module"

# SSH directly to bastion (it's publicly accessible)
# Install nginx and the stream module package
ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_IP" <<EOF
# Update package lists
sudo apt-get update -y

# Install nginx and the stream module for TCP proxying
# nginx: web server / load balancer
# libnginx-mod-stream: module for TCP/UDP proxying
sudo apt-get install -y nginx libnginx-mod-stream
EOF

log_success "NGINX packages installed"

# -----------------------------------------------------------------------------
# Step 2: Configure NGINX for TCP load balancing
# -----------------------------------------------------------------------------

separator
log_info "Rendering NGINX TCP load balancer configuration"
separator

# Write NGINX configuration to /etc/nginx/nginx.conf
# This configures two TCP upstream backends:
#   1. k8s_api: Round-robins Kubernetes API requests across control planes (port 6443)
#   2. rke2_supervisor: Round-robins RKE2 supervisor requests (port 9345)
# The supervisor port is needed during node join operations
ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_IP" <<EOF
# Create NGINX configuration file with stream module
# The stream block handles TCP (layer 4) proxying
cat <<'NGINX' | sudo tee /etc/nginx/nginx.conf >/dev/null
# Load the stream module for TCP/UDP proxying
load_module modules/ngx_stream_module.so;

# NGINX process configuration
user www-data;
worker_processes auto;
pid /run/nginx.pid;

# Event processing configuration
events {
  worker_connections 1024;  # Max concurrent connections per worker
}

# Stream block for TCP/UDP proxying
stream {
  # Upstream backend for Kubernetes API server
  # All control plane nodes run the API server on port 6443
  upstream k8s_api {
$(for ip in $CONTROL_PLANES; do echo "    server $ip:6443;"; done)
  }

  # Upstream backend for RKE2 supervisor API
  # This port is used during node join operations and for cluster management
  # Each control plane runs the supervisor on port 9345
  upstream rke2_supervisor {
$(for ip in $CONTROL_PLANES; do echo "    server $ip:9345;"; done)
  }

  # Server block: Listen on port 6443 and proxy to k8s_api upstream
  server {
    listen 6443;
    proxy_pass k8s_api;
  }

  # Server block: Listen on port 9345 and proxy to rke2_supervisor upstream
  server {
    listen 9345;
    proxy_pass rke2_supervisor;
  }
}
NGINX
EOF

log_success "NGINX configuration written"

# -----------------------------------------------------------------------------
# Step 3: Validate and restart NGINX
# -----------------------------------------------------------------------------

separator
log_info "Validating and restarting NGINX"
separator

# Test NGINX configuration for syntax errors, then restart the service
# nginx -t: Check configuration syntax
# systemctl restart: Apply new configuration
ssh $SSH_OPTS -i "$KEY" ubuntu@"$BASTION_IP" <<EOF
# Validate NGINX configuration for syntax errors
sudo nginx -t

# Restart NGINX to apply the new configuration
sudo systemctl restart nginx
EOF

log_success "NGINX is running and load balancer ports are active"

separator
log_success "Phase 1 completed: NGINX Load Balancer ready"
separator
