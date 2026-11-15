resource "aws_security_group" "open_ssh" {
  name        = "${local.prefix}-open-ssh"
  description = "cspm-remed-demo security group"
  vpc_id      = data.aws_vpc.demo.id

  tags = { Name = "${local.prefix}-open-ssh" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_any" {
  security_group_id = aws_security_group.open_ssh.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "${local.prefix}-ssh-any" }
}
