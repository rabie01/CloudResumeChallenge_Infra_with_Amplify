locals {
# For API Gateway CORS origins
  cors_origins = [for domain in var.custom_domain_names : "https://${domain}"]
}

variable "custom_domain_names" {
  type = list(string)
}
variable "lambda_invoke_arn" {}
variable "function_name" {}
variable "apigw_name" {}

resource "aws_apigatewayv2_api" "http_api" {
  name          = var.apigw_name
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
  integration_uri        = var.lambda_invoke_arn
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
  # function_name = aws_lambda_function.get_visitor_count.function_name
  function_name = var.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "api_invoke_url" {
    value = aws_apigatewayv2_stage.default.invoke_url  
}
