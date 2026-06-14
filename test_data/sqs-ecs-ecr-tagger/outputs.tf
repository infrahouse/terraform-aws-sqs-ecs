output "service_name" {
  description = "Name of the consumer ECS service (also the ECS cluster name)."
  value       = local.service_name
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = local.service_name
}

output "ecr_repo_name" {
  description = "Name of the ECR repository holding the consumer image."
  value       = aws_ecr_repository.test.name
}

output "queue_name" {
  description = "Name of the SQS queue created by the module."
  value       = module.test.queue_name
}
