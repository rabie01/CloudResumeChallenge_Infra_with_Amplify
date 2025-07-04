locals {
  amplify_app_id      = aws_amplify_app.resume_frontend.id
  amplify_branch      = aws_amplify_branch.main_branch.branch_name
  amplify_app_domain  = aws_amplify_app.resume_frontend.default_domain
  amplify_default_url = "https://${local.amplify_branch}.${local.amplify_app_domain}"
  # For API Gateway CORS origins
  cors_origins = [for domain in var.custom_domain_names : "https://${domain}"]
}

resource "aws_dynamodb_table" "visitor_cnt" {
  name         = "visitor_cnt"
  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }
}

# Create IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

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

# Attach AWS managed policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create a custom policy for DynamoDB access
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "LambdaDynamoDBAccessPolicy"
  description = "Allow Lambda to get/put/update visitor count in DynamoDB"

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
        Resource = aws_dynamodb_table.visitor_cnt.arn
      }
    ]
  })
}

# Attach the DynamoDB policy to the Lambda execution role
resource "aws_iam_policy_attachment" "lambda_dynamodb_attach" {
  name       = "LambdaAttachDynamoDBPolicy"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}
#can also be done as a stage in cicd
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/get_visitor_count.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "get_visitor_count" {
  function_name    = "get_visitor_count"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "get_visitor_count.lambda_handler"
  runtime          = "python3.13"
  #tf only, no cicd
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  #cicd
  # filename         = "${path.module}/lambda.zip"
  # source_code_hash = filebase64sha256("${path.module}/lambda.zip")
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_cnt.name
    }
  }
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "visitor_api"
  protocol_type = "HTTP"

  cors_configuration {
    # allow_origins     = concat([local.amplify_default_url], local.cors_origins)
    allow_origins     = local.cors_origins
    allow_methods     = ["GET", "OPTIONS"]
    allow_headers     = ["Content-Type"]
    allow_credentials = false
    expose_headers    = []
    max_age           = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_visitor_count.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_visitor_count.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_amplify_app" "resume_frontend" {
  name                 = "cloudresume-frontend"
  repository           = "https://github.com/rabie01/CloudResumeChallenge_Frontend.git"
  iam_service_role_arn = aws_iam_role.amplify_service.arn
  #comented to use github app instead
  oauth_token = var.github_token # stored in Jenkins/TF vars, not hardcoded
  # build_spec not needed for static website but left for reference also can be add to frontend amplify.yml
  build_spec = <<BUILD_SPEC
version: 1.0
frontend:
  phases:
    build:
      commands:
        - echo "Static site, no build needed"
        - sed -i 's|__API_URL__|'$API_URL'|g' js/get_count.js
  artifacts:
    baseDirectory: .
    files:
      - '**/*'
  cache:
    paths:
      - []
BUILD_SPEC

  environment_variables = {
    ENV = "production"
    API_URL = aws_apigatewayv2_stage.default.invoke_url
  }
}

resource "aws_amplify_branch" "main_branch" {
  app_id            = aws_amplify_app.resume_frontend.id
  branch_name       = "main"
  enable_auto_build = true
  stage             = "PRODUCTION"
}

#may be this iam role is not needed

resource "aws_iam_role" "amplify_service" {
  name = "amplify_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "amplify.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "amplify_basic" {
  role       = aws_iam_role.amplify_service.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
}

resource "aws_amplify_domain_association" "custom_domain" {
  app_id      = local.amplify_app_id
  domain_name = var.custom_domain_names[1]

  sub_domain {
    branch_name = local.amplify_branch
    prefix      = ""     # root domain
  }

  sub_domain {
    branch_name = local.amplify_branch
    prefix      = "www"  # www subdomain
  }
}




resource "null_resource" "trigger_amplify_deployment" {
  depends_on = [aws_amplify_branch.main_branch]

  # Force this command to be triggered every time this terraform file is ran
  triggers = {
    always_run = "${timestamp()}"
  }

  # The command to be ran
  provisioner "local-exec" {
    command = "aws amplify start-job --app-id ${local.amplify_app_id} --branch-name ${local.amplify_branch} --job-type RELEASE"
  }
}