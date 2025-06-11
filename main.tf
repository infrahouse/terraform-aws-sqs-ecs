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
}
