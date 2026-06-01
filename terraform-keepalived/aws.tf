# ─────────────────────────────────────────
# VPC — 최소 구성 (public subnet 1개, NAT 없음)
# Keepalived 실습은 같은 서브넷에 두 노드가 있어야 VRRP unicast 가능
# ─────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${local.project}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.project}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone       = data.aws_availability_zones.azs.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.project}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${local.project}-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────
# Security Group
# ─────────────────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${local.project}-sg"
  description = "Keycloak Keepalived nodes"
  vpc_id      = aws_vpc.this.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Keycloak HTTP
  ingress {
    description = "Keycloak HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Keycloak 관리 포트
  ingress {
    description = "Keycloak management"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # VRRP unicast (Keepalived 노드 간)
  ingress {
    description = "VRRP unicast (Keepalived)"
    from_port   = 0
    to_port     = 0
    protocol    = "112"
    self        = true
  }

  # JGroups 클러스터링
  ingress {
    description = "JGroups"
    from_port   = 7800
    to_port     = 7800
    protocol    = "tcp"
    self        = true
  }

  # PostgreSQL (노드 간)
  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-sg" }
}

# ─────────────────────────────────────────
# EC2 x2 — 같은 서브넷, 같은 AZ
# ─────────────────────────────────────────
resource "aws_instance" "node" {
  count = 2

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # 소스/목적지 체크 비활성화 — EIP 이동 후 트래픽 포워딩에 필요
  source_dest_check = false

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y java-21-amazon-corretto-headless jq curl wget unzip keepalived docker
    systemctl enable docker
    systemctl start docker
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  EOF

  tags = { Name = "${local.project}-node-${count.index + 1}" }
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
  instance_id   = aws_instance.node[0].id
  allocation_id = aws_eip.vip.id
}
