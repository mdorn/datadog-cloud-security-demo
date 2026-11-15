data "aws_vpc" "demo" {
  tags = { Name = "${local.prefix}-vpc" }
}

data "aws_subnet" "public_a" {
  vpc_id = data.aws_vpc.demo.id
  tags   = { Name = "${local.prefix}-public-a" }
}

data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}
