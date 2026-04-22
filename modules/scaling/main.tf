locals {
  tasks_per_instance = max(
    1,
    min(
      floor(var.instance_memory_available_mib / var.task_quota_memory),
      floor(var.instance_cpu_available_units / var.task_quota_cpu),
    ),
  )

  asg_min_size = var.consumer_asg_min_size != null ? var.consumer_asg_min_size : var.subnet_count

  # If consumer_asg_max_size is given - use it
  # If consumer_asg_max_size is not given and consumer_task_max_count is given - use consumer_task_max_count / tasks_per_instance
  # If neither is given - use the number of subnets plus one
  asg_max_size = var.consumer_asg_max_size != null ? (
    var.consumer_asg_max_size
    ) : (
    var.consumer_task_max_count != null ? (
      ceil(var.consumer_task_max_count / local.tasks_per_instance)
    ) : var.subnet_count + 1
  )

  task_min_count = var.consumer_task_min_count != null ? (
    var.consumer_task_min_count
    ) : (
    local.asg_min_size * local.tasks_per_instance
  )

  task_max_count = var.consumer_task_max_count != null ? (
    var.consumer_task_max_count
    ) : (
    local.asg_max_size * local.tasks_per_instance
  )
}
