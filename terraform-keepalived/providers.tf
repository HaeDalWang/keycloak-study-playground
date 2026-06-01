terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.43.0"
    }
  }
}

locals {
  project = "kc-keepalived"
  tags    = { terraform = true }
}

provider "aws" {
  default_tags {
    tags = local.tags
  }
}
