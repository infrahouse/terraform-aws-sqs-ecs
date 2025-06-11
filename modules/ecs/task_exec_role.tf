data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

## Principal permissions
data "aws_iam_policy" "ecs-task-execution-role-policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  # expected length of name_prefix to be in the range (1 - 38)
  name_prefix        = substr("${var.service_name}TaskExecutionRole", 0, 38)
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs-task-execution-role-policy.arn
}

## CloudWatch Logging permissions
data "aws_iam_policy_document" "ecs_cloudwatch_logs_policy" {
  statement {
    sid = "AllowDescribeLogGroups"
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
  statement {
    sid = "AllowECSExecLogging"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.consumer.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "ecs_task_execution_logs_policy" {
  policy = data.aws_iam_policy_document.ecs_cloudwatch_logs_policy.json
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_logs_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_logs_policy.arn
}

## User provided permissions
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_user_policy" {
  for_each   = var.task_execution_extra_policies
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = each.value
}
