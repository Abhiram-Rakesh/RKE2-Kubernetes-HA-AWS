# =============================================================================
# outputs.tf — Terraform outputs for quick reference after apply
#
# These values are printed to the terminal after `terraform apply` and can
# also be read by external tooling via `terraform output -json`.
# =============================================================================

# Public IP of the NGINX bastion — use this to SSH in or reach the K8s API.
output "nginx_public_ip" {
  value = aws_instance.nginx.public_ip
}

# Private IPs of all control plane nodes — useful for direct SSH via bastion.
output "control_plane_ips" {
  value = aws_instance.control_plane[*].private_ip
}

# Private IPs of all worker nodes.
output "worker_ips" {
  value = aws_instance.worker[*].private_ip
}

# Local path to the generated SSH private key file (terraform/ssh_key.pem).
output "ssh_key_path" {
  value = local_file.private_key.filename
}
