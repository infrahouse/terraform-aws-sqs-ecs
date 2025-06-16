output "service_name" {
  description = "Consumer ECS Service name"
  value       = module.ecs.service_name
}

output "service_arn" {
  description = "Consumer ECS Service ARN"
  value       = module.ecs.service_arn
}
