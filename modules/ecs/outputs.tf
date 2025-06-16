output "service_name" {
  description = "Consumer ECS Service name"
  value       = aws_ecs_service.consumer.name
}

output "service_arn" {
  description = "Consumer ECS Service ARN"
  value       = aws_ecs_service.consumer.id
}
