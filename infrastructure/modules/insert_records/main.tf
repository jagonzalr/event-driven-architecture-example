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

// DynamoDb Policy
data "aws_iam_policy_document" "dynamodb" {
  policy_id = "${var.name}-lambda-dynamodb"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["dynamodb:PutItem"]

    resources = [var.users_table_arn]
  }
}

resource "aws_iam_policy" "dynamodb" {
  name   = "${var.name}-lambda-dynamodb"
  policy = data.aws_iam_policy_document.dynamodb.json
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  depends_on  = [aws_iam_role.lambda, aws_iam_policy.dynamodb]
  role        = aws_iam_role.lambda.name
  policy_arn  = aws_iam_policy.dynamodb.arn
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

// SQS policy
data "aws_iam_policy_document" "sqs" {
  policy_id = "${var.name}-lambda-sqs"
  version   = "2012-10-17"

  statement {
    effect  = "Allow"
    actions = ["sqs:ReceiveMessage"]

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
resource "aws_cloudwatch_log_group" "insert_records" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 7
  tags              = var.tags
}

/*
* Lambda
*/

// Function
resource "aws_lambda_function" "insert_records" {
  depends_on = [aws_cloudwatch_log_group.insert_records]

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
      USERS_TABLE = var.users_table_name
    }
  }
}

// Event Source Mapping
resource "aws_lambda_event_source_mapping" "buffer_queue_to_insert_records" {
  event_source_arn = var.buffer_queue_arn
  function_name    = aws_lambda_function.insert_records.arn
}

// Permission
resource "aws_lambda_permission" "buffer_queue_execution" {
  depends_on = [aws_lambda_function.insert_records]

  statement_id  = "${var.name}-buffer-queue-AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.insert_records.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = var.buffer_queue_arn
}