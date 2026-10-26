resource "aws_sns_topic" "sqs_alarms" {
  name_prefix = "${var.service_name}-sqs-alarms-"
  tags        = local.default_module_tags
}
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.sqs_alarms.arn
  protocol  = "email"
  endpoint  = var.alert_notification_email
}

resource "aws_cloudwatch_metric_alarm" "sqs_age_alarm" {
  alarm_name          = "${aws_sqs_queue.queue.name}-message-age-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300 # 5 minutes
  statistic           = "Maximum"
  threshold           = 3600 # 1 hour in seconds, adjust as needed
  alarm_description   = "Alarm when the oldest message in the queue exceeds 1 hour"
  alarm_actions       = [aws_sns_topic.sqs_alarms.arn]
  ok_actions          = [aws_sns_topic.sqs_alarms.arn]

  dimensions = {
    QueueName = aws_sqs_queue.queue.name
  }
}

resource "aws_cloudwatch_metric_alarm" "dead_letter_queue_depth" {
  count = var.enable_dead_letter_queue ? 1 : 0

  alarm_name          = "${aws_sqs_queue.dead_letter[0].name}-depth-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300 # 5 minutes
  statistic           = "Maximum"
  # One message is enough: it is a message the consumers received dead_letter_queue_max_receive_count times and
  # never deleted, and it waits for someone to look at it.
  threshold = 0
  # SQS stops publishing a queue's metrics after six hours without messages or calls, a dead-letter queue's usual
  # state, and AWS's wording leaves open whether one that still holds messages keeps publishing. Missing data keeps
  # the alarm in the state it was in: neither a false ALARM for a quiet, empty queue nor a false OK for one that
  # still holds messages.
  treat_missing_data = "ignore"
  alarm_description = join(" ", [
    "Messages that consumers received ${var.dead_letter_queue_max_receive_count} times without deleting are in",
    "${aws_sqs_queue.dead_letter[0].name}, kept 14 days. Fix the cause, then redrive them to",
    "${aws_sqs_queue.queue.name}.",
  ])
  alarm_actions = [aws_sns_topic.sqs_alarms.arn]
  ok_actions    = [aws_sns_topic.sqs_alarms.arn]

  dimensions = {
    QueueName = aws_sqs_queue.dead_letter[0].name
  }
}
