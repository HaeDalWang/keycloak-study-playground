# AWS 지역 정보 불러오기
data "aws_region" "current" {}
# 현재 설정된 AWS 리전에 있는 가용영역 정보 불러오기
data "aws_availability_zones" "azs" {}
# 현재 Terraform을 실행하는 IAM 객체
data "aws_caller_identity" "current" {}

# Amazon Linux 2023 최신 AMI (Keycloak 26.x → Java 21 필요)
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    # minimal 제외: al2023-ami-minimal-* 은 SSM Agent 미포함
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# 기존에 발급된 ACM 인증서 (*.seungdobae.com 또는 keycloak.seungdobae.com)
data "aws_acm_certificate" "keycloak" {
  # ACM data source의 domain은 인증서 주 도메인(Primary Domain)으로 조회
  # *.seungdobae.com은 SAN이므로 주 도메인인 seungdobae.com으로 지정
  domain      = "seungdobae.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Route53 Hosted Zone
data "aws_route53_zone" "this" {
  name         = "seungdobae.com."
  private_zone = false
}