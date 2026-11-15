locals {
  prefix         = "cspm-remed-demo"
  aws_account_id = "897722680419"
  aws_region     = "us-east-2"

  ami_id        = "ami-00149760ce42c967b" # ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20230112
  instance_type = "t3.micro"
  instance_name = "${local.prefix}-vuln-host"

  ecr_repo_name     = "${local.prefix}-app"
  ecr_registry      = "${local.aws_account_id}.dkr.ecr.${local.aws_region}.amazonaws.com"
  dd_api_key_param  = "/${local.prefix}/dd-api-key"
  redeploy_document = "${local.prefix}-redeploy"

  tags = {
    env          = "demo"
    team         = "web"
    service      = "demo-app"
    owner        = "matt.dorn@datadoghq.com"
    "managed-by" = "terraform"
  }
}
