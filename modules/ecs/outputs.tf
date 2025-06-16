output "service_name" {
  description = "Consumer ECS Service name"
  value       = aws_ecs_service.consumer.name
}

output "service_arn" {
  description = "Consumer ECS Service ARN"
  value       = aws_ecs_service.consumer.id
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.task_role.arn
}

output "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution_role.arn
}