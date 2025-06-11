variable "ami_id" {
  description = "AMI id for EC2 instances. By default, latest ECS optimized image."
  type        = string
  default     = null
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG. By default, the number of subnets."
  type        = number
  default     = null
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG. By default, number of subnets plus one."
  type        = number
  default     = null
}

variable "cloudwatch_log_group_retention" {
  description = "Number of days you want to retain log events in the log group."
  default     = 365
  type        = number
}

variable "environment" {
  description = "Environment name string."
  type        = string
}

variable "extra_files" {
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

variable "extra_policies" {
  description = "A map of additional policy ARNs to attach to the consumer instance role."
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "Consumer EC2 Instance type"
  type        = string
  default     = "t3a.micro"
}

variable "keypair_name" {
  description = "SSH key pair name that will be added to the consumer instance.By default, create and use a new SSH keypair."
  type        = string
  default     = null
}

variable "on_demand_base_capacity" {
  description = "If specified, the ASG will request spot instances and this will be the minimal number of on-demand instances."
  type        = number
  default     = null
}


variable "root_volume_size" {
  description = "Root volume size in consumer EC2 instance in Gigabytes"
  type        = number
  default     = 30
}

variable "service_name" {
  description = "A descriptive name for the service that owns the queue."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet ids where the consumer instances will be created."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to add to resources."
  default     = {}
}

variable "target_cpu_load" {
  description = "Target CPU load for autoscaling."
  default     = 60
  type        = number
}
variable "users" {
  description = "A list of maps with user definitions according to the cloud-init format"
  default     = null
  type        = any
  # Check https://cloudinit.readthedocs.io/en/latest/reference/examples.html#including-users-and-groups
  # for fields description and examples.
  #   type = list(
  #     object(
  #       {
  #         name : string
  #         expiredate : optional(string)
  #         gecos : optional(string)
  #         homedir : optional(string)
  #         primary_group : optional(string)
  #         groups : optional(string) # Comma separated list of strings e.g. groups: users, admin
  #         selinux_user : optional(string)
  #         lock_passwd : optional(bool)
  #         inactive : optional(number)
  #         passwd : optional(string)
  #         no_create_home : optional(bool)
  #         no_user_group : optional(bool)
  #         no_log_init : optional(bool)
  #         ssh_import_id : optional(list(string))
  #         ssh_authorized_keys : optional(list(string))
  #         sudo : any # Can be either false or a list of strings e.g. sudo = ["ALL=(ALL) NOPASSWD:ALL"]
  #         system : optional(bool)
  #         snapuser : optional(string)
  #       }
  #     )
  #   )
}
