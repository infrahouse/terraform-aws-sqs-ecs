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

output "queue_name" {
  description = "SQS Queue name"
  value       = aws_sqs_queue.queue.name
}

output "queue_url" {
  description = "SQS Queue URL"
  value       = aws_sqs_queue.queue.id
}

output "queue_arn" {
  description = "SQS Queue ARN"
  value       = aws_sqs_queue.queue.arn
}
