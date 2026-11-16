terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "tfstate-mdorn"
    key          = "cspm-remed-demo/datadog/terraform.tfstate"
    region       = "us-east-2"
    profile      = "default"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.30"
    }
  }
}
