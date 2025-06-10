resource "aws_ecs_service" "consumer" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.consumer.id
  desired_count = var.task_min_count
  task_definition = aws_ecs_task_definition.consumer.arn

  lifecycle {
    ignore_changes = [
      desired_count,
      # capacity_provider_strategy,
    ]
  }
  force_delete = true

  # capacity_provider_strategy {
  #   base              = 1
  #   capacity_provider = aws_ecs_capacity_provider.consumer.name
  #   weight            = 100
  # }

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

  # lifecycle {
  #   ignore_changes = [ capacity_provider_strategy ]
  # }
  # provisioner "local-exec" {
  #   # use bash -c so we can loop
  #   interpreter = ["bash", "-c"]
  #   command = templatefile(
  #     "${path.module}/assets/wait_for_cap_provider.sh.tftpl",
  #     {
  #       name = self.name
  #       provider_account_id: data.aws_caller_identity.current.account_id
  #       identity_arn: data.aws_caller_identity.current.arn
  #       aws_region: data.aws_region.current.name
  #     }
  #   )
  # }
}
