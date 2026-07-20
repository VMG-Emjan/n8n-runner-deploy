output "ecr_repository_url" {
  description = "ECR repository URL for the n8n-runner image."
  value       = aws_ecr_repository.n8n_runner.repository_url
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "log_group_name" {
  description = "CloudWatch log group for the app."
  value       = aws_cloudwatch_log_group.n8n_runner.name
}
