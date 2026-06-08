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
        local.instance_memory_available >= local.consumer_task_placement_memory
        && local.instance_cpu_available >= var.consumer_task_quota_cpu
      )
      error_message = <<-EOT
        consumer_instance_type "${var.consumer_instance_type}" is too small for the requested task quotas.
        Available per instance after host/agent reservations: ${local.instance_memory_available} MiB memory, ${local.instance_cpu_available} CPU units.
        Task requires: ${local.consumer_task_placement_memory} MiB placement memory, ${var.consumer_task_quota_cpu} CPU units.
        Pick a larger consumer_instance_type or reduce consumer_task_quota_cpu / consumer_task_quota_memory_reservation.
      EOT
    }
    precondition {
      condition = (
        var.consumer_task_quota_memory_reservation == null
        || var.consumer_task_quota_memory_reservation <= var.consumer_task_quota_memory
      )
      error_message = <<-EOT
        consumer_task_quota_memory_reservation must be less than or equal to consumer_task_quota_memory.
      EOT
    }
  }
}
