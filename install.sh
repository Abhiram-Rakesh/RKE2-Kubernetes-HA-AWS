#!/usr/bin/env bash
set -euo pipefail

############################################
# Project: RKE2 HA Kubernetes on AWS
# Description:
#   - Provisions AWS infrastructure using Terraform
#   - Bootstraps a Highly Available RKE2 Kubernetes cluster
#   - Configures bastion-based operator access
#
# Script: install.sh
# Purpose:
#   - One-command installation entrypoint
#   - Runs Terraform init & apply
#   - Executes full cluster bootstrap
#
# Built by: Abhiram
############################################

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

############################################
# Logging helpers
############################################

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

############################################
# Project banner
############################################

separator
echo -e "${BLUE}RKE2 HA Kubernetes on AWS${RESET}"
echo -e "${BLUE}--------------------------------------------${RESET}"
echo -e "• Terraform-based AWS infrastructure"
echo -e "• Highly Available RKE2 Kubernetes cluster"
echo -e "• Bastion-host operator access model"
echo
echo -e "This script will:"
echo -e "• Provision all infrastructure"
echo -e "• Bootstrap the Kubernetes cluster"
echo -e "• Perform end-to-end verification"
echo
echo -e "Built by: ${GREEN}Abhiram${RESET}"
separator

# 1. Ensure scripts are executable

log_info "Ensuring executable permissions on bootstrap scripts"

chmod +x "$ROOT_DIR"/scripts/*.sh
chmod +x "$ROOT_DIR"/start.sh
chmod +x "$ROOT_DIR"/shutdown.sh

log_success "Executable permissions verified"

# 2. Terraform init & apply

separator
log_info "Provisioning infrastructure with Terraform"
separator

cd "$ROOT_DIR/terraform"

terraform init
terraform apply -auto-approve

cd "$ROOT_DIR"

log_success "Infrastructure provisioned successfully"

# 3. Bootstrap cluster

separator
log_info "Bootstrapping Kubernetes cluster"
separator

"$ROOT_DIR/start.sh"

# Installation complete

separator
log_success "RKE2 HA cluster installation completed successfully"
log_success "You can now SSH into the bastion and use kubectl"
separator
