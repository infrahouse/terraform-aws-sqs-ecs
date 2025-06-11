resource "aws_ecs_service" "consumer" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.consumer.id
  desired_count   = var.task_min_count
  task_definition = aws_ecs_task_definition.consumer.arn

  lifecycle {
    ignore_changes = [
      desired_count,
    ]
  }
  force_delete = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_iam_role.ecs_task_execution_role,
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_ecs_cluster_capacity_providers.ecs,
  ]
  tags = merge(
    {
      # need these tags for implicit dependency
      execution_role_arn : aws_ecs_task_definition.consumer.execution_role_arn
      # ECS agent needs to be able to connect the ECS to update task status
      security_group_inbound_rule: var.dependencies["security_group_inbound_rule"]
      security_group_outbound_rule: var.dependencies["security_group_outbound_rule"]
    },
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
  timeouts {
    delete = "10m"
  }
}
