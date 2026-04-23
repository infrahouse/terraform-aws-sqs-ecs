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

variable "vector_aggregator_endpoint" {
  type    = string
  default = null
}
