resource "aws_autoscaling_policy" "cpu_load" {
  autoscaling_group_name = aws_autoscaling_group.consumer.name
  name                   = "cpu_load_target"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.target_cpu_load
  }
}
