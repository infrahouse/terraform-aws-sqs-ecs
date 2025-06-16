output "service_name" {
  description = "Consumer ECS Service name"
  value       = module.ecs.service_name
}

output "service_arn" {
  description = "Consumer ECS Service ARN"
  value       = module.ecs.service_arn
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = module.ecs.task_role_arn
}

output "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = module.ecs.task_execution_role_arn
}
