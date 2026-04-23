resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.service_name}-${var.environment}"
  dashboard_body = jsonencode({
    widgets = concat(
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 1
          properties = {
            markdown = "# ${var.service_name} (${var.environment}) — SQS queue + ECS consumer"
          }
        },

        # === SQS Section ===
        {
          type   = "text"
          x      = 0
          y      = 1
          width  = 24
          height = 4
          properties = {
            markdown = join("", [
              "## SQS — work queue feeding the consumers\n",
              "**Backlog** — *Visible* messages are waiting for a worker to pick them up. ",
              "*NotVisible* are already in flight (a worker pulled them and is processing). ",
              "The autoscaler scales ECS tasks to keep *Visible / RunningTasks* at ",
              "`consumer_target_backlog_size` (currently **${var.consumer_target_backlog_size}**).\n\n",
              "**Oldest message age** — how long the oldest Visible message has been waiting. ",
              "Growing age with a growing backlog means consumers can't keep up. ",
              "Alarm fires at 1h (configurable via `sqs_age_alarm_threshold_seconds`).\n\n",
              "**Throughput** — `Sent` = producers publishing. `Received` = workers pulling. ",
              "`Deleted` = workers finishing successfully. A gap between Received and Deleted ",
              "means messages are failing processing and going back to the queue (or to the DLQ).",
            ])
          }
        },

        # --- Row 1: SQS queue ---
        {
          type   = "metric"
          x      = 0
          y      = 5
          width  = 8
          height = 6
          properties = {
            title   = "SQS backlog (messages)"
            region  = data.aws_region.current.name
            view    = "timeSeries"
            stacked = false
            period  = 60
            stat    = "Maximum"
            metrics = [
              [
                "AWS/SQS",
                "ApproximateNumberOfMessagesVisible",
                "QueueName",
                aws_sqs_queue.queue.name,
                { label = "Visible (waiting)" }
              ],
              [".", "ApproximateNumberOfMessagesNotVisible", ".", ".", { label = "NotVisible (in flight)" }]
            ]
            yAxis = {
              left = { min = 0 }
            }
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 5
          width  = 8
          height = 6
          properties = {
            title   = "Oldest message age (seconds)"
            region  = data.aws_region.current.name
            view    = "timeSeries"
            stacked = false
            period  = 60
            stat    = "Maximum"
            metrics = [
              ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", aws_sqs_queue.queue.name, { label = "Oldest age" }]
            ]
            yAxis = {
              left = { min = 0 }
            }
            annotations = {
              horizontal = [
                {
                  label = "Alarm: ${aws_cloudwatch_metric_alarm.sqs_age_alarm.threshold}s"
                  value = aws_cloudwatch_metric_alarm.sqs_age_alarm.threshold
                  fill  = "above"
                  color = "#d62728"
                }
              ]
            }
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 5
          width  = 8
          height = 6
          properties = {
            title   = "Message throughput (per minute)"
            region  = data.aws_region.current.name
            view    = "timeSeries"
            stacked = false
            period  = 60
            stat    = "Sum"
            metrics = [
              ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.queue.name, { label = "Sent (produced)" }],
              [".", "NumberOfMessagesReceived", ".", ".", { label = "Received (pulled by workers)" }],
              [".", "NumberOfMessagesDeleted", ".", ".", { label = "Deleted (processed OK)" }]
            ]
            yAxis = {
              left = { min = 0 }
            }
          }
        },

        # === ECS consumer Section ===
        {
          type   = "text"
          x      = 0
          y      = 11
          width  = 24
          height = 3
          properties = {
            markdown = join("", [
              "## ECS — Consumer tasks draining the queue\n",
              "**CPU & Memory utilization** — Percentage of *reserved* resources actually used ",
              "across all running tasks. Sustained high CPU means each task is saturated; the ",
              "autoscaler will add tasks until the backlog-per-task target is hit.\n\n",
              "**Backlog per task** — *Visible messages / RunningTasks*. This is the signal the ",
              "ECS target-tracking policy watches. Line should hover near ",
              "**${var.consumer_target_backlog_size}** (the target). Sustained higher means ",
              "we're below max tasks and scaling up; sustained lower means we're over-provisioned. ",
              "The Running/Desired bars on the right show whether ECS is actually getting the ",
              "tasks it asked for — a persistent gap means no EC2 capacity (check the ASG panel).",
            ])
          }
        },

        # --- Row 2: ECS service ---
        {
          type   = "metric"
          x      = 0
          y      = 14
          width  = 8
          height = 6
          properties = {
            title  = "ECS service CPU / Memory utilization (%)"
            region = data.aws_region.current.name
            view   = "timeSeries"
            period = 60
            stat   = "Average"
            metrics = [
              ["AWS/ECS", "CPUUtilization", "ClusterName", var.service_name, "ServiceName", module.ecs.service_name, { label = "CPU" }],
              [".", "MemoryUtilization", ".", ".", ".", ".", { label = "Memory" }]
            ]
            yAxis = {
              left = { min = 0, max = 100 }
            }
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 14
          width  = 8
          height = 6
          properties = {
            title  = "Backlog per task (messages/task)"
            region = data.aws_region.current.name
            view   = "timeSeries"
            period = 60
            metrics = [
              ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.queue.name, { id = "m1", visible = false, stat = "Sum" }],
              ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.service_name, "ServiceName", module.ecs.service_name, { id = "m2", visible = false, stat = "Average" }],
              [{ expression = "m1 / m2", label = "Visible / RunningTasks", id = "e1" }]
            ]
            yAxis = {
              left = { min = 0 }
            }
            annotations = {
              horizontal = [
                {
                  label = "Scaling target (${var.consumer_target_backlog_size})"
                  value = var.consumer_target_backlog_size
                  color = "#2ca02c"
                }
              ]
            }
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 14
          width  = 8
          height = 6
          properties = {
            title  = "Task count (Running vs Desired)"
            region = data.aws_region.current.name
            view   = "timeSeries"
            period = 60
            metrics = [
              ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.service_name, "ServiceName", module.ecs.service_name, { stat = "Average", label = "Running" }],
              [".", "DesiredTaskCount", ".", ".", ".", ".", { stat = "Average", label = "Desired" }],
              [".", "PendingTaskCount", ".", ".", ".", ".", { stat = "Average", label = "Pending (waiting for EC2)" }]
            ]
            yAxis = {
              left = { min = 0 }
            }
            annotations = {
              horizontal = [
                { label = "task_min_count", value = module.scaling.task_min_count, color = "#2ca02c" },
                { label = "task_max_count", value = module.scaling.task_max_count, color = "#d62728" }
              ]
            }
          }
        },

        # === Infrastructure capacity Section ===
        {
          type   = "text"
          x      = 0
          y      = 20
          width  = 24
          height = 4
          properties = {
            markdown = join("", [
              "## Infrastructure — EC2 hosts providing the compute\n",
              "ECS tasks run on EC2 instances in an Auto Scaling Group. If the ASG doesn't ",
              "have room for the tasks ECS wants, you'll see *Pending* tasks on the ECS panel ",
              "above and the ASG will scale up.\n\n",
              "**ASG capacity** — How many instances are in service vs desired vs max. ",
              "Desired climbing toward Max means we're running out of headroom.\n\n",
              "**Capacity provider reservation** — ECS's signal for when to add/remove EC2 ",
              "hosts. **100%** = perfect fit (tasks exactly fill the cluster). **>100%** = ",
              "ECS wants more instances than the ASG currently has (scale-out imminent). ",
              "**<100%** = cluster is over-provisioned (scale-in imminent).",
            ])
          }
        },

        # --- Row 3: Infrastructure capacity ---
        {
          type   = "metric"
          x      = 0
          y      = 24
          width  = 12
          height = 6
          properties = {
            title  = "ASG capacity (instances)"
            region = data.aws_region.current.name
            view   = "timeSeries"
            period = 60
            stat   = "Average"
            metrics = [
              ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", module.asg.asg_name, { label = "In service" }],
              [".", "GroupDesiredCapacity", ".", ".", { label = "Desired" }],
              [".", "GroupMaxSize", ".", ".", { label = "Max" }]
            ]
            yAxis = {
              left = { min = 0 }
            }
            annotations = {
              horizontal = [
                { label = "asg_min_size", value = module.scaling.asg_min_size, color = "#2ca02c" },
                { label = "asg_max_size", value = module.scaling.asg_max_size, color = "#d62728" }
              ]
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 24
          width  = 12
          height = 6
          properties = {
            title  = "ECS capacity provider reservation (%)"
            region = data.aws_region.current.name
            view   = "timeSeries"
            period = 60
            stat   = "Average"
            metrics = [
              ["AWS/ECS/ManagedScaling", "CapacityProviderReservation", "ClusterName", var.service_name, "CapacityProviderName", var.service_name, { label = "Reservation" }]
            ]
            yAxis = {
              left = { min = 0 }
            }
            annotations = {
              horizontal = [
                {
                  label = "Perfect fit (100%)"
                  value = 100
                  color = "#2ca02c"
                }
              ]
            }
          }
        },

        # === Logs Section ===
        {
          type   = "text"
          x      = 0
          y      = 30
          width  = 24
          height = 3
          properties = {
            markdown = join("", [
              "## Logs — What the workers (and hosts) are saying\n",
              "Most recent log lines. Click a line to expand. Use the CloudWatch Logs Insights ",
              "console for full search/filter. **Container stdout** is your app's logs. ",
              "**Host syslog/dmesg** panels appear when the CloudWatch agent is enabled ",
              "(`enable_cloudwatch_logs = true`) and are most useful when an instance ",
              "misbehaves at the OS level (OOM killer, disk full, kernel errors).",
            ])
          }
        },

        # --- Row 4: Container logs ---
        {
          type   = "log"
          x      = 0
          y      = 33
          width  = 24
          height = 6
          properties = {
            title  = "Container stdout (recent)"
            region = data.aws_region.current.name
            query  = "SOURCE '/ecs/${var.environment}/${var.service_name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
            view   = "table"
          }
        }
      ],

      # --- Row 5 (conditional): Host log groups (only when CloudWatch agent is enabled) ---
      var.enable_cloudwatch_logs ? [
        {
          type   = "log"
          x      = 0
          y      = 39
          width  = 12
          height = 6
          properties = {
            title  = "Host syslog"
            region = data.aws_region.current.name
            query  = "SOURCE '/ecs/${var.environment}/${var.service_name}-syslog' | fields @timestamp, @message | sort @timestamp desc | limit 100"
            view   = "table"
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 39
          width  = 12
          height = 6
          properties = {
            title  = "Host dmesg"
            region = data.aws_region.current.name
            query  = "SOURCE '/ecs/${var.environment}/${var.service_name}-dmesg' | fields @timestamp, @message | sort @timestamp desc | limit 100"
            view   = "table"
          }
        }
      ] : []
    )
  })
}
