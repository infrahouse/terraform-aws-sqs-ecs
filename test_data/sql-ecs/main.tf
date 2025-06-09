module "test" {
  source              = "./../../"
  service_name        = "sqs-test"
  consumer_subnet_ids = var.consumer_subnet_ids
  consumer_on_demand_base_capacity = 0
  consumer_docker_image = "httpd"
}
