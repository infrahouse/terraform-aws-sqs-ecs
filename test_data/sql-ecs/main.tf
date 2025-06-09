resource "random_string" "suffix" {
  length = 6
  special = false
}
module "test" {
  source                           = "./../../"
  service_name                     = "sqs-test-${random_string.suffix.result}"
  consumer_subnet_ids              = var.consumer_subnet_ids
  consumer_on_demand_base_capacity = 0
  consumer_docker_image            = "httpd"
}
