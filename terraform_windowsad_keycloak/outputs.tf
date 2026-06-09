output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "ad_servers_private_ips" {
  value = aws_instance.ad_servers[*].private_ip
}

output "keycloak_servers_private_ips" {
  value = aws_instance.keycloak[*].private_ip
}

# ── HA(Keepalived + PostgreSQL) 구성에 쓰는 값들 ──────────────
output "keycloak_instance_ids" {
  description = "Node1, Node2 인스턴스 ID (notify 스크립트는 IMDS로 자동조회하므로 참고용)"
  value       = aws_instance.keycloak[*].id
}

output "keycloak_db_vip" {
  description = "DB VIP (보조 사설IP). keycloak.conf db-url 및 keepalived-notify.sh DB_VIP"
  value       = "10.10.0.100"
}

output "keycloak_vip_eip_alloc_id" {
  description = "프론트 EIP allocation-id. keepalived-notify.sh EIP_ALLOC_ID"
  value       = aws_eip.vip.id
}

output "keycloak_vip_eip_public_ip" {
  description = "프론트 EIP public IP (외부 접속용)"
  value       = aws_eip.vip.public_ip
}

output "keycloak_subnet_cidr" {
  description = "두 노드가 속한 서브넷 CIDR. init-primary.sh REPL_ALLOWED_CIDR"
  value       = aws_subnet.public.cidr_block
}
