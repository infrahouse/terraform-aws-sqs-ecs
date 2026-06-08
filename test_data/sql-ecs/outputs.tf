output "service_name" {
  description = "Name of the ECS service"
  value       = local.service_name
}

output "task_definition_arn" {
  description = "Consumer ECS task definition ARN"
  value       = module.test.task_definition_arn
}
