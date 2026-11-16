terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "tfstate-mdorn"
    key          = "cspm-remed-demo/vulnerable/terraform.tfstate"
    region       = "us-east-2"
    profile      = "default"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
