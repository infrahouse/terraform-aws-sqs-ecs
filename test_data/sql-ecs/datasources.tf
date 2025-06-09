data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  boostrap_script_path = "/usr/local/bin/consumer-bootstrap.sh"
}
