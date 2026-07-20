# One-time bootstrap: lets GitHub Actions assume an AWS role via OIDC to run `terraform plan`.
# Run this ONCE locally with your AWS admin credentials. It creates only IAM objects
# (OIDC provider + role) — all free, no billable resources.
#
#   cd infra/oidc-bootstrap
#   terraform init
#   terraform apply        # review; creates IAM OIDC provider + read-only role
#   terraform output plan_role_arn   # copy this into the GitHub secret AWS_PLAN_ROLE_ARN
#
# The role is attached to AWS-managed ReadOnlyAccess, which is enough for `terraform plan`
# (plan only reads). It cannot create/modify/delete anything.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "github_repo" {
  description = "owner/repo allowed to assume the role."
  type        = string
  default     = "VMG-Emjan/n8n-runner-deploy"
}

# Set false if your account already has the GitHub Actions OIDC provider.
variable "create_oidc_provider" {
  type    = bool
  default = true
}

locals {
  oidc_url = "https://token.actions.githubusercontent.com"
  # GitHub's OIDC thumbprint is not validated by AWS anymore, but the provider still requires one.
  oidc_thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = local.oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.oidc_thumbprint]
}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.oidc_url
}

locals {
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.existing[0].arn
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Only the main branch can assume this role. Pull requests and other branches are denied.
      values = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "n8n-runner-ci-plan"
  description        = "Read-only role assumed by GitHub Actions to run terraform plan."
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

output "plan_role_arn" {
  description = "Put this value into the GitHub repo secret AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}
