resource "aws_instance" "ad_servers" {
  count                  = 2
  ami                    = data.aws_ami.windows_base.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.ad.id]
  key_name               = var.key_name
  private_ip             = cidrhost(aws_subnet.private[count.index].cidr_block, 10)

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }

  tags = { Name = "${local.project}-ad-${count.index + 1}" }
}
