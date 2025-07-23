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
