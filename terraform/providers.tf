terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    mysql = {
      source  = "terraform-providers/mysql"
      version = "~> 1.9"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}