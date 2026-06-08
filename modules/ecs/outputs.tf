output "service_name" {
  description = "Consumer ECS Service name"
  value       = aws_ecs_service.consumer.name
}

output "service_arn" {
  description = "Consumer ECS Service ARN"
  value       = aws_ecs_service.consumer.id
}

output "task_definition_arn" {
  description = "Consumer ECS task definition ARN"
  value       = aws_ecs_task_definition.consumer.arn
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.task_role.arn
}

output "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution_role.arn
}
