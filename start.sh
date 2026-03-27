#!/usr/bin/env bash
set -euo pipefail

# Project: RKE2 HA Kubernetes on AWS
# Description:
#   - Bootstraps a Highly Available RKE2 cluster using Ansible
#   - Uses pre-provisioned AWS infrastructure (Terraform must have run first)
#
# Script: start.sh
# Purpose:
#   - Validates that Terraform inventory exists
#   - Runs the Ansible playbook to bootstrap the full cluster
#
# Built by: Abhiram

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INV="$REPO_ROOT/inventory/inventory.json"

# Logging helpers

BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

log_info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

separator() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${RESET}"
}

# Project banner

separator
echo -e "${BLUE}RKE2 HA Kubernetes on AWS${RESET}"
echo -e "${BLUE}--------------------------------------------${RESET}"
echo -e "• Ansible-driven cluster bootstrap"
echo -e "• Initializes control planes and workers"
echo -e "• Configures load balancer and operator access"
echo
echo -e "This script will:"
echo -e "• Run all Ansible playbook phases in order"
echo -e "• Validate cluster health"
echo -e "• Exit immediately on failure"
echo
echo -e "Built by: ${GREEN}Abhiram${RESET}"
separator

# Prerequisite check

if ! command -v ansible-playbook &>/dev/null; then
    log_error "ansible-playbook not found — install Ansible first:"
    log_error "  pip install ansible"
    exit 1
fi

# Inventory validation

if [[ ! -f "$INV" ]]; then
    log_error "inventory/inventory.json not found"
    log_error "Run install.sh first to provision infrastructure with Terraform"
    exit 1
fi

log_success "Inventory file detected"

# Make the dynamic inventory executable

chmod +x "$REPO_ROOT/ansible/inventory.py"

# Run Ansible

separator
log_info "Starting Kubernetes cluster bootstrap via Ansible"
separator

cd "$REPO_ROOT/ansible"
ansible-playbook site.yml

# Bootstrap complete

separator
log_success "Cluster bootstrap completed successfully"
log_success "Kubernetes cluster is ready for use"
separator
