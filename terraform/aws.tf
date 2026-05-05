# VPC
module "vpc" {
  # 모듈 최신화 2026.05.04
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.project
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.azs.names
  public_subnets  = [for idx, _ in data.aws_availability_zones.azs.names : cidrsubnet(var.vpc_cidr, 8, idx)]
  private_subnets = [for idx, _ in data.aws_availability_zones.azs.names : cidrsubnet(var.vpc_cidr, 8, idx + 10)]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# ─────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────

# ALB SG: 인터넷 → ALB (80, 443)
resource "aws_security_group" "alb" {
  name        = "${local.project}-alb-sg"
  description = "ALB inbound HTTP/HTTPS from internet"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-alb-sg" }
}

# EC2 SG: ALB → Keycloak(8080), 노드 간 JGroups 클러스터링(7800), SSH(22)
resource "aws_security_group" "ec2" {
  name        = "${local.project}-ec2-sg"
  description = "Keycloak EC2 inbound from ALB and inter-node clustering"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Keycloak HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # ALB 헬스체크 → Keycloak 관리 포트 (26.x부터 헬스체크가 9000으로 분리)
  ingress {
    description     = "Keycloak management port from ALB"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # JDBC_PING 방식 클러스터링 시 불필요하지만, TCP_PING 실습 대비 열어둠
  ingress {
    description = "JGroups clustering (node to node)"
    from_port   = 7800
    to_port     = 7800
    protocol    = "tcp"
    self        = true
  }

  # 노드 2 Keycloak → 노드 1 PostgreSQL 접근
  ingress {
    description = "PostgreSQL (node to node)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }

  # Bastion 없이 VPC 내부에서만 SSH 허용
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.project}-ec2-sg" }
}

# ─────────────────────────────────────────
# EC2 - Keycloak Node 1, 2
# ─────────────────────────────────────────

resource "aws_instance" "keycloak" {
  count = 2

  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  # 각 노드를 서로 다른 AZ의 private subnet에 배치 → HA 실습
  subnet_id              = module.vpc.private_subnets[count.index]
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.keycloak_ec2.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  # Keycloak 26.x 요구사항: Java 21
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y java-21-amazon-corretto-headless jq curl wget unzip
  EOF

  tags = { Name = "${local.project}-node-${count.index + 1}" }
}

# ─────────────────────────────────────────
# ALB
# ─────────────────────────────────────────

resource "aws_lb" "keycloak" {
  name               = "${local.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  tags = { Name = "${local.project}-alb" }
}

resource "aws_lb_target_group" "keycloak" {
  name     = "${local.project}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    # Keycloak 26.x 관리 포트(9000)에서 헬스체크 엔드포인트 제공
    path                = "/health/ready"
    port                = "9000"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200"
  }

  tags = { Name = "${local.project}-tg" }
}

resource "aws_lb_target_group_attachment" "keycloak" {
  count            = 2
  target_group_arn = aws_lb_target_group.keycloak.arn
  target_id        = aws_instance.keycloak[count.index].id
  port             = 8080
}

# HTTP → HTTPS 강제 리다이렉트
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS → Keycloak TG 포워딩
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.keycloak.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak.arn
  }
}

# ─────────────────────────────────────────
# Route53
# ─────────────────────────────────────────

resource "aws_route53_record" "keycloak" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.service_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.keycloak.dns_name
    zone_id                = aws_lb.keycloak.zone_id
    evaluate_target_health = true
  }
}
