# =============================================================================
# compute.tf — EC2 instances for the RKE2 cluster
#
# Resources:
#   - data.aws_ami.ubuntu        : latest Ubuntu 22.04 LTS AMI from Canonical
#   - aws_instance.nginx         : bastion / NGINX load balancer (public subnet)
#   - aws_instance.control_plane : 3 RKE2 control plane nodes  (private subnet)
#   - aws_instance.worker        : worker (agent) nodes         (private subnet)
# =============================================================================

# Look up the most recent Ubuntu 22.04 LTS (Jammy) x86-64 HVM AMI.
# Owner 099720109477 is Canonical's official AWS account — ensures we always
# get an official, up-to-date image without hardcoding an AMI ID.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Bastion host running the NGINX TCP load balancer.
# Lives in the public subnet so it is reachable from the internet.
# Fronts the Kubernetes API (6443) and RKE2 supervisor (9345) ports for
# all control plane nodes, and also serves as the SSH jump host.
resource "aws_instance" "nginx" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.ssh.key_name
  vpc_security_group_ids = [aws_security_group.nginx.id]

  tags = { Name = "nginx-lb" }
}

# Three control plane nodes for a highly available RKE2 cluster.
# Node 0 is designated the cluster-init leader (bootstraps etcd);
# nodes 1 and 2 join via the LB supervisor endpoint.
# Placed in the private subnet — only reachable through the bastion/LB.
# t3.medium provides sufficient CPU/RAM for etcd + kube-apiserver + controllers.
resource "aws_instance" "control_plane" {
  count                  = 3
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.ssh.key_name
  vpc_security_group_ids = [aws_security_group.private.id]

  tags = { Name = "control-plane-${count.index + 1}" }
}

# Worker (agent) nodes that run application workloads.
# Count is 1 for this PoC; increase to scale out capacity.
# Also in the private subnet — outbound internet access via the NAT gateway.
resource "aws_instance" "worker" {
  count                  = 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.ssh.key_name
  vpc_security_group_ids = [aws_security_group.private.id]

  tags = { Name = "worker-${count.index + 1}" }
}
