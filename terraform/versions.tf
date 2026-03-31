# =============================================================================
# versions.tf — Terraform and provider version constraints
#
# Pin versions here to ensure consistent behaviour across team members and
# CI runs. Update these when deliberately upgrading providers.
# =============================================================================

terraform {
  # Require Terraform 1.5+ for features used in this configuration
  # (e.g., import blocks, check blocks).
  required_version = ">= 1.5.0"

  required_providers {
    # AWS provider — manages all AWS resources (VPC, EC2, SGs, etc.)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider with the region from variables.
# Credentials are sourced from the standard AWS credential chain
# (env vars, ~/.aws/credentials, instance profile, etc.).
provider "aws" {
  region = var.aws_region
}
