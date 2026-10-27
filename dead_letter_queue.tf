locals {
  # SQS requires a FIFO queue's dead-letter queue to be FIFO as well, and a FIFO queue's name to end in ".fifo".
  dead_letter_queue_name = join("", [
    trimsuffix(aws_sqs_queue.queue.name, ".fifo"),
    "-dlq",
    var.fifo_queue ? ".fifo" : "",
  ])

  # SQS's maximum, 14 days. A standard queue's message keeps its original enqueue time when it moves, so it expires
  # from the dead-letter queue that much sooner; the queue keeps messages 4 days, SQS's default, which leaves at
  # least 10 to look into one.
  dead_letter_queue_retention_seconds = 1209600

  # What that means for a message that moves, for the alarm's email.
  dead_letter_queue_expiry = (
    var.fifo_queue
    ? "Each expires 14 days after it moved there."
    : "Each expires 14 days after it was first sent to the queue, at least 10 days after it moved there."
  )
}

resource "aws_sqs_queue" "dead_letter" {
  count = var.enable_dead_letter_queue ? 1 : 0

  name                      = local.dead_letter_queue_name
  fifo_queue                = var.fifo_queue
  sqs_managed_sse_enabled   = true
  message_retention_seconds = local.dead_letter_queue_retention_seconds
  # Only the module's queue may move its messages here.
  redrive_allow_policy = jsonencode(
    {
      redrivePermission = "byQueue"
      sourceQueueArns   = [aws_sqs_queue.queue.arn]
    }
  )
  tags = local.default_module_tags

  lifecycle {
    precondition {
      condition     = length(local.dead_letter_queue_name) <= 80
      error_message = <<-EOT
        The dead-letter queue's name, "${local.dead_letter_queue_name}", is longer than the 80 characters SQS allows.
        It is the queue's name with "-dlq" before any ".fifo":
        shorten queue_name by ${length(local.dead_letter_queue_name) - 80} characters.
      EOT
    }
  }
}

# Apart from the queue, not its redrive_policy argument: the dead-letter queue takes its name and its redrive allow
# policy from the queue, so the queue can't refer back to it.
resource "aws_sqs_queue_redrive_policy" "queue" {
  count = var.enable_dead_letter_queue ? 1 : 0

  queue_url = aws_sqs_queue.queue.id
  redrive_policy = jsonencode(
    {
      deadLetterTargetArn = aws_sqs_queue.dead_letter[0].arn
      maxReceiveCount     = var.dead_letter_queue_max_receive_count
    }
  )
}
