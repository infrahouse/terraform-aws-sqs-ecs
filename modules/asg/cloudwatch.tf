resource "aws_cloudwatch_log_group" "ecs_ec2_syslog" {
  name              = "${local.cloudwatch_log_group_prefix}-syslog"
  retention_in_days = var.cloudwatch_log_group_retention
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_cloudwatch_log_group" "ecs_ec2_dmesg" {
  name              = "${local.cloudwatch_log_group_prefix}-dmesg"
  retention_in_days = var.cloudwatch_log_group_retention
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}
