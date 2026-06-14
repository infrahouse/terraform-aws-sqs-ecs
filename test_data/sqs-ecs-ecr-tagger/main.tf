resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

data "aws_caller_identity" "this" {}

resource "aws_ecr_repository" "test" {
  name         = local.service_name
  force_delete = true
}

resource "null_resource" "push_image" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${var.region} \
        | docker login --username AWS --password-stdin \
          ${data.aws_caller_identity.this.account_id}.dkr.ecr.${var.region}.amazonaws.com
      # Force linux/amd64: the ECS hosts are x86_64 (t3a.small), but on an
      # arm64 build host (e.g. Apple Silicon) a plain pull would fetch the
      # arm64 image, and the container would die with "exec format error".
      docker pull --platform linux/amd64 httpd:latest
      docker tag httpd:latest ${aws_ecr_repository.test.repository_url}:latest
      docker push ${aws_ecr_repository.test.repository_url}:latest
    EOT
  }
  depends_on = [aws_ecr_repository.test]
}

# Thread null_resource.push_image.id into the image URI so Terraform waits for
# the push to complete before creating the ECS service, without a module-level
# depends_on (which poisons the plan). substr(..., 0, 0) appends an empty
# string, so the URI value is unchanged.
locals {
  ecr_image = "${aws_ecr_repository.test.repository_url}:latest${substr(null_resource.push_image.id, 0, 0)}"
}

module "test" {
  source                   = "./../../"
  environment              = "development"
  service_name             = local.service_name
  consumer_subnet_ids      = var.consumer_subnet_ids
  consumer_docker_image    = local.ecr_image
  consumer_asg_max_size    = 1
  consumer_asg_min_size    = 1
  consumer_instance_type   = "t3a.small"
  alert_notification_email = "devnull@infrahouse.com"
  enable_cloudwatch_logs   = true
  enable_ecr_image_tagging = true
}
