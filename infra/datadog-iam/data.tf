data "aws_vpc" "demo" {
  tags = { Name = "${local.prefix}-vpc" }
}
