locals {
  prefix         = "cspm-remed-demo"
  aws_account_id = "897722680419"
  aws_region     = "us-east-2"
  github_repo    = "mdorn/datadog-cloud-security-demo"
  # The repo uses GitHub immutable OIDC subjects: owner@<owner_id>/repo@<repo_id>.
  github_oidc_sub_prefix = "repo:mdorn@81092/datadog-cloud-security-demo@1458951266"
  ecr_repo_name          = "${local.prefix}-app"

  tags = {
    env          = "demo"
    team         = "web"
    service      = "demo-app"
    owner        = "matt.dorn@datadoghq.com"
    "managed-by" = "terraform"
  }
}
