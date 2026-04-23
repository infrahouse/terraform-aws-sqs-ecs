data "aws_iam_policy_document" "daemon_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "cloudwatch_agent_task_role" {
  count              = var.enable_cloudwatch_logs ? 1 : 0
  name_prefix        = format("%s-cw-task-", substr(var.service_name, 0, 20))
  assume_role_policy = data.aws_iam_policy_document.daemon_assume_role.json
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_iam_role" "cloudwatch_agent_execution_role" {
  count              = var.enable_cloudwatch_logs ? 1 : 0
  name_prefix        = format("%s-cw-exec-", substr(var.service_name, 0, 20))
  assume_role_policy = data.aws_iam_policy_document.daemon_assume_role.json
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_task_policy" {
  count      = var.enable_cloudwatch_logs ? 1 : 0
  role       = aws_iam_role.cloudwatch_agent_task_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_execution_policy" {
  count      = var.enable_cloudwatch_logs ? 1 : 0
  role       = aws_iam_role.cloudwatch_agent_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "cloudwatch_agent" {
  # checkov:skip=CKV_AWS_336: Agent needs a writable /opt/aws/amazon-cloudwatch-agent/var/ for file-tail offsets. Proper fix tracked in follow-up issue.
  count              = var.enable_cloudwatch_logs ? 1 : 0
  family             = format("%s-cw-agent-daemon", var.service_name)
  task_role_arn      = aws_iam_role.cloudwatch_agent_task_role[0].arn
  execution_role_arn = aws_iam_role.cloudwatch_agent_execution_role[0].arn

  container_definitions = jsonencode(
    [
      {
        name      = "cloudwatch-agent"
        image     = var.cloudwatch_agent_image
        memory    = 256
        cpu       = 128
        essential = true
        mountPoints = [
          {
            sourceVolume  = "log-volume"
            containerPath = "/var/log"
          },
          {
            sourceVolume  = "config-volume"
            containerPath = "/etc/cwagentconfig"
            readOnly      = true
          }
        ]
      }
    ]
  )

  volume {
    name      = "log-volume"
    host_path = "/var/log"
  }

  volume {
    name      = "config-volume"
    host_path = var.cloudwatch_agent_config_path
  }

  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_ecs_service" "cloudwatch_agent" {
  count               = var.enable_cloudwatch_logs ? 1 : 0
  name                = "cloudwatch-agent-daemon"
  cluster             = aws_ecs_cluster.consumer.id
  task_definition     = aws_ecs_task_definition.cloudwatch_agent[0].arn
  launch_type         = "EC2"
  scheduling_strategy = "DAEMON"
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}
