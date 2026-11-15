provider "aws" {
  region              = local.aws_region
  profile             = "default"
  allowed_account_ids = [local.aws_account_id]

  default_tags {
    tags = local.tags
  }
}

# Credentials come only from DD_API_KEY / DD_APP_KEY env vars.
provider "datadog" {
  api_url = "https://api.datadoghq.com/"
}
