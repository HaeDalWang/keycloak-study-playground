output "keycloak_url" {
  description = "Keycloak 접속 URL"
  value       = "https://${local.service_domain_name}"
}

output "alb_dns_name" {
  description = "ALB DNS (Route53 등록 전 직접 접속용)"
  value       = aws_lb.keycloak.dns_name
}

output "ec2_instance_ids" {
  description = "SSM Session Manager 접속용 인스턴스 ID"
  value       = aws_instance.keycloak[*].id
}

output "ssm_connect_commands" {
  description = "각 노드 SSM 접속 명령어"
  value = [
    for id in aws_instance.keycloak[*].id :
    "aws ssm start-session --target ${id}"
  ]
}
