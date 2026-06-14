check "ecr_image_tagging_requires_ecr_uri" {
  assert {
    condition = (
      var.enable_ecr_image_tagging
      ? can(regex("dkr\\.ecr\\.[^.]+\\.amazonaws\\.com/", var.docker_image))
      : true
    )
    error_message = "docker_image must be an ECR URI when enable_ecr_image_tagging is true. Got: ${var.docker_image}"
  }
}

locals {
  default_module_tags = {}
  cloudwatch_group    = "/ecs/${var.environment}/${var.service_name}"

  # ECR repository ARN extracted from var.docker_image for scoped IAM permissions.
  # ECR URI format: ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO:TAG or /REPO@sha256:DIGEST
  # The can() wrapper prevents a plan-time crash if docker_image is not an ECR URI
  # (the check block above warns the user with a clear message).
  ecr_image_repo_arn = (
    var.enable_ecr_image_tagging && can(regex("dkr\\.ecr\\.([^.]+)\\.amazonaws\\.com", var.docker_image))
    ? "arn:aws:ecr:${
      regex("dkr\\.ecr\\.([^.]+)\\.amazonaws\\.com", var.docker_image)[0]
      }:${
      data.aws_caller_identity.current.account_id
      }:repository/${
      regex("amazonaws\\.com/([^:@]+)", var.docker_image)[0]
    }"
    : null
  )
}
