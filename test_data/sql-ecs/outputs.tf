output "service_name" {
  description = "Name of the ECS service"
  value       = local.service_name
}

output "task_definition_arn" {
  description = "Consumer ECS task definition ARN"
  value       = module.test.task_definition_arn
}

output "queue_name" {
  description = "SQS queue name"
  value       = module.test.queue_name
}

output "queue_url" {
  description = "SQS queue URL"
  value       = module.test.queue_url
}

output "queue_arn" {
  description = "SQS queue ARN"
  value       = module.test.queue_arn
}

output "dead_letter_queue_name" {
  description = "Dead-letter queue name, or null without one"
  value       = module.test.dead_letter_queue_name
}

output "dead_letter_queue_url" {
  description = "Dead-letter queue URL, or null without one"
  value       = module.test.dead_letter_queue_url
}

output "dead_letter_queue_arn" {
  description = "Dead-letter queue ARN, or null without one"
  value       = module.test.dead_letter_queue_arn
}
