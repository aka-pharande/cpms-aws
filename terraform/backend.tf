terraform {
  backend "s3" {
    bucket         = "s3-cpms-state-dev-useast1"
    key            = "cpms/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}