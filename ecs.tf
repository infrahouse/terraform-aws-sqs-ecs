module "ecs" {
  source                         = "./modules/ecs"
  environment                    = var.environment
  service_name                   = var.service_name
  asg_arn                        = module.asg.asg_arn
  cloudwatch_log_group_retention = var.log_retention_days
  container_commands             = var.consumer_task_commands
  container_healthcheck_command  = var.consumer_task_healthcheck_command
  container_quota_cpu            = var.consumer_task_quota_cpu
  container_quota_memory         = var.consumer_task_quota_memory
  docker_image                   = var.consumer_docker_image
  queue_name                     = aws_sqs_queue.queue.name
  service_target_backlog_size    = var.consumer_target_backlog_size
  task_environment_variables     = var.consumer_task_environment_variables
  task_execution_extra_policies  = var.consumer_task_execution_extra_policies
  task_role_extra_policies       = var.consumer_task_role_extra_policies
  task_max_count                 = local.task_max_count
  task_min_count                 = local.task_min_count
  task_secrets                   = var.consumer_task_secrets
  task_volumes_efs               = var.consumer_task_volumes_efs
  task_volumes_local             = var.consumer_task_volumes_local
  dependencies = {
    "security_group_inbound_rule" : module.asg.security_group_inbound_rule
    "security_group_outbound_rule" : module.asg.security_group_outbound_rule
  }
}
