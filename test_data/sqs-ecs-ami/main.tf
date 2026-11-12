resource "random_string" "suffix" {
  length  = 6
  special = false
}

# The module in this checkout with a consumer_ami_id. tests/test_consumer_ami.py
# only plans it.
module "test" {
  source                   = "./../../"
  environment              = "development"
  service_name             = local.service_name
  consumer_subnet_ids      = var.consumer_subnet_ids
  consumer_docker_image    = "httpd"
  consumer_ami_id          = var.consumer_ami_id
  consumer_asg_max_size    = 1
  consumer_asg_min_size    = 1
  consumer_instance_type   = "t3a.small"
  alert_notification_email = "devnull@infrahouse.com"
}
