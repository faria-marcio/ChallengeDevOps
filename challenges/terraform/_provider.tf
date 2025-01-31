terraform {
  backend "s3" {
    bucket = "dnx-labs"
    key    = "terraform-state/terraform.tfstate"
    region = "ap-southeast-2"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.30.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}
