# QuickBallot

A polyglot microservices voting application built with a three-tier architecture, containerised with Docker, orchestrated on Kubernetes, and deployed to AWS via Terraform-managed infrastructure.

- **vote-ui** — Next.js frontend (cast vote, view live results)
- **vote-api** — Java Spring Boot (accepts and records votes)
- **results-api** — Python FastAPI (reads and aggregates results)
- **PostgreSQL on Amazon RDS** — shared datastore for vote-api and results-api

---

## Status

**Implemented**

- Three services (vote-ui, vote-api, results-api) with Dockerfiles, and a Docker Compose setup with healthchecks
- Terraform state bucket: versioned, encrypted, TLS-only, with a lifecycle rule
- VPC with public, private and database subnets across three availability zones, an optional NAT gateway and an S3 gateway endpoint
- Private ECR repositories with immutable tags, scan on push and lifecycle policies
- Route 53 delegated zone and ACM certificate
- Pull request checks: terraform fmt, validate, tflint and a Trivy misconfiguration scan

**Planned**

- RDS PostgreSQL in private subnets and EKS with blue-green deployments
- IAM roles for CI (GitHub OIDC) and workloads (IRSA)
- Per-service CI/CD: tests, image build, push to ECR, deploy
- Monitoring with Prometheus, Grafana and Alertmanager
- API-level tests and database migrations

The Architecture and Tech Stack sections below describe the target design.

---

## Architecture

