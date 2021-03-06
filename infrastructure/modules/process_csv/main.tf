/*
* IAM
*/

// Role
data "aws_iam_policy_document" "assume_role" {
  policy_id = "${var.name}-lambda"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name                = "${var.name}-lambda"
  assume_role_policy  = data.aws_iam_policy_document.assume_role.json
}

// Logs Policy
data "aws_iam_policy_document" "logs" {
  policy_id = "${var.name}-lambda-logs"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]

    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.name}*:*"
    ]
  }
}

resource "aws_iam_policy" "logs" {
  name   = "${var.name}-lambda-logs"
  policy = data.aws_iam_policy_document.logs.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  depends_on  = [aws_iam_role.lambda, aws_iam_policy.logs]
  role        = aws_iam_role.lambda.name
  policy_arn  = aws_iam_policy.logs.arn
}

// S3 Policy
data "aws_iam_policy_document" "s3" {
  policy_id = "${var.name}-lambda-s3"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = [
      var.uploads_bucket_arn,
      "${var.uploads_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3" {
  name   = "${var.name}-lambda-s3"
  policy = data.aws_iam_policy_document.s3.json
}

resource "aws_iam_role_policy_attachment" "s3" {
  depends_on  = [aws_iam_role.lambda, aws_iam_policy.s3]
  role        = aws_iam_role.lambda.name
  policy_arn  = aws_iam_policy.s3.arn
}

// SQS policy
data "aws_iam_policy_document" "sqs" {
  policy_id = "${var.name}-lambda-sqs"
  version   = "2012-10-17"

  statement {
    effect  = "Allow"
    actions = ["sqs:SendMessage"]

    resources = [var.buffer_queue_arn]
  }
}

resource "aws_iam_policy" "sqs" {
  name   = "${var.name}-lambda-sqs"
  policy = data.aws_iam_policy_document.sqs.json
}

resource "aws_iam_role_policy_attachment" "sqs" {
  depends_on  = [aws_iam_role.lambda, aws_iam_policy.sqs]
  role        = aws_iam_role.lambda.name
  policy_arn  = aws_iam_policy.sqs.arn
}

/*
* Cloudwatch
*/

// Log group
resource "aws_cloudwatch_log_group" "process_csv" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 7
}

/*
* Lambda
*/

// Function
resource "aws_lambda_function" "process_csv" {
  depends_on = [aws_cloudwatch_log_group.process_csv]

  filename          = var.zip_path
  function_name     = var.name
  role              = aws_iam_role.lambda.arn
  handler           = var.handler
  source_code_hash  = filebase64sha256(var.zip_path)
  runtime           = "nodejs14.x"
  memory_size       = 1024
  timeout           = 60

  environment {
    variables = {
      BUFFER_QUEUE = var.buffer_queue_id
    }
  }
}

// Permissions
resource "aws_lambda_permission" "process_csv_allow_s3" {
  statement_id  = "${var.name}-process-csv-AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_csv.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.uploads_bucket_arn
}

/*
* S3
*/

// Notification
resource "aws_s3_bucket_notification" "uploads_bucket_notification" {
  bucket = var.uploads_bucket_name

  lambda_function {
    id                  = "uploads-event-process-csv"
    lambda_function_arn = aws_lambda_function.process_csv.arn
    events              = ["s3:ObjectCreated:CompleteMultipartUpload", "s3:ObjectCreated:Put"]
  }
}