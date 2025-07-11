resource "random_string" "suffix" {
  length  = 6
  special = false
}
module "test" {
  source                 = "./../../"
  service_name           = "sqs-test-${random_string.suffix.result}"
  consumer_subnet_ids    = var.consumer_subnet_ids
  consumer_docker_image  = "httpd"
  consumer_asg_max_size  = 1
  consumer_asg_min_size  = 1
  consumer_instance_type = "t3a.micro"
}
