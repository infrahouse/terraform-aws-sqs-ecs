variable "region" {}
variable "role_arn" {
  default = null
}
variable "consumer_subnet_ids" {}
variable "consumer_ami_id" {
  type = string
}
