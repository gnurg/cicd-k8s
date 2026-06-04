# VPC Networking

This document explains the network architecture used for the EKS cluster on AWS.

---

## Overview

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
┌─────────────────────────────────────────┐
│  VPC  10.0.0.0/16                       │
│                                         │
│  ┌──────────────┐  ┌──────────────┐     │
│  │ Public Subnet│  │ Public Subnet│     │
│  │ 10.0.0.0/24  │  │ 10.0.1.0/24  │     │
│  │              │  │              │     │
│  │ Load Balancer│  │  NAT Gateway │     │
│  └──────────────┘  └──────┬───────┘     │
│                           │             │
│  ┌──────────────┐  ┌──────▼───────┐     │
│  │Private Subnet│  │Private Subnet│     │
│  │ 10.0.10.0/24 │  │ 10.0.11.0/24 │     │
│  │              │  │              │     │
│  │ Fargate Pods │  │ Fargate Pods │     │
│  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────┘
```

---

## Components

### VPC (Virtual Private Cloud)
An isolated virtual network in AWS — like having your own private data center in the cloud. All cluster resources live inside it. Nothing outside can reach it unless explicitly allowed.

CIDR: `10.0.0.0/16` — up to 65,536 IP addresses available for all subnets.

### Availability Zones
AWS regions are divided into multiple physically separate data centers called Availability Zones (AZs). We create one subnet per AZ — if one AZ goes down, the cluster keeps running in the other. This is called **high availability**.

### Public Subnets (`10.0.0.0/24`, `10.0.1.0/24`)
Subnets directly reachable from the internet. Used for:
- **Load Balancer** — receives traffic from users and routes it to the pods
- **NAT Gateway** — allows private resources to initiate outbound connections

Resources in public subnets get a public IP address automatically.

### Private Subnets (`10.0.10.0/24`, `10.0.11.0/24`)
Subnets with no direct inbound access from the internet. Used for:
- **Fargate pods** — the containers running the app

Pods in private subnets are more secure — they cannot be reached directly from the internet. Traffic reaches them only via the Load Balancer.

### Internet Gateway
The "door" between the VPC and the public internet. Required for public subnets to send and receive traffic from the internet. Without it, nothing in the VPC can reach the outside world.

### NAT Gateway (Network Address Translation)
Allows resources in **private subnets** to make outbound connections to the internet (e.g. to pull Docker images from Docker Hub) **without** being reachable from the internet themselves.

Think of it as a one-way door: pods can call out, but nothing can call in. Placed in a public subnet, it translates the pod's private IP into its own public IP for outbound traffic.

### Load Balancer
Receives incoming traffic from users on port 80 and distributes it across the available pods. Placed in the public subnets. In Kubernetes this is created automatically when a Service of type `LoadBalancer` is applied — AWS provisions it behind the scenes.

### Route Tables
Define how traffic is routed within the VPC:
- **Public route table** — sends all outbound traffic (`0.0.0.0/0`) to the Internet Gateway
- **Private route table** — sends all outbound traffic (`0.0.0.0/0`) to the NAT Gateway

Each subnet is associated with one route table.

### Elastic IP (EIP)
A static public IP address assigned to the NAT Gateway. Required because the NAT Gateway needs a fixed public IP to route outbound traffic from private subnets.

---

## Traffic flow

**Inbound (user → app):**
```
User → Internet → Internet Gateway → Load Balancer (public subnet) → Fargate pod (private subnet)
```

**Outbound from pod (e.g. pulling a Docker image):**
```
Fargate pod (private subnet) → NAT Gateway (public subnet) → Internet Gateway → Internet
```
