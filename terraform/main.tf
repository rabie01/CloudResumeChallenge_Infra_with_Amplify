

module "visitor_table" {
  source     = "./modules/Dynamodb"
  table_name = "visitor_cnt"
}

module "lambda_visitor_count" {
  source     = "./modules/Lambda"
  lambda_name = "get_visitor_count"
  lambda_handler         = "get_visitor_count.lambda_handler"
  lambda_runtime         = "python3.13"
  table_name  = module.visitor_table.table_name
  table_arn   = module.visitor_table.table_arn
}


module "api_gw" {
  source = "./modules/ApiGateway"
  custom_domain_names = var.custom_domain_names
  apigw_name   = "visitor_api"
  lambda_invoke_arn = module.lambda_visitor_count.invoke_arn
  function_name = module.lambda_visitor_count.function_name
}


module "amplify" {
  source  = "./modules/Amplify"
  github_token = var.github_token
  amplify_name    = "cloudresume-frontend"
  amplify_repository      = "https://github.com/rabie01/CloudResumeChallenge_Frontend.git"
  API_URL = module.api_gw.api_invoke_url
  custom_domain_names = var.custom_domain_names
  frontend_branch = var.frontend_branch_name
  
}