# Configuration

## Required Variables

| Variable | Description |
|----------|-------------|
| `service_name` | A descriptive name for the service that owns the queue |
| `consumer_subnet_ids` | List of subnet IDs where consumer instances will be created |
| `consumer_docker_image` | Docker image for the consumer container |
| `alert_notification_email` | Email address for alert notifications |

## Queue Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `queue_name` | `null` | Name of the SQS queue. If null, AWS generates a name |
| `fifo_queue` | `false` | Enable FIFO queue behavior |

## Instance Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `consumer_instance_type` | `t3a.small` | EC2 instance type for consumer hosts |
| `consumer_ami_id` | `null` | AMI ID. Defaults to latest ECS-optimized image |
| `consumer_keypair_name` | `null` | SSH key pair name for instances |
| `consumer_root_volume_size` | `30` | Root volume size in GB |
| `consumer_on_demand_base_capacity` | `null` | Minimum on-demand instances (enables spot if set) |
| `consumer_extra_files` | `[]` | Additional files to create on host instances |
| `consumer_extra_policies` | `{}` | Additional IAM policy ARNs for instance role |

## Task Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `consumer_task_quota_cpu` | `200` | CPU units per task (1 vCPU = 1024) |
| `consumer_task_quota_memory` | `128` | Memory in MB per task |
| `consumer_task_commands` | `null` | Docker command override |
| `consumer_task_environment_variables` | `[]` | Environment variables for the task |
| `consumer_task_secrets` | `[]` | Secrets from Secrets Manager |
| `consumer_task_healthcheck_command` | `"exit 0"` | Health check shell command |
| `consumer_task_volumes_efs` | `{}` | EFS volume mounts |
| `consumer_task_volumes_local` | `{}` | Local volume mounts |
| `consumer_task_execution_extra_policies` | `{}` | Extra policies for task execution role |
| `consumer_task_role_extra_policies` | `{}` | Extra policies for task role |

## Scaling Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `consumer_asg_min_size` | `null` | Minimum ASG instances (defaults to subnet count) |
| `consumer_asg_max_size` | `null` | Maximum ASG instances (calculated from task max) |
| `consumer_task_min_count` | `null` | Minimum ECS tasks (calculated from ASG min) |
| `consumer_task_max_count` | `null` | Maximum ECS tasks (calculated from ASG max) |
| `consumer_target_cpu_load` | `60` | Target CPU utilization percentage |
| `consumer_target_backlog_size` | `100` | Target messages per task |

## Other

| Variable | Default | Description |
|----------|---------|-------------|
| `environment` | `"development"` | Environment name |
| `log_retention_days` | `365` | CloudWatch log retention in days |
| `tags` | `{}` | Additional resource tags |
