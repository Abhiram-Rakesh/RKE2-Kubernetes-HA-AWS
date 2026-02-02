#!/usr/bin/env bash
set -euo pipefail

# Project: RKE2 HA Kubernetes on AWS
# Description:
#   - Destroys all AWS infrastructure provisioned for the cluster
#   - Removes control planes, workers, load balancer, networking
#
# Script: shutdown.sh
# Purpose:
#   - Completely tears down the RKE2 HA cluster
#   - Removes all Terraform-managed resources
#
# ⚠️ WARNING
#   - This action is IRREVERSIBLE
#   - All cluster data will be lost
#
# Built by: Abhiram

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Project banner (destructive warning)

separator
echo -e "${RED}RKE2 HA Kubernetes on AWS — DESTRUCTION MODE${RESET}"
echo -e "${RED}--------------------------------------------${RESET}"
echo -e "${YELLOW}• This script will DESTROY all cluster infrastructure${RESET}"
echo -e "${YELLOW}• All EC2 instances, networking, and state will be removed${RESET}"
echo -e "${YELLOW}• This action CANNOT be undone${RESET}"
echo
echo -e "Built by: ${GREEN}Abhiram${RESET}"
separator

# Destroy infrastructure

log_warn "Destroying entire RKE2 HA cluster and infrastructure"
log_warn "This will remove ALL Terraform-managed resources"

separator
log_info "Running Terraform destroy"
separator

cd "$ROOT_DIR/terraform"

terraform destroy -auto-approve

# Destruction complete

separator
log_success "Infrastructure destroyed successfully"
log_success "All cluster resources have been removed"
separator
