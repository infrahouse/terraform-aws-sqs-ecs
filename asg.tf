module "asg" {
  source = "./modules/asg"

  ami_id                       = var.consumer_ami_id
  asg_min_size                 = module.scaling.asg_min_size
  asg_max_size                 = module.scaling.asg_max_size
  cloudwatch_agent_config_path = local.cloudwatch_agent_config_path
  enable_cloudwatch_logs       = var.enable_cloudwatch_logs
  enable_vector_agent          = var.enable_vector_agent
  environment                  = var.environment
  extra_files                  = var.consumer_extra_files
  extra_policies               = var.consumer_extra_policies
  instance_type                = var.consumer_instance_type
  keypair_name                 = var.consumer_keypair_name
  on_demand_base_capacity      = var.consumer_on_demand_base_capacity
  root_volume_size             = var.consumer_root_volume_size
  service_name                 = var.service_name
  subnet_ids                   = var.consumer_subnet_ids
  tags = {
    AmazonECSManaged : true
    queue-name : aws_sqs_queue.queue.name
  }
  target_cpu_load            = var.consumer_target_cpu_load
  users                      = {}
  vector_agent_config        = var.vector_agent_config
  vector_agent_config_path   = local.vector_agent_config_path
  vector_aggregator_endpoint = var.vector_aggregator_endpoint
}
