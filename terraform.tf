terraform {
  //noinspection HILUnresolvedReference
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Floor is 6.0: the lambda-monitored module used by the optional ECR
      # image tagger (modules/ecs/ecr_image_tagger.tf) transitively requires
      # aws >= 6.0, and Terraform loads that requirement even when the feature
      # is disabled (count = 0).
      version = ">= 6.0, < 7"
    }
  }
}
