# VPC Subnetting Plan

This is the plan Phase 3 Terraform will implement. Sketched now (Phase 1) per
the assignment, built for real later.

## CIDR overview

| Name                 | CIDR             | AZ          | Type    | Purpose                              |
|----------------------|-------------------|-------------|---------|---------------------------------------|
| quickballot-vpc      | 10.0.0.0/16       | —           | —       | Whole VPC (65,536 addresses)          |
| public-subnet-a      | 10.0.0.0/24       | us-east-1a  | Public  | NAT gateway, ALB/Ingress, bastion     |
| public-subnet-b      | 10.0.1.0/24       | us-east-1b  | Public  | ALB/Ingress (2nd AZ, HA)              |
| private-subnet-a     | 10.0.10.0/24      | us-east-1a  | Private | EKS worker nodes / pods               |
| private-subnet-b     | 10.0.11.0/24      | us-east-1b  | Private | EKS worker nodes / pods (2nd AZ)      |
| private-db-subnet-a  | 10.0.20.0/24      | us-east-1a  | Private | RDS (DB subnet group)                 |
| private-db-subnet-b  | 10.0.21.0/24      | us-east-1b  | Private | RDS (DB subnet group, required 2 AZs) |

(Swap `us-east-1` for whichever region you settle on — just keep it consistent
everywhere: EC2 in Phase 1, and every Terraform resource in Phase 3.)

## Routing

- **Public subnets** → route table with a route to an Internet Gateway (`0.0.0.0/0 → igw`).
- **Private subnets** (EKS nodes) → route table with a route to a NAT Gateway
  sitting in a public subnet (`0.0.0.0/0 → nat-gw`), so pods can pull images /
  call AWS APIs without being reachable from the internet.
- **Private DB subnets** → no route to the internet at all. RDS only needs to
  be reachable from inside the VPC.

## Why split DB subnets from EKS node subnets

RDS requires a "DB subnet group" spanning ≥2 AZs, and keeping the database on
its own subnets makes the security group story simple: the DB security group
only needs one inbound rule — Postgres (5432) from the EKS node/pod security
group. Nothing else can reach it, not even other things in the private subnet.

## Security groups (preview, built in Phase 3)

- `sg-eks-nodes` — inbound from the ALB/Ingress SG on service ports, outbound
  open (nodes need to reach AWS APIs, ECR, RDS).
- `sg-rds` — inbound 5432 **only** from `sg-eks-nodes`. No public inbound rule
  ever exists on this SG.
- `sg-alb` — inbound 80/443 from `0.0.0.0/0` (it's the public entry point),
  outbound to `sg-eks-nodes`.

## Phase 1 practice box (temporary, not part of final architecture)

The Phase 1 practice server (Linux admin / bash / UFW exercise) is a local
VirtualBox VM, not AWS infrastructure at all — it gets discarded once Phase 1
is done. The custom VPC above only gets built in Phase 3, in Terraform, and
that's what EKS/RDS actually live in.
