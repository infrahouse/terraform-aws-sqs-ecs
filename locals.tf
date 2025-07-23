locals {
  module_version = "1.0.0"

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

  tasks_per_instance = min(
    1,
    # number of tasks per instance based on memory usage
    ceil(
      (
        data.aws_ec2_instance_type.consumer.memory_size - local.host_memory_reserved - local.cloudwatch_agent_container_resources.memory
      ) / var.consumer_task_quota_memory
    ),
    # number of tasks per instance based on CPU usage
    ceil(
      (
        data.aws_ec2_instance_type.consumer.default_vcpus * 1024 - local.cloudwatch_agent_container_resources.cpu
      ) / var.consumer_task_quota_cpu
    )
  )

  asg_min_size = var.consumer_asg_min_size != null ? var.consumer_asg_min_size : length(var.consumer_subnet_ids)
  # If consumer_asg_max_size is given - use it
  # If consumer_asg_max_size is not given and consumer_task_max_count is given - use consumer_task_max_count / tasks_per_instance
  # If neither is given - use the number of subnets plus one
  asg_max_size = var.consumer_asg_max_size != null ? (
    var.consumer_asg_max_size
    ) : (
    var.consumer_task_max_count != null ? (
      ceil(var.consumer_task_max_count / local.tasks_per_instance)
    ) : length(var.consumer_subnet_ids) + 1
  )

  task_min_count = var.consumer_task_min_count != null ? (
    var.consumer_task_min_count
    ) : (
    ceil(local.asg_min_size / local.tasks_per_instance)
  )
  task_max_count = var.consumer_task_max_count != null ? (
    var.consumer_task_max_count
    ) : (
    ceil(local.asg_max_size / local.tasks_per_instance)
  )
}
