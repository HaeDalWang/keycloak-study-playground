# AWS 지역 정보
data "aws_region" "current" {}
data "aws_availability_zones" "azs" {}

# Amazon Linux 2023 최신 AMI (SSM Agent 포함, minimal 제외)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
