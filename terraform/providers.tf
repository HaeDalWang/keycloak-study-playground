# 요구되는 테라폼 제공자 목록
terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.43.0"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.7.0"
    }
  }
}

locals {
  project             = "ezl-keycloak"
  service_domain_name = "keycloak.seungdobae.com"
  tags = {
    terraform = true
  }
}

# AWS 제공자 설정
provider "aws" {
  default_tags {
    tags = local.tags
  }
}

# Keycloak 제공자
provider "keycloak" {
  client_id = "admin-cli"
  username  = "admin"
  password  = "saltware1234"
  url       = "https://${local.service_domain_name}"
}