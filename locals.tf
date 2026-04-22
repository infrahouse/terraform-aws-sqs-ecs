locals {
  module_version = "2.0.0"

  default_module_tags = merge(
    var.tags,
    {
      service : var.service_name
      created_by_module : "infrahouse/sqs-ecs/aws"
    }
  )
  # This is how much resource the cloudwatch agent consumes
  cloudwatch_agent_container_resources = {
    cpu    = 128
    memory = 256
  }
  host_memory_reserved = 1024 # Allocate 1024 MB of memory for host operating system

  instance_memory_available = (
    data.aws_ec2_instance_type.consumer.memory_size
    -local.host_memory_reserved
    -local.cloudwatch_agent_container_resources.memory
  )
  instance_cpu_available = (
    data.aws_ec2_instance_type.consumer.default_vcpus * 1024
    -local.cloudwatch_agent_container_resources.cpu
  )
}

module "scaling" {
  source = "./modules/scaling"

  instance_memory_available_mib = local.instance_memory_available
  instance_cpu_available_units  = local.instance_cpu_available
  task_quota_cpu                = var.consumer_task_quota_cpu
  task_quota_memory             = var.consumer_task_quota_memory
  subnet_count                  = length(var.consumer_subnet_ids)

  consumer_asg_min_size   = var.consumer_asg_min_size
  consumer_asg_max_size   = var.consumer_asg_max_size
  consumer_task_min_count = var.consumer_task_min_count
  consumer_task_max_count = var.consumer_task_max_count
}
