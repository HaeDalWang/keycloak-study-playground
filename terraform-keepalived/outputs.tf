output "node_public_ips" {
  description = "각 노드 퍼블릭 IP (SSM 접속용)"
  value       = aws_instance.node[*].public_ip
}

output "node_private_ips" {
  description = "각 노드 프라이빗 IP (Keepalived 설정에 필요)"
  value       = aws_instance.node[*].private_ip
}

output "node_instance_ids" {
  description = "SSM 접속 명령어"
  value = [
    for id in aws_instance.node[*].id :
    "aws ssm start-session --target ${id}"
  ]
}

output "vip_public_ip" {
  description = "EIP (VIP) — 클라이언트가 접속하는 단일 IP"
  value       = aws_eip.vip.public_ip
}

output "vip_allocation_id" {
  description = "EIP Allocation ID — Keepalived notify 스크립트에 필요"
  value       = aws_eip.vip.id
}
