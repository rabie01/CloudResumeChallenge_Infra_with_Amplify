variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name to access"
  type        = string
}

variable "table_arn" {
  description = "DynamoDB table ARN to allow access"
  type        = string
}


variable "lambda_handler" {
  description = "lambda_handler"
  type        = string
}

variable "lambda_runtime" {
  description = "lambda_runtime"
  type        = string
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.lambda_name}_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.lambda_name}_dynamodb_policy"
  description = "Allow Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = var.table_arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_dynamodb_attach" {
  name       = "${var.lambda_name}_dynamodb_attach"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_lambda_function" "lambda_fn" {
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = "get_visitor_count.lambda_handler"
  runtime       = "python3.13"

  #tf only, no cicd
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  #cicd
  # filename         = "${path.module}/lambda.zip"
  # source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.root}/lambda/get_visitor_count.py"
  output_path = "${path.root}/lambda.zip"
}

output "function_name" {
  value = aws_lambda_function.lambda_fn.function_name
}

output "invoke_arn" {
  value = aws_lambda_function.lambda_fn.invoke_arn
}

output "role_arn" {
  value = aws_iam_role.lambda_exec.arn
}
