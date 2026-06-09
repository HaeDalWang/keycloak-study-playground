resource "aws_instance" "keycloak" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = var.instance_type
  # ── 퍼블릭 서브넷 배치 ──────────────────────────────────────
  #  EIP(VIP) failover 시 Node2도 인터넷에서 접근 가능해야 하므로 public 서브넷.
  #  두 노드 모두 같은 public 서브넷(AZ 2a) → DB VIP(보조 사설IP) 이동 가능.
  subnet_id                   = aws_subnet.public.id
  private_ip                  = "10.10.0.${21 + count.index}" # Node1=.21, Node2=.22
  vpc_security_group_ids      = [aws_security_group.keycloak.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  # DB VIP(보조 사설IP 10.10.0.100)는 최초 Primary인 Node1에 미리 예약.
  secondary_private_ips = count.index == 0 ? ["10.10.0.100"] : []

  source_dest_check = false

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y openjdk-21-jre-headless jq curl wget unzip keepalived docker.io
    systemctl enable docker
    systemctl start docker
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  EOF

  tags = { Name = "${local.project}-kc-${count.index + 1}" }
}

# ─────────────────────────────────────────
# EIP — Keepalived VIP 역할
# 노드 1에 초기 연결, 장애 시 Keepalived notify 스크립트가 노드 2로 이동
# ─────────────────────────────────────────
resource "aws_eip" "vip" {
  domain = "vpc"
  tags   = { Name = "${local.project}-vip" }
}

resource "aws_eip_association" "vip" {
  instance_id   = aws_instance.keycloak[0].id
  allocation_id = aws_eip.vip.id
}
