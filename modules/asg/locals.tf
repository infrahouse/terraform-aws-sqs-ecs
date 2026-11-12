locals {
  default_module_tags         = var.tags
  cloudwatch_log_group_prefix = "/ecs/${var.environment}/${var.service_name}"
  ami_id                      = var.ami_id != null ? var.ami_id : data.aws_ami.ecs.id
  asg_min_size                = var.asg_min_size != null ? var.asg_min_size : length(var.subnet_ids)
  asg_max_size                = var.asg_max_size != null ? var.asg_max_size : length(var.subnet_ids) + 1

  # The root device of the image the launch template uses.
  root_device_name = (
    var.ami_id != null ? data.aws_ami.selected[0].root_device_name : data.aws_ami.ecs.root_device_name
  )
}
