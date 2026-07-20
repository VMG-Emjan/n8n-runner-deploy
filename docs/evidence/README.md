# Evidence — "Production, Not Demoware"

Every claim below is backed by a reproducible artifact. All produced at **$0** (GitHub Actions free
tier + local `kind`; no cloud resources created).

**Green CI run:** https://github.com/VMG-Emjan/n8n-runner-deploy/actions/runs/28755424163 — all 7 jobs ✅

| # | Claim | Status |
|---|-------|--------|
| 1 | CI/CD green, all DevSecOps stages | ✅ 7/7 jobs pass — run 28755424163 |
| 2 | SAST runs (Semgrep) | ✅ `sast` job green (report-only; infra repo) |
| 3 | No secrets in repo/history | ✅ `secret-scan` (gitleaks) green; `gitleaks-results.sarif` artifact |
| 4 | IaC scanned (tfsec) | ✅ `iac-scan` green (report-only) |
| 5 | Image vuln-scanned (Trivy) | ✅ Total: 3 (HIGH: 3, CRITICAL: 0) — upstream n8n, report-only |
| 6 | SBOM produced (Syft) | ✅ `sbom` artifact (775 KB, SPDX-JSON) |
| 7 | Policy gate enforces hardening | ✅ `helm-policy` green; locally bad manifest fails 6/6 (see `local-validation.local.txt`) |
| 8 | Infra provable without spend | ✅ real OIDC `terraform plan`: **55 to add, 0 change, 0 destroy** (no apply); `terraform-plan` artifact — run 28756826763 |
| 9 | Image published w/ digest | ✅ `ghcr.io/vmg-emjan/n8n-runner@sha256:a2bce2778c22…54d7da` |
| 10 | Runtime: pods running | ✅ CI `local-k8s`: `n8n-n8n-runner-… 1/1 Running`; also local kind |
| 11 | Helm release + revision | ✅ `helm list` deployed rev1; rollback → rev2 |
| 12 | Health endpoint passing | ✅ readiness/liveness `/healthz`; local curl HTTP 200 `{"status":"ok"}` |
| 13 | Rollback works | ✅ CI + local `helm rollback` success |
| 14 | Secret not in image/logs | ✅ `N8N_ENCRYPTION_KEY` via secretKeyRef, not inline |
| 15 | Repeatable | ✅ CI reruns clean; `scripts/local-deploy.sh` full cycle |
| 16 | (opt) Live cloud | ☐ opt-in / billable — `terraform apply` on request, then `destroy` |

## Reproduce locally ($0)

```bash
scripts/local-deploy.sh   # build → kind → deploy → health → rollback → destroy
```

`*.local.*` files (raw run captures) are git-ignored so live data never leaks.
