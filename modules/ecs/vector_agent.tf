resource "aws_iam_role" "vector_agent_task_role" {
  count              = var.enable_vector_agent ? 1 : 0
  name_prefix        = format("%s-vec-task-", substr(var.service_name, 0, 20))
  assume_role_policy = data.aws_iam_policy_document.daemon_assume_role.json
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_iam_role" "vector_agent_execution_role" {
  count              = var.enable_vector_agent ? 1 : 0
  name_prefix        = format("%s-vec-exec-", substr(var.service_name, 0, 20))
  assume_role_policy = data.aws_iam_policy_document.daemon_assume_role.json
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_iam_role_policy_attachment" "vector_agent_execution_policy" {
  count      = var.enable_vector_agent ? 1 : 0
  role       = aws_iam_role.vector_agent_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "vector_agent_task_policy" {
  for_each   = var.enable_vector_agent ? toset(var.vector_agent_task_policy_arns) : toset([])
  role       = aws_iam_role.vector_agent_task_role[0].name
  policy_arn = each.value
}

resource "aws_ecs_task_definition" "vector_agent" {
  count              = var.enable_vector_agent ? 1 : 0
  family             = format("%s-vector-agent-daemon", var.service_name)
  task_role_arn      = aws_iam_role.vector_agent_task_role[0].arn
  execution_role_arn = aws_iam_role.vector_agent_execution_role[0].arn

  container_definitions = jsonencode(
    [
      {
        name      = "vector-agent"
        image     = var.vector_agent_image
        memory    = 256
        cpu       = 128
        essential = true
        command   = ["--config", var.vector_agent_config_path]
        mountPoints = [
          {
            sourceVolume  = "docker-containers"
            containerPath = "/var/lib/docker/containers"
            readOnly      = true
          },
          {
            sourceVolume  = "docker-sock"
            containerPath = "/var/run/docker.sock"
            readOnly      = true
          },
          {
            sourceVolume  = "vector-config"
            containerPath = var.vector_agent_config_path
            readOnly      = true
          }
        ]
        healthCheck = {
          command     = ["CMD-SHELL", "wget -qO- http://localhost:8686/health || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 60
        }
      }
    ]
  )

  volume {
    name      = "docker-containers"
    host_path = "/var/lib/docker/containers"
  }

  # Docker socket grants full Docker API access. The readOnly mount flag only
  # prevents filesystem writes — it does NOT restrict API calls (list, inspect,
  # stop containers) through the Unix socket. Vector's docker_logs source
  # requires the socket to discover and tail container logs.
  volume {
    name      = "docker-sock"
    host_path = "/var/run/docker.sock"
  }

  volume {
    name      = "vector-config"
    host_path = var.vector_agent_config_path
  }

  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )

  lifecycle {
    precondition {
      condition     = var.vector_aggregator_endpoint != null || var.vector_agent_config != null
      error_message = "enable_vector_agent = true requires either vector_aggregator_endpoint or vector_agent_config to be set."
    }
  }
}

resource "aws_ecs_service" "vector_agent" {
  count               = var.enable_vector_agent ? 1 : 0
  name                = "vector-agent-daemon"
  cluster             = aws_ecs_cluster.consumer.id
  task_definition     = aws_ecs_task_definition.vector_agent[0].arn
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
