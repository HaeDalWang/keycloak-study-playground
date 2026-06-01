output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "ad_servers_private_ips" {
  value = aws_instance.ad_servers[*].private_ip
}

output "keycloak_servers_private_ips" {
  value = aws_instance.keycloak[*].private_ip
}
