resource "random_string" "suffix" {
  length  = 6
  special = false
}

module "test" {
  source                     = "./../../"
  environment                = "development"
  service_name               = local.service_name
  consumer_subnet_ids        = var.consumer_subnet_ids
  consumer_docker_image      = "httpd"
  consumer_asg_max_size      = 1
  consumer_asg_min_size      = 1
  consumer_instance_type     = "t3a.small"
  alert_notification_email   = "devnull@infrahouse.com"
  enable_cloudwatch_logs     = var.enable_cloudwatch_logs
  enable_vector_agent        = var.enable_vector_agent
  vector_aggregator_endpoint = var.vector_aggregator_endpoint
}
