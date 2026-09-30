# QuickBallot

Polyglot microservices voting app — capstone project for Borderless Tech Academy (DevOps Cohort 1).

- **vote-ui** — Next.js frontend (cast vote, view live results)
- **vote-api** — Java Spring Boot (accepts and records votes)
- **results-api** — Python FastAPI (reads and aggregates results)
- **PostgreSQL on Amazon RDS** — shared datastore for vote-api and results-api

> This README will grow into the final submission doc. The architecture diagram
> and "Decisions & Trade-offs" section get added in Phase 7. For now it doubles
> as our working roadmap.

## Roadmap / checklist

Target: submit by **2026-10-16** (1 month from kickoff).

- [ ] **Phase 1 — Foundation** (Linux, Bash, Networking, Git)
  - [ ] Ubuntu server provisioned (local VirtualBox VM), non-root sudo user, SSH key-only auth
  - [ ] UFW firewall configured
  - [ ] Idempotent setup script (`scripts/setup-server.sh`) — Docker, Nginx, swap, fail2ban
  - [ ] VPC subnetting plan sketched (`docs/vpc-subnetting-plan.md`)
  - [ ] GitHub repo public, `.gitignore` in place, `main` branch protected
- [ ] **Phase 2 — Application layer**
  - [ ] Shared `votes` schema designed
  - [ ] vote-ui, vote-api, results-api working locally against local Postgres
  - [ ] Each service Dockerized (multi-stage, non-root, `.dockerignore`)
  - [ ] Images pushed to per-service ECR repos
  - [ ] Health-check endpoint per service
- [ ] **Phase 3 — Infrastructure as Code**
  - [ ] Terraform: VPC, NAT, route tables
  - [ ] Terraform: EKS cluster
  - [ ] Terraform: RDS Postgres (private subnets, locked-down SG)
  - [ ] Domain registered, DNS → vote-ui, HTTPS cert
  - [ ] S3 remote state + locking
  - [ ] Least-privilege IAM / IRSA
  - [ ] `terraform plan`/`apply` workflow documented
- [ ] **Phase 4 — CI/CD**
  - [ ] Per-service GitHub Actions pipeline (test → build → push ECR → deploy)
  - [ ] PR checks: lint, test, `terraform plan`
  - [ ] Secrets in GitHub Actions secrets / AWS Secrets Manager
  - [ ] dev → main flow with manual approval gate, instructor as reviewer
- [ ] **Phase 5 — Orchestration & blue-green**
  - [ ] K8s manifests per service (Deployment/Service/Ingress/ConfigMap/Secret/probes/HPA)
  - [ ] Ingress on domain with HTTPS
  - [ ] Blue-green deployment on one service, demoed live
  - [ ] Rolling update + rollback demoed on another service
- [ ] **Phase 6 — Observability**
  - [ ] Prometheus + Grafana via Helm
  - [ ] 3+ dashboards: latency, error rate, CPU/memory
  - [ ] At least one alert rule wired to Slack/email
- [ ] **Phase 7 — Docs, demo, teardown**
  - [ ] Architecture diagram + Decisions & Trade-offs in README
  - [ ] 5–7 min demo video (push → pipeline → live vote → blue-green → dashboards)
  - [ ] Incident postmortem (`docs/postmortem.md`)
  - [ ] Screenshots captured **before** teardown
  - [ ] `terraform destroy` run, confirmed

## Repo layout

```
quickballot-app/
├── vote-ui/        # Next.js frontend
├── vote-api/        # Spring Boot API
├── results-api/     # FastAPI results service
├── terraform/        # IaC for VPC, EKS, RDS, IAM, DNS
├── k8s/              # Kubernetes manifests per service
├── scripts/          # Server setup / ops scripts
└── docs/              # Subnetting plan, postmortem, notes
```

## Local decisions log

- **Phase 1 server**: local VirtualBox VM (not EC2, not WSL2) — the
  assignment allows "local VM or EC2" for Phase 1, and a real VM keeps the
  host/guest boundary clean (SSH into it from Windows like a remote box,
  genuine UFW/fail2ban lockout risk) in a way WSL2's blurred networking
  doesn't. No AWS spend for this throwaway practice box either. See
  [docs/phase1-foundation.md](docs/phase1-foundation.md).
