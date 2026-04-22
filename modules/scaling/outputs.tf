output "tasks_per_instance" {
  description = "Number of ECS tasks that fit on one EC2 instance given the configured quotas."
  value       = local.tasks_per_instance
}

output "asg_min_size" {
  description = "Resolved ASG minimum size."
  value       = local.asg_min_size
}

output "asg_max_size" {
  description = "Resolved ASG maximum size."
  value       = local.asg_max_size
}

output "task_min_count" {
  description = "Resolved ECS service task minimum count."
  value       = local.task_min_count
}

output "task_max_count" {
  description = "Resolved ECS service task maximum count."
  value       = local.task_max_count
}
