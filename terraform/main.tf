resource "aws_dynamodb_table" "visitor_cnt" {
  name           = "visitor_cnt"
  hash_key       = "id"
  billing_mode   = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "get_visitor_count" {
  function_name = "get_visitor_count"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "get_visitor_count.lambda_handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_cnt.name
    }
  }
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "visitor_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.get_visitor_count.invoke_arn
  integration_method = "POST"
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
  name       = "cloudresume-frontend"
  repository = "https://github.com/rabie01/CloudResumeChallenge_Frontend.git"
  oauth_token = var.github_token  # stored in Jenkins/TF vars, not hardcoded

  build_spec = <<BUILD_SPEC
version: 1.0
frontend:
  phases:
    preBuild:
      commands:
        - npm install
    build:
      commands:
        - npm run build
  artifacts:
    baseDirectory: dist
    files:
      - '**/*'
  cache:
    paths:
      - node_modules/**/* 
BUILD_SPEC

  environment_variables = {
    ENV = "production"
  }
}

resource "aws_amplify_branch" "main_branch" {
  app_id      = aws_amplify_app.resume_frontend.id
  branch_name = "main"
  stage       = "PRODUCTION"
}
