resource "aws_cloudwatch_log_group" "consumer" {
  name              = local.cloudwatch_group
  retention_in_days = var.cloudwatch_log_group_retention
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_cloudwatch_log_group" "containerinsights" {
  name              = "/aws/ecs/containerinsights/${aws_ecs_cluster.consumer.name}/performance"
  retention_in_days = var.cloudwatch_log_group_retention
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}
