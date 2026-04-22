# Examples

## Basic SQS Consumer

Minimal configuration with default settings:

```hcl
module "sqs_consumer" {
  source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"
  version = "2.0.1"

  service_name             = "order-processor"
  consumer_subnet_ids      = var.private_subnet_ids
  consumer_docker_image    = "my-org/order-processor:latest"
  alert_notification_email = "ops@example.com"
}
```

## Spot Instance Consumer

Use spot instances for cost savings with one on-demand instance as a baseline:

```hcl
module "sqs_consumer" {
  source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"
  version = "2.0.1"

  service_name                     = "batch-processor"
  consumer_subnet_ids              = var.private_subnet_ids
  consumer_docker_image            = "my-org/batch-processor:latest"
  alert_notification_email         = "ops@example.com"
  consumer_on_demand_base_capacity = 1
}
```

## High-Throughput Consumer

Larger instances with more tasks for high message volume:

```hcl
module "sqs_consumer" {
  source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"
  version = "2.0.1"

  service_name             = "event-processor"
  consumer_subnet_ids      = var.private_subnet_ids
  consumer_docker_image    = "my-org/event-processor:latest"
  alert_notification_email = "ops@example.com"

  consumer_instance_type      = "c5.xlarge"
  consumer_task_quota_cpu     = 512
  consumer_task_quota_memory  = 512
  consumer_task_max_count     = 20
  consumer_target_backlog_size = 50
  consumer_target_cpu_load    = 70
}
```

## Consumer with Secrets

Pass secrets from AWS Secrets Manager to the container:

```hcl
module "sqs_consumer" {
  source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"
  version = "2.0.1"

  service_name             = "api-consumer"
  consumer_subnet_ids      = var.private_subnet_ids
  consumer_docker_image    = "my-org/api-consumer:latest"
  alert_notification_email = "ops@example.com"

  consumer_task_secrets = [
    {
      name      = "DATABASE_URL"
      valueFrom = aws_secretsmanager_secret.db_url.arn
    },
    {
      name      = "API_KEY"
      valueFrom = aws_secretsmanager_secret.api_key.arn
    },
  ]

  consumer_task_execution_extra_policies = {
    secrets = aws_iam_policy.read_secrets.arn
  }
}
```

## Consumer with EFS Volume

Mount an EFS filesystem for shared storage:

```hcl
module "sqs_consumer" {
  source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"
  version = "2.0.1"

  service_name             = "file-processor"
  consumer_subnet_ids      = var.private_subnet_ids
  consumer_docker_image    = "my-org/file-processor:latest"
  alert_notification_email = "ops@example.com"

  consumer_task_volumes_efs = {
    shared-data = {
      file_system_id = aws_efs_file_system.shared.id
      container_path = "/mnt/shared"
    }
  }
}
```

## FIFO Queue Consumer

Process messages in order with a FIFO queue:

```hcl
module "sqs_consumer" {
  source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"
  version = "2.0.1"

  service_name             = "ordered-processor"
  consumer_subnet_ids      = var.private_subnet_ids
  consumer_docker_image    = "my-org/ordered-processor:latest"
  alert_notification_email = "ops@example.com"
  fifo_queue               = true
}
```

## Custom Docker Command

Override the container's default command:

```hcl
module "sqs_consumer" {
  source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"
  version = "2.0.1"

  service_name             = "custom-consumer"
  consumer_subnet_ids      = var.private_subnet_ids
  consumer_docker_image    = "my-org/worker:latest"
  alert_notification_email = "ops@example.com"

  consumer_task_commands = ["python", "-m", "worker", "--queue-mode"]

  consumer_task_environment_variables = [
    {
      name  = "LOG_LEVEL"
      value = "INFO"
    },
    {
      name  = "WORKER_CONCURRENCY"
      value = "4"
    },
  ]
}
```
