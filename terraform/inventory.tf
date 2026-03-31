# =============================================================================
# inventory.tf — Generate Ansible inventory from Terraform outputs
#
# After `terraform apply`, this writes a JSON file that the dynamic Ansible
# inventory script (ansible/inventory.py) reads to build its host groups.
# Keeping inventory generation here ensures the IP addresses, SSH key path,
# and RKE2 version stay in sync with the infrastructure Terraform manages.
# =============================================================================

# Write a JSON inventory file to ../inventory/inventory.json.
# The Ansible inventory script reads this file at runtime to populate groups:
#   nginx_lb      — public + private IPs of the bastion/LB
#   control_plane — private IPs of all control plane nodes
#   workers       — private IPs of all worker nodes
#   ssh_key       — absolute path to the generated SSH private key
#   rke2_version  — version string passed through to the Ansible group_vars
resource "local_file" "inventory" {
  filename = "${path.module}/../inventory/inventory.json"

  content = jsonencode({
    nginx_lb = {
      public_ip  = aws_instance.nginx.public_ip
      private_ip = aws_instance.nginx.private_ip
    }
    control_plane = aws_instance.control_plane[*].private_ip
    workers       = aws_instance.worker[*].private_ip
    ssh_key       = abspath(local_file.private_key.filename)
    rke2_version  = var.rke2_version
  })
}
