data "aws_region" "current" {}
data "aws_availability_zones" "azs" {}

data "aws_ami" "windows_base" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-Korean-Full-Base-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ami" "ubuntu_24" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
