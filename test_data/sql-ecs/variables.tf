variable "region" {}
variable "role_arn" {
  default = null
}
variable "consumer_subnet_ids" {}
variable "ubuntu_codename" {
  default = "noble"
}

variable "enable_cloudwatch_logs" {
  type    = bool
  default = true
}

variable "enable_vector_agent" {
  type    = bool
  default = false
}

variable "consumer_task_quota_memory" {
  type    = number
  default = 128
}

variable "consumer_task_quota_memory_reservation" {
  type    = number
  default = null
}

variable "vector_aggregator_endpoint" {
  type    = string
  default = null
}

variable "fifo_queue" {
  type    = bool
  default = false
}

variable "queue_name" {
  type    = string
  default = null
}

variable "enable_dead_letter_queue" {
  type    = bool
  default = false
}

variable "run_test_consumer" {
  description = <<-EOT
    Run files/consumer.py, which consumes the queue's messages, instead of httpd,
    which reads nothing. tests/test_dead_letter_queue.py needs its message left alone.
  EOT
  type        = bool
  default     = false
}

variable "consumer_ami_id" {
  type    = string
  default = null
}
