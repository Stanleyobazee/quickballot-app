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
- **State bucket encryption:** SSE-S3 rather than a customer-managed KMS key, so there is no key cost or key policy to manage. A KMS key adds key-policy control and an audit trail, and is the upgrade for a long-lived environment or if state ever holds secrets. The scanner exception is recorded in `.trivyignore`.
- **State locking:** S3 native locking instead of a DynamoDB table, one resource less to run and pay for.
- **Backend configuration:** the bucket name is supplied through a git-ignored `backend.hcl`, so it is not repeated in each stack or published in the repository.
- **Vote integrity:** the voter token is created and stored in the browser, and a database uniqueness constraint rejects repeat submissions for the same token. This is friction against accidental duplicates, not verified one-person-one-vote, because clearing the token allows another vote. A stronger guarantee would need a voter identity or eligibility mechanism.

---

## Author

**Stanley Obazee** — Cloud & DevOps Engineer
- GitHub: [@Stanleyobazee](https://github.com/Stanleyobazee)
- LinkedIn: [linkedin.com/in/stanley-obazee-505673259](https://www.linkedin.com/in/stanley-obazee-505673259)

---

## Licence

MIT — see [LICENSE](LICENSE) for details.