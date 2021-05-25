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
  tags                = var.tags
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

// SES policy
data "aws_iam_policy_document" "ses" {
  policy_id = "${var.name}-lambda-ses"
  version   = "2012-10-17"

  statement {
    effect  = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "ses" {
  name   = "${var.name}-lambda-ses"
  policy = data.aws_iam_policy_document.ses.json
}

resource "aws_iam_role_policy_attachment" "ses" {
  depends_on  = [aws_iam_role.lambda, aws_iam_policy.ses]
  role        = aws_iam_role.lambda.name
  policy_arn  = aws_iam_policy.ses.arn
}

/*
* Cloudwatch
*/

// Log group
resource "aws_cloudwatch_log_group" "send_email" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 7
  tags              = var.tags
}

/*
* Lambda
*/

// Function
resource "aws_lambda_function" "send_email" {
  depends_on = [aws_cloudwatch_log_group.send_email]

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
      REGION      = var.region
      FROM_EMAIL  = var.from_email
    }
  }
}

// Event Source Mapping
resource "aws_lambda_event_source_mapping" "users_table_to_insert_records" {
  event_source_arn  = var.users_table_stream_arn
  function_name     = aws_lambda_function.send_email.arn
  starting_position = "LATEST"
}

// Permission
resource "aws_lambda_permission" "buffer_queue_execution" {
  depends_on = [aws_lambda_function.send_email]

  statement_id  = "${var.name}-users-table-AllowExecutionFromDynamoDB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_email.function_name
  principal     = "dynamodb.amazonaws.com"
  source_arn    = var.users_table_stream_arn
}