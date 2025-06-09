resource "aws_ecs_service" "consumer" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.consumer.id
  desired_count   = null
  task_definition = aws_ecs_task_definition.consumer.arn

  lifecycle {
    ignore_changes = [
      desired_count,
      capacity_provider_strategy  # workaround for https://github.com/hashicorp/terraform-provider-aws/issues/39584
    ]
  }

  capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.consumer.name
    weight            = 100
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_iam_role.ecs_task_execution_role,
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
  ]
  tags = merge(
    {
      # need these tags for implicit dependency
      execution_role_arn : aws_ecs_task_definition.consumer.execution_role_arn
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
