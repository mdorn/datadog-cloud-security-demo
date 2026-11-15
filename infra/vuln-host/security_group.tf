resource "aws_security_group" "host" {
  name        = "${local.prefix}-host"
  description = "Demo host: no inbound; outbound HTTP/HTTPS only"
  vpc_id      = data.aws_vpc.demo.id

  tags = { Name = "${local.prefix}-host" }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.host.id
  description       = "HTTPS: Datadog, ECR, SSM, Docker/apt repos"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.host.id
  description       = "HTTP: Ubuntu apt mirrors"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}
