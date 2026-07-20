terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state (recommended). Documented, NOT applied by default — see docs/production-deployment.md.
  # Uncomment and set values only when going live.
  # backend "s3" {
  #   bucket         = "CHANGE-ME-tfstate"
  #   key            = "n8n-runner/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "CHANGE-ME-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
  # Credentials come from OIDC (GitHub Actions) or local profile. No static keys in code.
  default_tags {
    tags = {
      Project   = "n8n-runner"
      ManagedBy = "terraform"
      Env       = var.environment
    }
  }
}
