locals {
  prefix         = "cspm-remed-demo"
  aws_account_id = "897722680419"
  aws_region     = "us-east-2"
  github_repo    = "mdorn/datadog-cloud-security-demo"
  ecr_repo_name  = "${local.prefix}-app"

  tags = {
    env          = "demo"
    team         = "web"
    service      = "demo-app"
    owner        = "matt.dorn@datadoghq.com"
    "managed-by" = "terraform"
  }
}
