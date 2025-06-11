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
