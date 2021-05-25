terraform {
  required_version = "<= 0.15.3"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.42.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  from_email  = "test@example.com"
  handler     = "src/functions/process_csv.handler"
  name        = "eda-example"
  zip_path    = "../../../.serverless/process_csv.zip"
}

data "aws_caller_identity" "current" {}

module "core" {
  source  = "./modules/core"
  name    = local.name
}

module "process_csv" {
  source              = "./modules/process_csv"
  account_id          = data.aws_caller_identity.current.account_id
  buffer_queue_arn    = module.core.buffer_queue_arn
  handler             = local.handler
  name                = "${local.name}-process-env"
  region              = var.region
  uploads_bucket_arn  = module.core.uploads_bucket_arn
  uploads_bucket_name = module.core.uploads_bucket_name
  zip_path            = local.zip_path
}