# n8n-runner — Production Kubernetes Deploy

Production-ready deployment for a self-hosted **n8n + ffmpeg** runner: Helm chart, full DevSecOps CI
pipeline, and cloud-ready Terraform IaC — proven end-to-end at **$0** (local `kind`, no cloud spend).

[![ci](https://github.com/VMG-Emjan/n8n-runner-deploy/actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)

## Why this exists

Demonstrates **cloud deploy / production plumbing**: container → Helm → Kubernetes, with a DevSecOps
gate and IaC. Not demoware — every claim has a reproducible artifact (see [`docs/evidence/`](docs/evidence/README.md)).

## Stack

| Layer | Tool |
|-------|------|
| Workload | self-hosted n8n + ffmpeg/ffprobe ([`n8n-ffmpeg/Dockerfile`](n8n-ffmpeg/Dockerfile)) |
| Packaging | Helm ([`charts/n8n-runner`](charts/n8n-runner)) — image tag parametric |
| Registry | GHCR |
| CI/CD | GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) |
| DevSecOps | Semgrep · gitleaks · tfsec · Trivy · Syft SBOM · Conftest/OPA policy gate |
| IaC | Terraform EKS + ECR ([`infra/terraform`](infra/terraform)) — plan-only |
| Runtime proof | local `kind` ([`scripts/local-deploy.sh`](scripts/local-deploy.sh)) |

## Quick start ($0)

```bash
scripts/local-deploy.sh   # build → kind → deploy → health → rollback → destroy
```

## Going live

Opt-in and billable. See [docs/production-deployment.md](docs/production-deployment.md#going-live).
`terraform apply` → capture live evidence → `terraform destroy`. Est. ~$120/mo if left running.
