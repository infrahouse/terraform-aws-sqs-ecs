module "asg" {
  source = "./modules/asg"

  ami_id                  = var.consumer_ami_id
  asg_min_size            = local.asg_min_size
  asg_max_size            = local.asg_max_size
  environment             = var.environment
  extra_files             = var.consumer_extra_files
  extra_policies          = var.consumer_extra_policies
  instance_type           = var.consumer_instance_type
  keypair_name            = var.consumer_keypair_name
  on_demand_base_capacity = var.consumer_on_demand_base_capacity
  root_volume_size        = var.consumer_root_volume_size
  service_name            = var.service_name
  subnet_ids              = var.consumer_subnet_ids
  tags = {
    AmazonECSManaged : true
    queue-name : aws_sqs_queue.queue.name
  }
  target_cpu_load = var.consumer_target_cpu_load
  users           = {}
}
