terraform {
  required_version = "~> 1.5"
  //noinspection HILUnresolvedReference
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.62"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
