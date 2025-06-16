resource "aws_ecs_task_definition" "consumer" {
  family = var.service_name
  container_definitions = jsonencode(
    [
      merge(
        {
          name      = var.service_name
          image     = var.docker_image
          cpu       = var.container_quota_cpu
          memory    = var.container_quota_memory
          essential = true
          healthCheck = {
            "retries" : 3,
            "command" : [
              "CMD-SHELL", var.container_healthcheck_command
            ],
            "timeout" : 5,
            "interval" : 30,
            "startPeriod" : null
          }
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"  = aws_cloudwatch_log_group.consumer.name
              "awslogs-region" = data.aws_region.current.name
            }
          }
          environment = concat(
            [
              {
                name : "SQS_ECS_QUEUE_URL"
                value : var.queue_url
              }
            ],
            var.task_environment_variables
          )
          secrets = var.task_secrets
          mountPoints = [
            for name, def in merge(var.task_volumes_efs, var.task_volumes_local) : {
              sourceVolume : name
              containerPath : def.container_path
            }
          ]
        },
        var.container_commands != null ? { command : var.container_commands } : {},
      )
    ]
  )
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.task_role.arn

  dynamic "volume" {
    for_each = var.task_volumes_efs
    content {
      name = volume.key
      efs_volume_configuration {
        file_system_id = volume.value.file_system_id
      }
    }
  }
  dynamic "volume" {
    for_each = var.task_volumes_local
    content {
      name      = volume.key
      host_path = volume.value.host_path
    }
  }
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}
