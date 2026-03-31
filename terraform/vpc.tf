# =============================================================================
# vpc.tf — VPC, subnets, gateways, and routing for the RKE2 cluster
#
# Network layout:
#   10.0.0.0/16  — VPC CIDR
#   10.0.1.0/24  — public subnet  (bastion/NGINX LB, NAT gateway EIP)
#   10.0.2.0/24  — private subnet (control plane nodes + workers)
#
# Internet traffic flow:
#   inbound  → IGW → public subnet → NGINX LB → private nodes
#   outbound (private) → private route table → NAT GW → IGW → internet
# =============================================================================

# VPC with DNS support enabled so EC2 instances get resolvable hostnames.
# DNS hostnames are required by some AWS services and the EKS/RKE2 tooling.
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Internet Gateway — attaches to the VPC and enables inbound/outbound
# internet connectivity for resources in the public subnet.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
}

# Public subnet — hosts the NGINX bastion and the NAT gateway.
# map_public_ip_on_launch gives the bastion an auto-assigned public IP
# so it is reachable without a manually managed EIP.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
}

# Private subnet — hosts all control plane and worker nodes.
# No public IPs; outbound internet access goes through the NAT gateway.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"
}

# Elastic IP for the NAT gateway — provides a stable outbound public IP
# for instances in the private subnet (used for package installs, image pulls).
resource "aws_eip" "nat" {}

# NAT Gateway — placed in the public subnet so private-subnet instances
# can initiate outbound internet connections without being directly reachable.
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

# Route table for the public subnet — default route via the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Route table for the private subnet — default route via the NAT Gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

# Associate the public route table with the public subnet.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Associate the private route table with the private subnet.
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
