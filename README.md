# RKE2 HA Kubernetes on AWS

---

## Overview

This Infrastructure-as-Code (IaC) project provisions a **highly available Rancher Kubernetes Engine 2 (RKE2) cluster on AWS** using **Terraform and Bash-based automation**.

The goal of this project is to demonstrate a **production-style Kubernetes architecture** with automated infrastructure provisioning and cluster bootstrap, suitable for Proof-of-Concept (PoC) environments.

Key features include:

- Multi-node **high availability control plane**
- Embedded **etcd** running on control-plane nodes
- **NGINX-based TCP load balancing** for Kubernetes API access
- Bastion-host access model for secure cluster operations
- Automated bootstrap of control plane and worker nodes
- End-to-end cluster validation after deployment

This project is fully reproducible, easy to deploy and tear down, and mirrors common Kubernetes deployment patterns used in real-world production environments.

---

## Architecture

### High-Level Architecture

The cluster is deployed within a dedicated AWS Virtual Private Cloud (VPC) and consists of public and private subnets.
<img width="1051" height="1251" alt="RKE2-AWS-HA(3)" src="https://github.com/user-attachments/assets/b603cb5b-6c81-4a47-83d5-8ee0d56af0c6" />

### Components

- **NGINX Load Balancer / Bastion**
  - Publicly accessible EC2 instance
  - Acts as:
    - SSH bastion for operator access
    - TCP load balancer for Kubernetes API traffic

- **Control Plane Nodes (3)**
  - Deployed in a private subnet
  - Run Kubernetes control plane components
  - Form an embedded etcd quorum for high availability

- **Worker Nodes**
  - Deployed in a private subnet
  - Run application workloads

- **Networking**
  - Public subnet for bastion access
  - Private subnet for Kubernetes nodes
  - NAT Gateway for outbound internet access from private nodes
  - No direct public access to control plane or worker nodes

---

## Key Design Decisions

- High availability control plane with multiple nodes
- Embedded etcd for control plane state management
- Load-balanced Kubernetes API endpoint
- Bastion-based access model
- Private networking for all Kubernetes nodes
- Automated provisioning and bootstrap workflow
- Simple lifecycle management (create, verify, destroy)

These design choices reflect common patterns used in production Kubernetes environments while remaining suitable for PoC usage.

---

## Prerequisites

### Local Requirements

- Linux or macOS
- Bash
- Terraform (v1.5 or later recommended)
- AWS CLI configured with valid credentials
- `jq`
- SSH client

### AWS Requirements

- An AWS account
- Permissions to create:
- VPCs and subnets
- Security groups
- EC2 instances
- NAT Gateway and Elastic IPs

---

## Installation Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/Abhiram-Rakesh/rke2-kubernetes-ha-aws.git
cd rke2-ha-aws-terraform-bash
```

### 2. Install the Cluster

```bash
chmod +x *.sh
./install.sh
```

This command will:

- Provision AWS infrastructure using Terraform

- Bootstrap the RKE2 control plane

- Join worker nodes to the cluster

- Configure Kubernetes API load balancing

- Enable bastion-based kubectl access

- Perform basic cluster health validation

### 3. Access the Cluster

After installation completes, SSH into the nginx LB using the ssh key in the `/terraform` directory

```bash
ssh -i <PATH_TO_SSH_KEY> ubuntu@<NGINX_LB_IP>
```

Validate cluster status:

```bash
kubectl get nodes
kubectl get pods -A
```

All nodes should be in the Ready state.

### 4. Re-run Bootstrap (Optional)

If infrastructure is already provisioned and you want to re-run the bootstrap process:

```bash
./start.sh
```

### 5. Destroy the Environment

To remove all resources created by this project:

```bash
./shutdown.sh
```

⚠️ This action will destroy all AWS infrastructure provisioned by the project.

---

## Troubleshooting Guide

### Terraform Apply Fails

- Verify AWS credentials are configured correctly

- Ensure required AWS permissions are available

- Check Terraform output for service limits or region constraints

### SSH Access Issues

- Ensure the generated SSH key exists

- Set correct permissions:

- chmod 600 terraform/ssh_key.pem

### Kubernetes API Not Reachable

- Confirm the NGINX service is running on the bastion

- Verify internal connectivity between bastion and control plane nodes

- Ensure required ports are reachable within the VPC

---

## Recap

This project provides a production-aligned Proof of Concept for running a highly available RKE2 Kubernetes cluster on AWS, featuring:

- Automated infrastructure provisioning

- High availability control plane

- Secure bastion-based access

- Load-balanced Kubernetes API

- Simple installation and teardown workflow

It is intended for demonstrations, experimentation, and learning purposes while closely reflecting real-world Kubernetes deployment patterns.
