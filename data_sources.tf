data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_subnet" "selected" {
  id = var.consumer_subnet_ids[0]
}

data "aws_ec2_instance_type" "consumer" {
  instance_type = var.consumer_instance_type
}
