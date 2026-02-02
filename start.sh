#!/usr/bin/env bash
set -euo pipefail

# Project: RKE2 HA Kubernetes on AWS
# Description:
#   - Bootstraps a Highly Available RKE2 cluster
#   - Uses pre-provisioned AWS infrastructure
#   - Executes all bootstrap phases in order
#
# Script: start.sh
# Purpose:
#   - Runs all cluster bootstrap scripts
#   - Assumes Terraform infrastructure already exists
#   - Fails fast on any error
#
# Built by: Abhiram

export SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INV="$REPO_ROOT/inventory/inventory.json"

# Logging helpers

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

# Project banner

separator
echo -e "${BLUE}RKE2 HA Kubernetes on AWS${RESET}"
echo -e "${BLUE}--------------------------------------------${RESET}"
echo -e "• Executes full Kubernetes cluster bootstrap"
echo -e "• Initializes control planes and workers"
echo -e "• Configures load balancer and operator access"
echo
echo -e "This script will:"
echo -e "• Run all bootstrap phases in order"
echo -e "• Validate cluster health"
echo -e "• Exit immediately on failure"
echo
echo -e "Built by: ${GREEN}Abhiram${RESET}"
separator

# Inventory validation

if [[ ! -f "$INV" ]]; then
    log_error "inventory.json not found"
    log_error "Run install.sh first to provision infrastructure"
    exit 1
fi

export REPO_ROOT
export INV

log_success "Inventory file detected"

# Execute bootstrap phases

separator
log_info "Starting Kubernetes cluster bootstrap"
separator

for script in "$REPO_ROOT"/scripts/*.sh; do
    log_info "Executing phase: $(basename "$script")"
    bash "$script"
done

# Bootstrap complete

separator
log_success "Cluster bootstrap completed successfully"
log_success "Kubernetes cluster is ready for use"
separator
