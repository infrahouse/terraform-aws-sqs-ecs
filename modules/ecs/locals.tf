locals {
  default_module_tags = {}
  cloudwatch_group    = "/ecs/${var.environment}/${var.service_name}"
}
