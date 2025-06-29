locals {
  amplify_app_id      = aws_amplify_app.resume_frontend.id
  amplify_branch      = aws_amplify_branch.main_branch.branch_name
  amplify_app_domain  = aws_amplify_app.resume_frontend.default_domain
  amplify_default_url = "https://${local.amplify_branch}.${local.amplify_app_domain}"
  # For API Gateway CORS origins
  cors_origins = [for domain in var.custom_domain_names : "https://${domain}"]
  api_domain = "api.${var.custom_domain_names[1]}"
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


resource "aws_lambda_function" "get_visitor_count" {
  function_name    = "get_visitor_count"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "get_visitor_count.lambda_handler"
  runtime          = "python3.13"
  filename         = "${path.module}/lambda.zip"
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

  cors_configuration {
    allow_origins     = concat([local.amplify_default_url], local.cors_origins)
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

resource "aws_acm_certificate" "api_cert" {
  domain_name       = local.api_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "ACM cert for ${local.api_domain}"
  }
}

resource "aws_apigatewayv2_domain_name" "api_domain" {
  domain_name = local.api_domain

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api_cert_validation.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}
resource "aws_apigatewayv2_api_mapping" "api_map" {
  api_id      = aws_apigatewayv2_api.http_api.id
  domain_name = aws_apigatewayv2_domain_name.api_domain.id
  stage       = aws_apigatewayv2_stage.default.name
}

data "aws_route53_zone" "primary" {
  name         = var.hosted_zone_name  # e.g. "myresume.rabietech.dpdns.org"
  private_zone = false
}

resource "aws_route53_record" "api_dns" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.api_domain
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}



resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "api_cert_validation" {
  certificate_arn         = aws_acm_certificate.api_cert.arn
  validation_record_fqdns = [
  for record in aws_route53_record.api_cert_validation : record.fqdn
]
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