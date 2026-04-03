# Troubleshooting

## Common Issues

### Tasks not starting

**Symptoms:** ECS tasks remain in PENDING state.

**Possible causes:**

- **Insufficient instance capacity** - The ASG may not have enough
  instances. Check ASG desired count and instance health in the EC2
  console.
- **Resource constraints** - Task CPU/memory quotas may exceed
  available instance resources. Verify `consumer_task_quota_cpu` and
  `consumer_task_quota_memory` fit within the chosen
  `consumer_instance_type`.
- **Image pull failures** - Check the ECS task execution role has
  permission to pull the Docker image. For ECR images, ensure the
  execution role has `ecr:GetDownloadUrlForLayer`,
  `ecr:BatchGetImage`, and `ecr:GetAuthorizationToken`.

### Tasks failing health checks

**Symptoms:** Tasks are repeatedly stopped and restarted.

**Possible causes:**

- The `consumer_task_healthcheck_command` is returning a non-zero
  exit code. The default is `"exit 0"` which always passes. If
  you've customized it, verify the command works inside your
  container.

### Messages not being processed

**Symptoms:** Messages accumulate in the queue.

**Possible causes:**

- **Consumer application error** - Check CloudWatch logs for the ECS service.
- **IAM permissions** - Ensure the task role has
  `sqs:ReceiveMessage`, `sqs:DeleteMessage`, and
  `sqs:GetQueueAttributes` on the queue.
- **Networking** - Consumer instances need network access to SQS
  endpoints. Ensure VPC endpoints or NAT gateway are configured.

### Scaling not working

**Symptoms:** Service doesn't scale up despite high queue depth.

**Possible causes:**

- **Scaling cooldown** - ECS auto-scaling has cooldown periods. Wait a few minutes for metrics to stabilize.
- **Max capacity reached** - Check if `consumer_task_max_count` or `consumer_asg_max_size` limits are hit.
- **CloudWatch metrics lag** - SQS metrics update every 5 minutes. Scaling decisions may be delayed.

### CloudWatch alarm always in ALARM state

**Symptoms:** The SQS age alarm fires immediately.

**Possible causes:**

- Messages are not being processed fast enough. Scale up by
  increasing `consumer_task_max_count` or using a larger
  `consumer_instance_type`.
- Consumer application is crashing. Check CloudWatch logs.

## Checking Logs

Consumer container logs are sent to CloudWatch Logs. Find the log
group in the AWS console under CloudWatch > Log groups, named after
your service.

```bash
aws logs tail /ecs/YOUR_SERVICE_NAME --follow
```

## Getting Help

- [Open an issue](https://github.com/infrahouse/terraform-aws-sqs-ecs/issues) on GitHub
- See [CONTRIBUTING.md](https://github.com/infrahouse/terraform-aws-sqs-ecs/blob/main/CONTRIBUTING.md)
  for development setup
