locals {
  module_version = "2.1.0"

  default_module_tags = merge(
    var.tags,
    {
      service : var.service_name
      created_by_module : "infrahouse/sqs-ecs/aws"
    }
  )

  # Host paths for daemon config files. Written by the ASG submodule via
  # cloud-init, mounted into the daemon containers by the ECS submodule.
  cloudwatch_agent_config_path = "/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
  vector_agent_config_path     = "/etc/vector/vector.yaml"

  # Per-daemon resource reservations on every EC2 host. Mirror values in the
  # infrahouse/ecs/aws reference module so sizing stays consistent.
  cloudwatch_agent_container_resources = {
    cpu    = 128
    memory = 256
  }
  vector_agent_container_resources = {
    cpu    = 128
    memory = 256
  }

  host_memory_reserved = 1024 # Host OS reservation

  daemon_memory_overhead = (
    (var.enable_cloudwatch_logs ? local.cloudwatch_agent_container_resources.memory : 0) +
    (var.enable_vector_agent ? local.vector_agent_container_resources.memory : 0)
  )
  daemon_cpu_overhead = (
    (var.enable_cloudwatch_logs ? local.cloudwatch_agent_container_resources.cpu : 0) +
    (var.enable_vector_agent ? local.vector_agent_container_resources.cpu : 0)
  )

  instance_memory_available = (
    data.aws_ec2_instance_type.consumer.memory_size
    -local.host_memory_reserved
    -local.daemon_memory_overhead
  )
  instance_cpu_available = (
    data.aws_ec2_instance_type.consumer.default_vcpus * 1024
    -local.daemon_cpu_overhead
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
