variable "asg_arn" {
  description = "ASG ARN that is a capacity provider for the cluster."
  type        = string
}

variable "enable_cloudwatch_logs" {
  description = "Deploy the CloudWatch agent as a DAEMON ECS service."
  type        = bool
}

variable "cloudwatch_agent_image" {
  description = "CloudWatch agent container image."
  type        = string
}

variable "cloudwatch_agent_config_path" {
  description = "Host path where the CloudWatch agent config is mounted from."
  type        = string
}

variable "enable_vector_agent" {
  description = "Deploy the Vector Agent as a DAEMON ECS service."
  type        = bool
}

variable "vector_agent_image" {
  description = "Vector Agent container image."
  type        = string
}

variable "vector_agent_config_path" {
  description = "Host path where the Vector Agent config is mounted from."
  type        = string
}

variable "vector_aggregator_endpoint" {
  description = "Vector Aggregator endpoint. Required when enable_vector_agent is true and vector_agent_config is null."
  type        = string
}

variable "vector_agent_config" {
  description = "Custom Vector Agent config. When non-null, vector_aggregator_endpoint is not required."
  type        = string
}

variable "vector_agent_task_policy_arns" {
  description = "IAM policy ARNs to attach to the Vector Agent task role."
  type        = list(string)
}

variable "cloudwatch_log_group_retention" {
  description = "Number of days you want to retain log events in the log group."
  type        = number
}

variable "container_commands" {
  description = "If specified, use this list of strings as a docker command."
  type        = list(string)
}

variable "container_healthcheck_command" {
  description = "A shell command that a container runs to check if it's healthy. Exit code 0 means healthy, non-zero - unhealthy."
  type        = string
}

variable "container_quota_cpu" {
  description = "Number of CPU units that a container is going to use."
  type        = number
}

variable "container_quota_memory" {
  description = "Amount of RAM in megabytes the container is going to use."
  type        = number
}

variable "dependencies" {
  description = "Injected module dependencies. A map of a resource name as a key and a value"
  type        = map(string)
  default     = {}
}

variable "docker_image" {
  description = "A container image that will run the service."
  type        = string
}

variable "environment" {
  description = "Name of environment."
  type        = string
}

variable "queue_name" {
  description = "SQS queue name."
  type        = string
}

variable "service_name" {
  description = "A descriptive name for the service that owns the queue."
  type        = string
}

variable "service_target_backlog_size" {
  description = "Target number of messages in a SQS backlog per task."
  type        = number
}

variable "task_environment_variables" {
  description = "Environment variables passed down to a task."
  type = list(
    object(
      {
        name : string
        value : string
      }
    )
  )
}

variable "task_execution_extra_policies" {
  description = "A map of extra policies attached to the task execution role. The key is an arbitrary string, the value is the policy ARN."
  type        = map(string)
}

variable "task_role_extra_policies" {
  description = "A map of extra policies attached to the task role. The key is an arbitrary string, the value is the policy ARN."
  type        = map(string)
}

variable "task_max_count" {
  description = "Highest number of tasks to run"
  type        = number
}

variable "task_min_count" {
  description = "Lowest number of tasks to run"
  type        = number
}

variable "task_secrets" {
  description = "Secrets to pass to a container. A `name` will be the environment variable. valueFrom is a secret ARN."
  type = list(
    object(
      {
        name : string
        valueFrom : string
      }
    )
  )
}

variable "task_volumes_efs" {
  description = "Map name->{file_system_id, container_path} of EFS volumes defined in task and available for containers to mount."
  type = map(
    object(
      {
        file_system_id : string
        container_path : string
      }
    )
  )
}

variable "task_volumes_local" {
  description = "Map name->{host_path, container_path} of local volumes defined in task and available for containers to mount."
  type = map(
    object(
      {
        host_path : string
        container_path : string
      }
    )
  )
}
