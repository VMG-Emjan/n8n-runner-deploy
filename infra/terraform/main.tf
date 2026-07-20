# Minimal but real IaC for the cloud-ready target. PLAN-ONLY by policy:
# `terraform apply` is never run unless a live-cloud request is approved (see the prompt's
# "Buluta Çıkış — Yalnızca Talep Üzerine" section). Applying creates billable resources.

data "aws_availability_zones" "available" {
  state = "available"
}

# --- Container registry (ECR). GHCR is used day-to-day; ECR here proves the cloud path. ---
resource "aws_ecr_repository" "n8n_runner" {
  name                 = "n8n-runner"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# --- Networking ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 2), cidrsubnet(var.vpc_cidr, 4, 3)]

  enable_nat_gateway = true
  single_nat_gateway = true # cost cap: one NAT, not one per AZ

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# --- EKS cluster + managed node group (least surface, IRSA enabled) ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      desired_size   = var.node_desired_size
      min_size       = 1
      max_size       = 2
      capacity_type  = "ON_DEMAND"
    }
  }

  # CloudWatch control-plane logging for audit/evidence.
  cluster_enabled_log_types = ["api", "audit", "authenticator"]
}

# --- Application log group ---
resource "aws_cloudwatch_log_group" "n8n_runner" {
  name              = "/eks/${var.cluster_name}/n8n-runner"
  retention_in_days = 14
}

# --- Basic alarm: node group CPU. Demonstrates alerting wiring. ---
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EKS node CPU > 80% for 10m."
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }
}
