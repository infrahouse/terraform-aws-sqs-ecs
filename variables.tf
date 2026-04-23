variable "alert_notification_email" {
  description = "Email address to receive alert notifications."
  type        = string
}

variable "log_retention_days" {
  description = "Number of days you want to retain log events in a log group."
  type        = number
  default     = 365
}

variable "consumer_ami_id" {
  description = "AMI id for EC2 instances. By default, latest ECS optimized image."
  type        = string
  default     = null
}

variable "consumer_asg_min_size" {
  description = "Minimum number of instances in ASG. By default, the number of subnets."
  type        = number
  default     = null
}

variable "consumer_asg_max_size" {
  description = "Minimum number of instances in ASG. By default, calculated from var.consumer_task_max_count."
  type        = number
  default     = null
}

variable "consumer_task_commands" {
  description = "If specified, use this list of strings as a docker command."
  type        = list(string)
  default     = null
}

variable "consumer_task_healthcheck_command" {
  description = "A shell command that a container runs to check if it's healthy. Exit code 0 means healthy, non-zero - unhealthy."
  type        = string
  default     = "exit 0"
}

variable "consumer_docker_image" {
  description = "A container image that will run the consumer application."
  type        = string
}

variable "consumer_task_environment_variables" {
  description = "Environment variables passed down to a task."
  type = list(
    object(
      {
        name : string
        value : string
      }
    )
  )
  default = []
}

variable "consumer_task_execution_extra_policies" {
  description = "A map of extra policies attached to the task execution role. The key is an arbitrary string, the value is the policy ARN."
  type        = map(string)
  default     = {}
}

variable "consumer_task_role_extra_policies" {
  description = "A map of extra policies attached to the task role. The key is an arbitrary string, the value is the policy ARN."
  type        = map(string)
  default     = {}
}

variable "consumer_task_secrets" {
  description = "Secrets to pass to a container. A `name` will be the environment variable. valueFrom is a secret ARN."
  type = list(
    object(
      {
        name : string
        valueFrom : string
      }
    )
  )
  default = []
}

variable "consumer_task_volumes_efs" {
  description = "Map name->{file_system_id, container_path} of EFS volumes defined in task and available for containers to mount."
  type = map(
    object(
      {
        file_system_id : string
        container_path : string
      }
    )
  )
  default = {}
}

variable "consumer_task_volumes_local" {
  description = "Map name->{host_path, container_path} of local volumes defined in task and available for containers to mount."
  type = map(
    object(
      {
        host_path : string
        container_path : string
      }
    )
  )
  default = {}
}

variable "consumer_on_demand_base_capacity" {
  description = "If specified, the ASG will request spot instances and this will be the minimal number of on-demand instances."
  type        = number
  default     = null
}

variable "consumer_task_quota_cpu" {
  description = "Number of CPU units that a container is going to use. One vCPU is equal to 1024 CPU units."
  type        = number
  default     = 200
}

variable "consumer_task_quota_memory" {
  description = "Amount of RAM in megabytes the container is going to use."
  type        = number
  default     = 128
}

variable "consumer_task_min_count" {
  description = "Minimal number of ECS tasks. By default, calculated from var.consumer_asg_min_size."
  type        = number
  default     = null
}

variable "consumer_task_max_count" {
  description = "Maximum number of ECS tasks. By default, calculated from consumer_asg_max_size."
  type        = number
  default     = null
}

variable "consumer_target_backlog_size" {
  description = "Target number of messages in the SQS backlog per task in ECS service."
  default     = 100
  type        = number
}

variable "consumer_target_cpu_load" {
  description = "Target CPU load for autoscaling."
  default     = 60
  type        = number
}



variable "consumer_extra_files" {
  description = "Additional files to create on a host EC2 instance."
  type = list(
    object(
      {
        content     = string
        path        = string
        permissions = string
      }
    )
  )
  default = []
}

variable "consumer_extra_policies" {
  description = "A map of additional policy ARNs to attach to the consumer instance role."
  type        = map(string)
  default     = {}
}

variable "consumer_instance_type" {
  description = "Consumer EC2 Instance type"
  type        = string
  default     = "t3a.small"
}

variable "consumer_keypair_name" {
  description = "SSH key pair name that will be added to the consumer instance.By default, create and use a new SSH keypair."
  type        = string
  default     = null
}

variable "consumer_root_volume_size" {
  description = "Root volume size in consumer EC2 instance in Gigabytes"
  type        = number
  default     = 30
}

variable "consumer_subnet_ids" {
  description = "List of subnet ids where the consumer instances will be created."
  type        = list(string)
}

variable "environment" {
  description = "Environment name string."
  type        = string
}

variable "fifo_queue" {
  description = "If true, the queue supports FIFO queue behavior."
  type        = bool
  default     = false
}

variable "queue_name" {
  description = "Name of the queue."
  type        = string
  default     = null
}

variable "service_name" {
  description = "A descriptive name for the service that owns the queue."
  type        = string
}

variable "tags" {
  description = "A map of tags to add to resources."
  type        = map(string)
  default     = {}
}

variable "enable_cloudwatch_logs" {
  description = <<-EOT
    Deploy a CloudWatch agent daemon on every EC2 instance in this cluster.
    Tails host log files (/var/log/messages, /var/log/dmesg) into CloudWatch log groups.

    Does not affect container stdout/stderr, which is always shipped via the Docker
    awslogs driver configured on the task definition.
  EOT
  type        = bool
  default     = true
}

variable "cloudwatch_agent_image" {
  description = "CloudWatch agent container image."
  type        = string
  default     = "amazon/cloudwatch-agent:latest"
}

variable "enable_vector_agent" {
  description = <<-EOT
    Deploy a Vector Agent daemon on every EC2 instance in this cluster.
    Collects container logs (via Docker socket) and host metrics, forwards to a
    Vector Aggregator. Requires vector_aggregator_endpoint or vector_agent_config.
  EOT
  type        = bool
  default     = false
}

variable "vector_agent_image" {
  description = "Vector Agent container image."
  type        = string
  default     = "timberio/vector:0.43.1-alpine"
}

variable "vector_aggregator_endpoint" {
  description = <<-EOT
    Vector Aggregator address (host:port) for the agent to forward data to.
    Used by the default config template. Ignored if vector_agent_config is set.

    Example: "vector-aggregator.sandbox.tinyfish.io:6000"
  EOT
  type        = string
  default     = null
}

variable "vector_agent_config" {
  description = <<-EOT
    Custom Vector Agent config (YAML string). When provided, replaces the
    built-in default config template entirely.
  EOT
  type        = string
  default     = null
}

variable "vector_agent_task_policy_arns" {
  description = <<-EOT
    List of IAM policy ARNs to attach to the Vector Agent task role.
    The default config (Docker logs + host metrics forwarded to an aggregator)
    needs no AWS permissions. Add policies here if your Vector config uses AWS
    sinks (S3, CloudWatch, Kinesis, etc.).
  EOT
  type        = list(string)
  default     = []
}
