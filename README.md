# QuickBallot

A polyglot microservices voting application built with a three-tier architecture, containerised with Docker, orchestrated on Kubernetes, and deployed to AWS via Terraform-managed infrastructure.

- **vote-ui** — Next.js frontend (cast vote, view live results)
- **vote-api** — Java Spring Boot (accepts and records votes)
- **results-api** — Python FastAPI (reads and aggregates results)
- **PostgreSQL on Amazon RDS** — shared datastore for vote-api and results-api

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
├── terraform/        # IaC — VPC, EKS, RDS, IAM, DNS
├── k8s/              # Kubernetes manifests per service
├── helm/             # Helm chart (where applicable)
├── scripts/          # Provisioning and ops scripts
└── docs/             # Infrastructure setup, architecture notes, postmortem
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

Each service has its own GitHub Actions workflow:

1. **Test** — unit and integration tests
2. **Build** — Docker image (multi-stage, non-root)
3. **Push** — image to Amazon ECR
4. **Deploy** — rolling update on EKS via kubectl/Helm

---

## Infrastructure (Terraform)

All AWS resources are defined declaratively in `terraform/`:

- VPC with public and private subnets across two availability zones
- EKS cluster with managed node groups
- RDS PostgreSQL in private subnets with a locked-down security group
- S3 remote state with DynamoDB locking
- Least-privilege IAM roles with IRSA for pod-level AWS access
- ACM certificate + Route 53 DNS for HTTPS ingress

---

## Observability

- Prometheus scrapes metrics from all three services
- Grafana dashboards: request latency, error rate, CPU/memory per pod
- Alertmanager routes alerts to Slack/email

---

## Author

**Stanley Obazee** — Cloud & DevOps Engineer
- GitHub: [@Stanleyobazee](https://github.com/Stanleyobazee)
- LinkedIn: [linkedin.com/in/stanley-obazee-505673259](https://www.linkedin.com/in/stanley-obazee-505673259)

---

## Licence

MIT — see [LICENSE](LICENSE) for details.