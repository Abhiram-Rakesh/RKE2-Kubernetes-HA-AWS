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

# When piped through curl, BASH_SOURCE[0] is empty and ROOT_DIR resolves to
# the current directory — no terraform/ will be present. Clone the repo to
# a fixed location and re-exec so the full project structure is available.
if [[ ! -d "$ROOT_DIR/terraform" ]]; then
    INSTALL_DIR="$HOME/rke2-kubernetes-ha-aws"
    echo "[INFO] Repo not found locally — cloning to $INSTALL_DIR"
    git clone --depth=1 https://github.com/Abhiram-Rakesh/RKE2-Kubernetes-HA-AWS.git "$INSTALL_DIR"
    exec bash "$INSTALL_DIR/install.sh"
fi

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
echo -e "• Ansible-driven cluster bootstrap"
echo -e "• Highly Available RKE2 Kubernetes cluster"
echo -e "• Bastion-host operator access model"
echo
echo -e "This script will:"
echo -e "• Provision all AWS infrastructure via Terraform"
echo -e "• Bootstrap the Kubernetes cluster via Ansible"
echo -e "• Perform end-to-end verification"
echo
echo -e "Built by: ${GREEN}Abhiram${RESET}"
separator

# 1. Prerequisites check

separator
log_info "Checking local prerequisites"
separator

MISSING=0

check_cmd() {
    if command -v "$1" &>/dev/null; then
        log_success "$1 found ($(command -v "$1"))"
    else
        log_error "$1 not found — $2"
        MISSING=1
    fi
}

check_cmd terraform      "Install from https://developer.hashicorp.com/terraform/install"
check_cmd ansible-playbook "Run: pip install ansible"
check_cmd python3        "Install Python 3 via your package manager"
check_cmd aws            "Install from https://aws.amazon.com/cli/"

if [[ $MISSING -eq 1 ]]; then
    log_error "One or more required tools are missing. Please install them and retry."
    exit 1
fi

log_info "Verifying AWS credentials"
if ! aws sts get-caller-identity &>/dev/null; then
    log_error "AWS credentials are not configured or have expired."
    log_error "Run: aws configure  (or export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY)"
    exit 1
fi

log_success "AWS credentials valid ($(aws sts get-caller-identity --query 'Arn' --output text))"

# 3. Ensure scripts are executable

log_info "Ensuring executable permissions on scripts"

chmod +x "$ROOT_DIR/start.sh"
chmod +x "$ROOT_DIR/shutdown.sh"
chmod +x "$ROOT_DIR/ansible/inventory.py"

log_success "Executable permissions verified"

# 4. Terraform init & apply

separator
log_info "Provisioning infrastructure with Terraform"
separator

cd "$ROOT_DIR/terraform"

terraform init
terraform apply -auto-approve

cd "$ROOT_DIR"

log_success "Infrastructure provisioned successfully"

# 5. Bootstrap cluster

separator
log_info "Bootstrapping Kubernetes cluster"
separator

"$ROOT_DIR/start.sh"

# Installation complete

separator
log_success "RKE2 HA cluster installation completed successfully"
log_success "You can now SSH into the bastion and use kubectl"
separator
