# Network design

Region: eu-north-1 (Stockholm), three availability zones.
VPC: 10.0.0.0/16 (65,536 addresses), built with Terraform in `terraform/main`.

| Tier     | eu-north-1a  | eu-north-1b  | eu-north-1c  | Holds                        |
| -------- | ------------ | ------------ | ------------ | ---------------------------- |
| Public   | 10.0.1.0/24  | 10.0.10.0/24 | 10.0.20.0/24 | Load balancer, NAT gateway   |
| Private  | 10.0.32.0/20 | 10.0.48.0/20 | 10.0.64.0/20 | EKS worker nodes and pods    |
| Database | 10.0.96.0/24 | 10.0.97.0/24 | 10.0.98.0/24 | RDS                          |

The subnets use 13,824 of the 65,536 addresses and do not overlap.

## Routing

- Public subnets share one route table with a default route to the internet gateway.
- Each private subnet has its own route table. When the NAT gateway is enabled,
  the default route points at it, so pods can pull images and call AWS APIs
  without being reachable from the internet.
- Database subnets share a route table with no route to the internet.

## NAT gateway

One NAT gateway in the first public subnet serves all three private subnets
(`single_nat_gateway = true`). It is created only when `enable_nat_gateway` is
true, because the gateway and its Elastic IP are billed by the hour.

Trade-off: if that zone fails, the private subnets in the other two zones lose
outbound internet, and their traffic to the NAT crosses zone boundaries at a
small transfer charge. One gateway per zone costs about three times as much and
is a one-variable change (`single_nat_gateway = false`). The environment is
short-lived, so the cheaper option was chosen.

## Why the database tier is separate

RDS needs a subnet group that spans at least two zones. Keeping the database on
its own subnets keeps the security rules simple: the database security group
allows Postgres (5432) only from the node security group.

## Security groups (planned)

- `sg-alb`: inbound 80 and 443 from the internet, outbound to `sg-eks-nodes`.
- `sg-eks-nodes`: inbound from `sg-alb` on the service ports, outbound open.
- `sg-rds`: inbound 5432 only from `sg-eks-nodes`. No public rule exists.

## Tags

Public subnets carry `kubernetes.io/role/elb = 1` and private subnets
`kubernetes.io/role/internal-elb = 1`, so the AWS load balancer controller finds
them. Every resource gets `Project` and `ManagedBy` tags from the provider, and
names follow `project-tier-zone`.
