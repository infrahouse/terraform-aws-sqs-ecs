data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_sqs_queue" "current" {
  name = var.queue_name
}
