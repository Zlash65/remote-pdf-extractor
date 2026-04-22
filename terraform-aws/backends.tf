terraform {
  backend "remote" {
    organization = "core-services"

    workspaces {
      prefix = "remote-pdf-extractor-aws-"
    }
  }

  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
