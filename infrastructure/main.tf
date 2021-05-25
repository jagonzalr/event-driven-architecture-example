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
  zip_path  = ""
  handler   = ""
}

resource "aws_s3_bucket" "uploads" {
  bucket        = "${var.name}-uploads"
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    id      = "${var.name}-uploads-object-removal-rule"
    enabled = true
    expiration {
      days = 1
    }
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["x-amz-server-side-encryption", "x-amz-request-id", "x-amz-id-2", "ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "uploads_access_block" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_lambda_function" "process_csv" {
  depends_on = [aws_cloudwatch_log_group.process_csv]

  filename          = local.zip_path
  function_name     = "${var.name}-process-csv"
  role              = aws_iam_role.role.arn
  handler           = local.handler
  source_code_hash  = filebase64sha256(local.zip_path)
  runtime           = "nodejs14.x"
  memory_size       = 1024
  timeout           = 60

  environment {
    variables = {
      REGION = var.region
    }
  }
}