// Offline tests for the dead-letter queue option: its name, its settings, the
// redrive between the queues, and the checks on its inputs. Runs via
// `terraform test` as plans against mocked providers, so it creates nothing;
// tests/test_dead_letter_queue.py checks the same against real SQS.
//
// Run from the repo root:
//   terraform init -backend=false
//   terraform test

mock_provider "aws" {
  // Every run is a plan, so nothing is left to tear down; the values below
  // exist at plan time instead.
  override_during = plan

  // An ARN and a URL of each queue's own, so the redrive checks below tell one
  // queue from the other.
  override_resource {
    target = aws_sqs_queue.queue
    values = {
      arn = "arn:aws:sqs:us-west-2:123456789012:queue"
      id  = "https://sqs.us-west-2.amazonaws.com/123456789012/queue"
    }
  }
  override_resource {
    target = aws_sqs_queue.dead_letter
    values = {
      arn = "arn:aws:sqs:us-west-2:123456789012:dead-letter"
      id  = "https://sqs.us-west-2.amazonaws.com/123456789012/dead-letter"
    }
  }

  // The alarms' actions must be ARNs; a mocked topic's random string isn't one.
  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-west-2:123456789012:mock"
    }
  }
  // A t3a.small, so the module's instance sizing check passes.
  override_data {
    target = data.aws_ec2_instance_type.consumer
    values = {
      memory_size   = 2048
      default_vcpus = 2
    }
  }
}
mock_provider "cloudinit" {}
mock_provider "null" {}
mock_provider "random" {}
mock_provider "tls" {}

variables {
  environment              = "development"
  service_name             = "dlq-test"
  consumer_subnet_ids      = ["subnet-00000000000000001"]
  consumer_docker_image    = "httpd"
  alert_notification_email = "devnull@infrahouse.com"
  queue_name               = "orders"
}

run "off_by_default" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  assert {
    condition = (
      length(aws_sqs_queue.dead_letter) == 0
      && length(aws_sqs_queue_redrive_policy.queue) == 0
      && length(aws_cloudwatch_metric_alarm.dead_letter_queue_depth) == 0
    )
    error_message = "Without enable_dead_letter_queue, the module must create no dead-letter queue, redrive policy or alarm."
  }
  assert {
    condition = (
      output.dead_letter_queue_name == null
      && output.dead_letter_queue_url == null
      && output.dead_letter_queue_arn == null
    )
    error_message = "Without enable_dead_letter_queue, the dead_letter_queue_* outputs must be null."
  }
}

run "standard" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  variables {
    enable_dead_letter_queue = true
  }

  assert {
    condition     = aws_sqs_queue.dead_letter[0].name == "orders-dlq"
    error_message = "Expected the dead-letter queue orders-dlq, got ${aws_sqs_queue.dead_letter[0].name}"
  }
  assert {
    condition = (
      !aws_sqs_queue.dead_letter[0].fifo_queue
      && aws_sqs_queue.dead_letter[0].sqs_managed_sse_enabled
      && aws_sqs_queue.dead_letter[0].message_retention_seconds == 1209600
    )
    error_message = "The dead-letter queue must be standard, SQS-encrypted and keep messages 14 days."
  }
  assert {
    condition = jsondecode(aws_sqs_queue.dead_letter[0].redrive_allow_policy) == {
      redrivePermission = "byQueue"
      sourceQueueArns   = [aws_sqs_queue.queue.arn]
    }
    error_message = "The dead-letter queue must admit the module's queue only: ${aws_sqs_queue.dead_letter[0].redrive_allow_policy}"
  }
  assert {
    condition = (
      aws_sqs_queue_redrive_policy.queue[0].queue_url == aws_sqs_queue.queue.id
      && jsondecode(aws_sqs_queue_redrive_policy.queue[0].redrive_policy) == {
        deadLetterTargetArn = aws_sqs_queue.dead_letter[0].arn
        maxReceiveCount     = 5
      }
    )
    error_message = "The queue must send a message to the dead-letter queue after 5 receives: ${aws_sqs_queue_redrive_policy.queue[0].redrive_policy}"
  }
  assert {
    condition = (
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth[0].dimensions.QueueName == "orders-dlq"
      && aws_cloudwatch_metric_alarm.dead_letter_queue_depth[0].alarm_actions == toset([aws_sns_topic.sqs_alarms.arn])
    )
    error_message = "The depth alarm must watch orders-dlq and notify the module's SNS topic."
  }
  assert {
    condition = (
      output.dead_letter_queue_name == aws_sqs_queue.dead_letter[0].name
      && output.dead_letter_queue_url == aws_sqs_queue.dead_letter[0].id
      && output.dead_letter_queue_arn == aws_sqs_queue.dead_letter[0].arn
    )
    error_message = "The dead_letter_queue_* outputs must name the dead-letter queue."
  }
}

run "fifo" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  variables {
    enable_dead_letter_queue            = true
    fifo_queue                          = true
    queue_name                          = "orders.fifo"
    dead_letter_queue_max_receive_count = 3
  }

  assert {
    condition = (
      aws_sqs_queue.dead_letter[0].name == "orders-dlq.fifo"
      && aws_sqs_queue.dead_letter[0].fifo_queue
    )
    error_message = "Expected the FIFO dead-letter queue orders-dlq.fifo, got ${aws_sqs_queue.dead_letter[0].name}"
  }
  assert {
    condition     = jsondecode(aws_sqs_queue_redrive_policy.queue[0].redrive_policy).maxReceiveCount == 3
    error_message = "maxReceiveCount must follow dead_letter_queue_max_receive_count."
  }
}

run "name_at_the_limit" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  variables {
    enable_dead_letter_queue = true
    // 76 characters, so the dead-letter queue's name is SQS's 80.
    queue_name = "q234567890123456789012345678901234567890123456789012345678901234567890123456"
  }

  assert {
    condition     = length(aws_sqs_queue.dead_letter[0].name) == 80
    error_message = "Expected an 80-character dead-letter queue name."
  }
}

run "name_too_long" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  variables {
    enable_dead_letter_queue = true
    // 77 characters: the dead-letter queue's name would be 81.
    queue_name = "q2345678901234567890123456789012345678901234567890123456789012345678901234567"
  }

  expect_failures = [aws_sqs_queue.dead_letter]
}

run "name_too_long_without_the_option" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  variables {
    // The check is the dead-letter queue's: a long name is fine without one.
    queue_name = "q2345678901234567890123456789012345678901234567890123456789012345678901234567"
  }

  assert {
    condition     = length(aws_sqs_queue.dead_letter) == 0
    error_message = "Without enable_dead_letter_queue, there is no dead-letter queue to check."
  }
}

run "max_receive_count_zero" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  variables {
    dead_letter_queue_max_receive_count = 0
  }

  expect_failures = [var.dead_letter_queue_max_receive_count]
}

run "max_receive_count_above_sqs_range" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  variables {
    dead_letter_queue_max_receive_count = 1001
  }

  expect_failures = [var.dead_letter_queue_max_receive_count]
}

run "max_receive_count_fractional" {
  command = plan

  plan_options {
    target = [
      aws_sqs_queue.queue,
      aws_sqs_queue.dead_letter,
      aws_sqs_queue_redrive_policy.queue,
      aws_cloudwatch_metric_alarm.sqs_age_alarm,
      aws_cloudwatch_metric_alarm.dead_letter_queue_depth,
    ]
  }

  variables {
    dead_letter_queue_max_receive_count = 2.5
  }

  expect_failures = [var.dead_letter_queue_max_receive_count]
}
