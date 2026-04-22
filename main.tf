resource "aws_sqs_queue" "queue" {
  name                    = var.queue_name
  fifo_queue              = var.fifo_queue
  sqs_managed_sse_enabled = true
  tags = merge(
    local.default_module_tags,
    {
      module_version : local.module_version
    }
  )

  lifecycle {
    precondition {
      condition = (
        local.instance_memory_available >= var.consumer_task_quota_memory
        && local.instance_cpu_available >= var.consumer_task_quota_cpu
      )
      error_message = <<-EOT
        consumer_instance_type "${var.consumer_instance_type}" is too small for the requested task quotas.
        Available per instance after host/agent reservations: ${local.instance_memory_available} MiB memory, ${local.instance_cpu_available} CPU units.
        Task requires: ${var.consumer_task_quota_memory} MiB memory, ${var.consumer_task_quota_cpu} CPU units.
        Pick a larger consumer_instance_type or reduce consumer_task_quota_cpu / consumer_task_quota_memory.
      EOT
    }
  }
}
