variable "instance_memory_available_mib" {
  type        = number
  description = "Memory (MiB) available per EC2 instance for ECS tasks, net of host OS and agent reservations."
}

variable "instance_cpu_available_units" {
  type        = number
  description = "CPU units available per EC2 instance for ECS tasks, net of agent reservations."
}

variable "task_quota_cpu" {
  type        = number
  description = "CPU units requested by one consumer task."
}

variable "task_quota_memory" {
  type        = number
  description = "Memory (MiB) requested by one consumer task."
}

variable "subnet_count" {
  type        = number
  description = "Number of subnets the ASG will span. Used as the default for asg_min_size and asg_max_size."
}

variable "consumer_asg_min_size" {
  type        = number
  description = "User-provided ASG min size. If null, defaults to subnet_count."
  default     = null
}

variable "consumer_asg_max_size" {
  type        = number
  description = "User-provided ASG max size. If null, derived from consumer_task_max_count or subnet_count+1."
  default     = null
}

variable "consumer_task_min_count" {
  type        = number
  description = "User-provided ECS task min count. If null, derived as asg_min_size * tasks_per_instance."
  default     = null
}

variable "consumer_task_max_count" {
  type        = number
  description = "User-provided ECS task max count. If null, derived as asg_max_size * tasks_per_instance."
  default     = null
}
