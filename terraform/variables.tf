# =============================================================================
# variables.tf — Input variables for the RKE2 HA cluster
#
# Override defaults by passing -var flags, a .tfvars file, or environment
# variables (TF_VAR_<name>) at plan/apply time.
# =============================================================================

# AWS region where all resources are deployed.
# Defaults to ap-south-1 (Mumbai). Change this to deploy in another region.
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

# Short name for this project, used to namespace resource names and tags
# (e.g., the SSH key pair is named "<project_name>-key").
variable "project_name" {
  type    = string
  default = "rke2-ha-poc"
}

# RKE2 release to install on all nodes. The version string must match the
# tag format used by the official RKE2 installer (e.g. v1.29.3+rke2r1).
# This value is also passed through to Ansible via the inventory JSON file.
variable "rke2_version" {
  type    = string
  default = "v1.29.3+rke2r1"
}
