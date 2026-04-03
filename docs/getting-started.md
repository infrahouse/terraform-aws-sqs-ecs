# Getting Started

## Prerequisites

- Terraform >= 1.0
- AWS Provider >= 5.62
- An AWS account with permissions to create SQS, ECS, EC2, IAM, and CloudWatch resources
- VPC with private subnets for the consumer instances
- A Docker image for your SQS consumer application

## First Deployment

### 1. Basic Configuration

```hcl
module "sqs_consumer" {
  source  = "registry.infrahouse.com/infrahouse/sqs-ecs/aws"
  version = "2.0.0"

  service_name            = "order-processor"
  consumer_subnet_ids     = ["subnet-abc123", "subnet-def456"]
  consumer_docker_image   = "my-org/order-processor:latest"
  alert_notification_email = "ops@example.com"
}
```

### 2. Apply

```bash
terraform init
terraform plan
terraform apply
```

### 3. Verify

After applying, check the outputs:

```bash
terraform output queue_url
terraform output service_name
```

Your ECS service will start running consumer containers that poll the SQS queue for messages.

## What Gets Created

- **SQS Queue** - Server-side encrypted message queue
- **ECS Cluster** - Container orchestration
- **ECS Service** - Manages consumer task lifecycle
- **EC2 Auto Scaling Group** - Provides compute capacity for ECS tasks
- **IAM Roles** - Task role, task execution role, and instance profile
- **CloudWatch Log Group** - Container log aggregation
- **CloudWatch Alarm** - SQS message age monitoring
- **SNS Topic** - Alert notifications

## Next Steps

- [Architecture](architecture.md) - Understand how scaling works
- [Configuration](configuration.md) - Customize all variables
- [Examples](examples.md) - See common use cases
