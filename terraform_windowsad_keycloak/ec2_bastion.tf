resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.windows_base.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.key_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }

  tags = { Name = "${local.project}-bastion" }
}
