# =============================================================================
# ssh.tf — SSH key pair generation and registration
#
# Generates a fresh RSA key pair on every `terraform apply` (if not yet in
# state), writes the private key to disk, and registers the public key with
# AWS so it can be attached to EC2 instances at launch.
# =============================================================================

# Generate a 4096-bit RSA private key in Terraform state.
# The key is stored in the state file — ensure state is stored securely
# (e.g., encrypted S3 backend) in production environments.
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Write the private key PEM to terraform/ssh_key.pem with mode 0600
# so it can be used directly with `ssh -i` or referenced by Ansible.
resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/ssh_key.pem"
  file_permission = "0600"
}

# Register the corresponding public key with AWS under a named key pair.
# EC2 instances reference this key pair by name so AWS injects the public
# key into ~/.ssh/authorized_keys via cloud-init on first boot.
resource "aws_key_pair" "ssh" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}
