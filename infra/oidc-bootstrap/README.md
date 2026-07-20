# OIDC bootstrap — enable `terraform plan` in CI

One-time setup so GitHub Actions can assume an AWS role via OIDC and run `terraform plan`.
Creates only IAM objects (OIDC provider + a read-only role) — **free, no billable resources**.
The role has `ReadOnlyAccess` only: it can plan, never apply.

## Steps

```bash
# 1. Run once locally with your AWS admin credentials
cd infra/oidc-bootstrap
terraform init
terraform apply                       # review; if the GitHub OIDC provider already exists,
                                      #   re-run with: -var create_oidc_provider=false
terraform output plan_role_arn        # copy the ARN

# 2. Add it as a GitHub repo secret
#    Settings → Secrets and variables → Actions → New repository secret
#    Name:  AWS_PLAN_ROLE_ARN
#    Value: <the ARN from step 1>

# 3. Re-run the ci workflow (Actions → ci → Run workflow, or push a commit)
```

The `terraform` job's `Plan` step is gated on that secret. Once set, CI runs
`terraform plan` (no apply) and uploads the output as the `terraform-plan` artifact.

## Notes

- Trust is scoped to
  `repo:VMG-Emjan/n8n-runner-deploy:ref:refs/heads/main`. Pull requests and
  other branches cannot assume the AWS role.
- Nothing here is billable. The main `infra/terraform` config is still **plan-only** — no `apply`.
- To remove: `terraform destroy` in this dir (deletes the role/provider).
