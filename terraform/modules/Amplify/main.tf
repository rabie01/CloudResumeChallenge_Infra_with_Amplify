locals {
  amplify_app_id      = aws_amplify_app.frontend.id
  amplify_branch      = aws_amplify_branch.main_branch.branch_name
  amplify_app_domain  = aws_amplify_app.frontend.default_domain
  amplify_default_url = "https://${local.amplify_branch}.${local.amplify_app_domain}"
}

variable "amplify_name" {}
variable "API_URL" {}
variable "github_token" {}
variable "amplify_repository" {}
variable "custom_domain_names" {}
variable "frontend_branch" {}


resource "aws_amplify_app" "frontend" {
  name                 = var.amplify_name
  repository           = var.amplify_repository
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
    API_URL = var.API_URL
  }
}

resource "aws_amplify_branch" "main_branch" {
  app_id            = aws_amplify_app.frontend.id
  branch_name       = var.frontend_branch
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



#needed to overcome the issue that when amplify created by tf, it wont run automatically, and needs manual deploy
#for first time before it can be trigered by any vhanges in the frontend code
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

output "default_domain" {
  value = "https://${var.frontend_branch}.${aws_amplify_app.frontend.default_domain}"
} 

output "custom_domain" {
  value = [ for domain in var.custom_domain_names : "https://${domain}"]
} 