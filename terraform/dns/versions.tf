terraform {
  required_version = ">= 1.10"

  backend "s3" {
    key          = "dns/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Project   = "quickballot"
      ManagedBy = "terraform"
    }
  }
}
