# Bastion Security Group
resource "aws_security_group" "bastion" {
  name        = "${local.project}-bastion-sg"
  description = "Windows Bastion SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 주의: 실 환경에선 특정 IP로 제한
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.project}-bastion-sg" }
}

# Windows AD Security Group
resource "aws_security_group" "ad" {
  name        = "${local.project}-ad-sg"
  description = "Windows AD Servers SG"
  vpc_id      = aws_vpc.this.id

  # AD Required Ports from Bastion & Keycloak Subnets
  # Using VPC CIDR for simplicity of internal communication
  dynamic "ingress" {
    for_each = [
      { port = 135, protocol = "tcp", desc = "RPC Endpoint Mapper" },
      { port = 389, protocol = "tcp", desc = "LDAP" },
      { port = 389, protocol = "udp", desc = "LDAP" },
      { port = 636, protocol = "tcp", desc = "LDAP SSL" },
      { port = 3268, protocol = "tcp", desc = "LDAP GC" },
      { port = 3269, protocol = "tcp", desc = "LDAP GC SSL" },
      { port = 53, protocol = "tcp", desc = "DNS" },
      { port = 53, protocol = "udp", desc = "DNS" },
      { port = 88, protocol = "tcp", desc = "Kerberos" },
      { port = 88, protocol = "udp", desc = "Kerberos" },
      { port = 445, protocol = "tcp", desc = "SMB" }
    ]
    content {
      description = ingress.value.desc
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = [var.vpc_cidr]
    }
  }

  ingress {
    description = "RPC for LSA, SAM, NetLogon, FRS"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "RDP from VPC"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.project}-ad-sg" }
}

# Keycloak Security Group
resource "aws_security_group" "keycloak" {
  name        = "${local.project}-keycloak-sg"
  description = "Ubuntu Keycloak SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Keycloak HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "JGroups"
    from_port   = 7800
    to_port     = 7800
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.project}-keycloak-sg" }
}
