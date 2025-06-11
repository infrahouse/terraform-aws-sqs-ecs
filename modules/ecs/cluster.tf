resource "aws_ecs_cluster" "consumer" {
  name = var.service_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )

}

resource "aws_ecs_capacity_provider" "consumer" {
  name = var.service_name

  auto_scaling_group_provider {
    auto_scaling_group_arn         = var.asg_arn
    managed_termination_protection = "ENABLED"
    managed_draining               = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      # https://repost.aws/questions/QU-SweEQPqR2evZ-n_KaUL0A/ecs-understanding-of-capacityproviderreservation
      target_capacity        = 100
      instance_warmup_period = 300
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

resource "aws_ecs_cluster_capacity_providers" "ecs" {
  cluster_name = aws_ecs_cluster.consumer.name
  capacity_providers = [
    aws_ecs_capacity_provider.consumer.name
  ]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.consumer.name
  }
}
