resource "random_string" "asg_suffix" {
  length  = 6
  special = false
}

locals {
  asg_name = "${aws_launch_template.consumer.name}-${random_string.asg_suffix.result}"
}

resource "aws_autoscaling_group" "consumer" {
  name                      = local.asg_name
  min_size                  = local.asg_min_size
  max_size                  = local.asg_max_size
  vpc_zone_identifier       = var.subnet_ids
  max_instance_lifetime     = 30 * 24 * 3600
  health_check_grace_period = 900
  wait_for_capacity_timeout = "15m"
  protect_from_scale_in     = true
  enabled_metrics = [
    "GroupInServiceInstances"
  ]
  dynamic "launch_template" {
    for_each = var.on_demand_base_capacity == null ? [1] : []
    content {
      id      = aws_launch_template.consumer.id
      version = aws_launch_template.consumer.latest_version
    }
  }

  dynamic "mixed_instances_policy" {
    for_each = var.on_demand_base_capacity == null ? [] : [1]
    content {
      instances_distribution {
        on_demand_base_capacity                  = var.on_demand_base_capacity
        on_demand_percentage_above_base_capacity = 0
      }
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.consumer.id
          version            = aws_launch_template.consumer.latest_version
        }
      }
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage       = 90
      scale_in_protected_instances = "Refresh"
    }
  }

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "${var.service_name}-consumer"
  }

  dynamic "tag" {
    for_each = merge(
      local.default_module_tags,
      data.aws_default_tags.provider.tags,
    )
    content {
      key                 = tag.key
      propagate_at_launch = true
      value               = tag.value
    }
  }
  depends_on = [
    module.instance-profile
  ]
}
