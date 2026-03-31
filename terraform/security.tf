# =============================================================================
# security.tf — Security groups for bastion/LB and private cluster nodes
#
# Two security groups:
#   aws_security_group.nginx   : bastion/NGINX — public-facing inbound rules
#   aws_security_group.private : control plane + workers — locked to nginx SG
# =============================================================================

# Security group for the NGINX bastion / load balancer (public subnet).
# Allows inbound SSH for operator access plus the two ports NGINX proxies
# to the cluster. Unrestricted egress so it can reach the private nodes.
resource "aws_security_group" "nginx" {
  vpc_id = aws_vpc.this.id

  # SSH — operator access from the internet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API server — kubectl and client traffic
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RKE2 supervisor API — node registration and cluster join traffic
  ingress {
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (reaching private nodes, package repos, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for control plane and worker nodes (private subnet).
# No direct internet ingress — traffic must enter through the nginx SG or
# originate from another node in the same security group (cluster-internal).
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.this.id

  # Allow all traffic from the nginx bastion SG (SSH jumps + LB health checks)
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.nginx.id]
  }

  # Allow all intra-cluster traffic (etcd replication, CNI, kubelet, etc.)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # Allow all outbound traffic (package installs via NAT, image pulls, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