```
                        ┌─────────────────────────────┐
                        │       GitHub Actions         │
                        │       CI/CD Pipeline         │
                        └──────────────┬──────────────┘
                                       │
              ┌────────────────────────▼────────────────────────┐
              │                  AWS EKS                        │
              │                                                  │
              │  ┌──────────────┐   ┌──────────────┐           │
              │  │   vote-ui    │   │  results-api  │           │
              │  │  (Next.js)   │   │   (FastAPI)   │           │
              │  └──────┬───────┘   └──────┬────────┘           │
              │         │                  │                     │
              │  ┌──────▼──────────────────▼────────┐           │
              │  │          vote-api                 │           │
              │  │       (Spring Boot)               │           │
              │  └──────────────┬────────────────────┘           │
              └─────────────────┼────────────────────────────────┘
                                │
                   ┌────────────▼────────────┐
                   │   Amazon RDS PostgreSQL  │
                   │     (private subnet)     │
                   └─────────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js |
| Vote API | Java Spring Boot |
| Results API | Python FastAPI |
| Database | PostgreSQL (Amazon RDS) |
| Containerisation | Docker (multi-stage builds) |
| Orchestration | Kubernetes (AWS EKS) |
| Infrastructure | Terraform |
| CI/CD | GitHub Actions |
| Observability | Prometheus + Grafana |

---

## Project Structure

```
quickballot-app/
├── vote-ui/          # Next.js frontend
├── vote-api/         # Spring Boot vote ingestion API
├── results-api/      # FastAPI results aggregation service
├── terraform/        # IaC: bootstrap (state), main (network, ECR), dns
├── k8s/              # Kubernetes manifests per service
├── scripts/          # Provisioning and ops scripts
├── .github/          # CI workflows
└── docs/             # Infrastructure setup and network design notes
```

---

## Development Environment

Phase 1 runs on a local Ubuntu Server 24.04 VM hosted on a Proxmox hypervisor. The VM is provisioned via an idempotent setup script and accessed via VS Code Remote SSH — mirroring the workflow of a remote EC2 instance without AWS spend at this stage.

See [docs/infrastructure-setup.md](docs/infrastructure-setup.md) for the full environment spec and setup steps.

---

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Node.js 20+
- Java 21+
- Python 3.12+

### Run locally

```bash
git clone https://github.com/Stanleyobazee/quickballot-app.git
cd quickballot-app
docker compose up --build
```

Services:

| Service | Port |
|---------|------|
| vote-ui | 3000 |
| vote-api | 8080 |
| results-api | 8000 |
| PostgreSQL | 5432 |

---

## CI/CD Pipeline

**Implemented:** the terraform-checks workflow runs on every pull request: format check, terraform validate for each stack, tflint and a Trivy misconfiguration scan.

**Planned:** one workflow per service:

1. **Test** — unit and API-level tests
2. **Build** — Docker image (multi-stage, non-root)
3. **Push** — image to Amazon ECR
4. **Deploy** — blue-green release on EKS

---

## Infrastructure (Terraform)

AWS resources are defined in `terraform/`, split into three stacks with separate state:

| Stack | Contents | Status |
|-------|----------|--------|
| `bootstrap` | S3 state bucket | Implemented |
| `main` | VPC, public/private/database subnets across three AZs, optional NAT gateway, S3 gateway endpoint, ECR repositories | Implemented |
| `dns` | Route 53 zone for the delegated subdomain and wildcard ACM certificate | Implemented |
| (not yet created) | EKS with managed node groups, RDS PostgreSQL in private subnets, least-privilege IAM with GitHub OIDC for CI and IRSA for pods | Planned |

Remote state lives in S3 and uses S3 native locking (`use_lockfile`); there is no DynamoDB table.

### Initialising Terraform

The state bucket name is not in the code. Copy `terraform/backend.hcl.example` to `terraform/backend.hcl`, set the bucket name, then run this inside each stack folder:

```bash
terraform init -backend-config=../backend.hcl
```

Add `-reconfigure` if the stack was initialised before. The `dns` stack also needs `terraform.tfvars` copied from `terraform.tfvars.example`.

Running `init` without the file makes Terraform prompt for a bucket, and entering a different name points at a different, possibly empty, state.

---

## Observability (planned)

- Prometheus scrapes metrics from all three services
- Grafana dashboards: request latency, error rate, CPU/memory per pod
- Alertmanager routes alerts to Slack/email

---

## Decisions & Trade-offs

- **Cost-controlled, short-lived environment:** expensive resources (NAT gateway today, EKS and RDS later) exist only while needed and are destroyed afterwards. The NAT gateway sits behind `enable_nat_gateway`, off by default.
- **One NAT gateway instead of one per AZ:** lower hourly cost, but private subnets lose outbound access if its AZ fails. `single_nat_gateway = false` gives one per AZ.
- **State bucket encryption:** SSE-S3 rather than a customer-managed KMS key, so there is no key cost or key policy to manage. A KMS key adds key-policy control and an audit trail, and is the upgrade for a long-lived environment or if state ever holds secrets. The scanner exception is recorded in `.trivyignore.yaml`.
- **State locking:** S3 native locking instead of a DynamoDB table, one resource less to run and pay for.
- **Backend configuration:** the bucket name is supplied through a git-ignored `backend.hcl`, so it is not repeated in each stack or published in the repository.
- **Database:** an optional RDS PostgreSQL instance (`enable_database`, off by default, so there is no hourly cost while it is unused). It runs in a single AZ with no deletion protection and no final snapshot, which suits a disposable environment and is not a production configuration. Production would add Multi-AZ, deletion protection and a final snapshot. The master password is generated by RDS and stored in Secrets Manager (`manage_master_user_password`), so no password appears in code or state files. The database security group allows PostgreSQL (5432) only from the EKS cluster security group, and only when both `enable_database` and `enable_eks` are true.
- **EKS cluster:** optional (`enable_eks`, off by default) and billed by the hour while enabled, for the control plane, the nodes and the NAT gateway it depends on. A precondition requires `enable_nat_gateway`, an admin role (`eks_admin_role_arn`) and a non-empty `eks_public_access_cidrs`, so a misconfigured combination fails at plan time.
- **EKS access:** access entries (authentication mode `API`) instead of the `aws-auth` ConfigMap, so access is managed through the AWS API and the cluster creator receives no implicit admin rights. The public API endpoint is enabled but limited to `eks_public_access_cidrs`; `0.0.0.0/0` is rejected. The private endpoint is enabled for in-VPC access. Access entries require the full role ARN including the SSO path (`.../role/aws-reserved/sso.amazonaws.com/<region>/AWSReservedSSO_...`), unlike the older `aws-auth` ConfigMap.
- **EKS nodes:** x86 nodes (`AL2023_x86_64_STANDARD`) because the images are built for amd64; Graviton would need multi-arch builds. Two `t3.medium` nodes by default, because the pod limit per node on small instances is low. The count (`eks_node_count`) and type are variables.
- **EKS logging:** control plane logs (api, audit, authenticator) go to a log group managed in Terraform with 7-day retention, to bound storage cost.
- **EKS scanner exceptions:** Trivy findings AWS-0039, AWS-0040 and AWS-0041 are suppressed for `eks.tf` only, with the reasons recorded in `.trivyignore.yaml`. AWS-0039 (no customer-managed key for secrets): EKS envelope-encrypts all Kubernetes API data by default with an AWS-owned key (Kubernetes 1.28 and later), and a customer-managed key is the upgrade for a long-lived environment. AWS-0040 and AWS-0041 (public endpoint): the API endpoint must be reachable from the operator's workstation, which is outside the VPC. Public access is limited to explicit CIDR ranges and `0.0.0.0/0` is rejected. A private-only endpoint would need a VPN or bastion host.
- **Load balancer controller:** the AWS Load Balancer Controller gets its AWS permissions through EKS Pod Identity (`pods.eks.amazonaws.com` trust and an `aws_eks_pod_identity_association`) instead of IRSA, so no OIDC trust conditions or service account annotations are needed. Its IAM policy is the project's official `iam_policy.json`, vendored unchanged in `terraform/main/policies/` and pinned to controller v3.6.3 together with the Helm chart version in `scripts/deploy-k8s.sh`, so a change in the upstream policy is a reviewed update and not a surprise.
- **Secrets handling:** `scripts/deploy-k8s.sh` creates the `db-config` ConfigMap and the `db-credentials` Secret at deploy time from the RDS-managed secret in Secrets Manager. Nothing is stored in Git, and the password is passed to `kubectl` through a process substitution, not on a command line. The Kubernetes Secret is a copy of the Secrets Manager value, refreshed on each deploy and not on rotation. External Secrets Operator is the production alternative, syncing the secret continuously.
- **HTTPS:** TLS is terminated at the ALB with an ACM certificate (apex and wildcard) issued and DNS-validated by the `dns` stack. The Ingress redirects HTTP to HTTPS and uses the `ELBSecurityPolicy-TLS13-1-2-2021-06` policy. The certificate ARN is read from Terraform at deploy time and substituted into the manifest, so it is not stored in Git. Traffic inside the cluster is plain HTTP behind the load balancer.
- **DNS record:** the alias record at the zone apex is created by `scripts/dns-record.sh` and not by Terraform, because the ALB belongs to the AWS Load Balancer Controller and does not exist in Terraform state. ExternalDNS is the alternative: it would manage the record from the Ingress continuously, at the cost of another controller and its IAM permissions.
- **Teardown order:** `scripts/teardown-k8s.sh` removes the DNS record and the Ingress first and waits until the ALB and the controller's security groups are gone, and only then is Terraform run to switch the environment off. A load balancer created by the controller is not in Terraform state, so an orphaned one keeps network interfaces and security groups in the VPC and blocks its deletion. The script prints the Terraform commands and never applies them.
- **Vote integrity:** the voter token is created and stored in the browser, and a database uniqueness constraint rejects repeat submissions for the same token. This is friction against accidental duplicates, not verified one-person-one-vote, because clearing the token allows another vote. A stronger guarantee would need a voter identity or eligibility mechanism.

### Container image findings

Images are scanned with ECR basic scanning on push and rebuilt with `--pull`, so base-image patches are picked up. A finding with a fix available is fixed. A finding without a fix, or one that does not apply to how the image is used, is recorded here with the reason and a trigger for re-checking. ECR tags are immutable, so every rebuild gets a new tag (version plus commit hash). The ECR scan covers OS packages only, while CI also reports library findings from Trivy.

| Recorded | Image | Finding | Reason | Re-check when |
|---|---|---|---|---|
| 2026-11-17 | vote-ui 0.1.1 | 1 CRITICAL, CVE-2026-4738, reported against the Alpine package zlib 1.3.2-r1 | The CVE concerns the infback9 module in the zlib copy bundled with GDAL. The image does not contain GDAL, and the Alpine zlib package contains no infback9 files. Alpine already has zlib 1.4-r0, but the `node:24-alpine` base has not picked it up yet. | Rebuild with `--pull` when the base image is refreshed, push as 0.1.2, re-scan. |
| 2026-11-17 | results-api 0.1.1 | 4 HIGH in the Debian base packages zlib and glibc (`python:3.12-slim`); also 9 MEDIUM and 3 LOW, not acted on individually | The glibc findings have no patched package yet. zlib1g now has a Debian fix and clears on a rebuild with `--pull`. | At the next rebuild with `--pull`. |
| 2026-11-23 | vote-api 0.1.1 | 1 CRITICAL (CVE-2026-4738, zlib); 4 HIGH in openssl (CVE-2026-95691, CVE-2026-88823, CVE-2026-95692, CVE-2026-107496); 1 HIGH in libfontenc (CVE-2026-109908); 4 MEDIUM | All are Alpine base-image packages; none are in application dependencies. | Rebuild with `--pull` on a refreshed base image. |

CVE-2026-124851 (libzstd1 in the results-api base image) was fixed on 2026-11-25 by a package upgrade in the Dockerfile.

### Dependency findings

CI reports fixable HIGH and CRITICAL library findings from Trivy without failing the build. They come from these versions: Spring Boot 4.0.0 (vote-api), Next.js 14.2.35 (vote-ui), and fastapi 0.115.0 with starlette 0.38.6 (results-api). Upgrades are planned as separate changes; the CI step becomes a gate once they land.

---

## Author

**Stanley Obazee** — Cloud & DevOps Engineer
- GitHub: [@Stanleyobazee](https://github.com/Stanleyobazee)
- LinkedIn: [linkedin.com/in/stanley-obazee-505673259](https://www.linkedin.com/in/stanley-obazee-505673259)

---

## Licence

MIT — see [LICENSE](LICENSE) for details.