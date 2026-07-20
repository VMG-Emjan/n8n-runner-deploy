# Production Deployment — n8n-runner

Production-ready deployment for the **n8n ffmpeg-runner** (n8n + ffmpeg/ffprobe), packaged as a
Helm chart with a full DevSecOps CI pipeline and cloud-ready Terraform IaC.

**Cost model:** everything below is **$0**. No cloud resources are created. Runtime proof runs on a
throwaway local `kind` cluster; Terraform is `validate` + `plan` only. Live cloud is opt-in
(see [Going Live](#going-live)).

## Architecture

```
n8n-ffmpeg/Dockerfile ──build──> GHCR image ──Helm──> Kubernetes (kind local | EKS on demand)
                                     │
CI (GitHub Actions):  SAST · secret-scan · IaC-scan · Trivy · SBOM · policy-gate · helm-lint · tf plan · kind deploy+rollback
```

| Component | Choice | Why |
|-----------|--------|-----|
| Workload | self-hosted n8n + ffmpeg | the "ffmpeg-runner" named in the skill gap |
| Packaging | Helm chart `charts/n8n-runner` | image tag is parametric — swap to the python `automation` superset via `--set image.repository=` |
| Registry | GHCR | free; ECR defined in Terraform as the cloud path |
| Runtime proof | local `kind` | real `kubectl`/`helm` evidence at $0 |
| IaC | Terraform EKS + ECR (plan-only) | proves infra without spend |
| State | n8n SQLite on PVC | local ok; prod → external DB (RDS) |

## Prerequisites

- Local proof: `docker`, `kind`, `kubectl`, `helm`
- CI: a GitHub repo (`git init` + push). Actions run on the free tier.
- Secrets never committed — enforced by `.gitignore`, `.dockerignore`, and the gitleaks CI job.

## Quick start (local, $0)

```bash
scripts/local-deploy.sh          # build → kind → deploy → prove → rollback → destroy
KEEP=1 scripts/local-deploy.sh   # keep the cluster for manual poking
```

Evidence lands in `docs/evidence/local-run.local.txt`.

## CI/CD pipeline

`.github/workflows/ci.yml` jobs:

1. **sast** — Semgrep
2. **secret-scan** — gitleaks
3. **iac-scan** — tfsec on `infra/terraform`
4. **build** — docker build → Trivy scan (fails on HIGH/CRITICAL) → Syft SBOM → GHCR push (main only, with digest)
5. **helm-policy** — `helm lint` + `helm template` → Conftest policy gate (`policy/kubernetes.rego`)
6. **terraform** — `fmt` + `validate` always; `plan` only when `AWS_PLAN_ROLE_ARN` is set (OIDC, never applies)
7. **local-k8s** — kind cluster → Helm deploy → `kubectl rollout status` → `helm rollback` smoke test

### Secrets & auth

- **Runtime secret:** `N8N_ENCRYPTION_KEY`. Local/dev uses `secret.create=true` (in-values, dev only).
  Production: set `secret.create=false` and provision `n8n-runner-secret` via External Secrets / SSM CSI.
- **AWS auth:** OIDC only. Set repo secret `AWS_PLAN_ROLE_ARN` to an IAM role trusting GitHub's OIDC
  provider. No long-lived AWS keys anywhere.
- **Branch protection:** require the `sast`, `secret-scan`, `helm-policy`, and `local-k8s` checks on `main`;
  require PR review; restrict who can approve the `production` GitHub Environment.

## Going Live

Live cloud is **opt-in** and starts billing. Only when a client/employer asks:

```bash
cd infra/terraform
# 1. configure remote state (uncomment backend "s3" in versions.tf)
# 2. set AWS creds via OIDC/profile
terraform init
terraform plan      # review — this is the same plan CI produces
terraform apply     # <-- billing starts here (EKS control plane + node + NAT)
# ... deploy chart to the real cluster, capture live evidence ...
terraform destroy   # <-- billing stops
```

**Estimated monthly cost if left running:** EKS control plane ~\$73 + 1× t3.small node ~\$15 +
single NAT gateway ~\$32 ≈ **\$120/mo**. Destroy immediately after capturing evidence to keep it near \$0.

## Evidence checklist

See `docs/evidence/README.md`. Collect: green CI run, scan outputs, SBOM, policy-gate pass/fail,
`terraform plan`, image digest, `kubectl get pods`, `helm list`, health check, `helm rollback`.
