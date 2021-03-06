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
  from_email                = "test@example.com"
  insert_records_handler    = "src/functions/insertRecords.handler"
  insert_records_zip_path   = "../.serverless/insertRecords.zip"
  name                      = "eda-example"
  process_csv_handler       = "src/functions/processCsv.handler"
  process_csv_zip_path      = "../.serverless/processCsv.zip"
  send_email_handler        = "src/functions/sendEmail.handler"
  send_email_zip_path       = "../.serverless/sendEmail.zip"
}

data "aws_caller_identity" "current" {}

module "core" {
  source  = "./modules/core"
  name    = local.name
}

module "process_csv" {
  depends_on = [module.core]

  source              = "./modules/process_csv"
  account_id          = data.aws_caller_identity.current.account_id
  buffer_queue_id     = module.core.buffer_queue_id
  buffer_queue_arn    = module.core.buffer_queue_arn
  handler             = local.process_csv_handler
  name                = "${local.name}-process-csv"
  region              = var.region
  uploads_bucket_arn  = module.core.uploads_bucket_arn
  uploads_bucket_name = module.core.uploads_bucket_name
  zip_path            = local.process_csv_zip_path
}

module "insert_records" {
  depends_on = [module.core]

  source              = "./modules/insert_records"
  account_id          = data.aws_caller_identity.current.account_id
  buffer_queue_arn    = module.core.buffer_queue_arn
  handler             = local.insert_records_handler
  name                = "${local.name}-insert-records"
  region              = var.region
  users_table_arn     = module.core.users_table_arn
  users_table_name    = module.core.users_table_name
  zip_path            = local.insert_records_zip_path
}

module "send_email" {
  depends_on = [module.core]

  source                  = "./modules/send_email"
  account_id              = data.aws_caller_identity.current.account_id
  from_email              = local.from_email
  handler                 = local.send_email_handler
  name                    = "${local.name}-send-email"
  region                  = var.region
  users_table_stream_arn  = module.core.users_table_stream_arn
  zip_path                = local.send_email_zip_path
}