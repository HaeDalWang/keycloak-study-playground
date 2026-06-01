resource "aws_instance" "keycloak" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.keycloak.id]
  key_name               = var.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  tags = { Name = "${local.project}-kc-${count.index + 1}" }
}
