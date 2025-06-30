variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}
variable "custom_domain_names" {
  type = list(string)
  description = "List of custom domains (no protocol, e.g. 'myresume.rabietech.dpdns.org')"
  default = [
    "www.myresume.rabietech.dpdns.org",
    "myresume.rabietech.dpdns.org"
  ]
}


variable "amplify_name" {
  description = "name of your app on amplify"
  type        = string
  default = "cloudresume-frontend"
}

variable "amplify_repository" {
  description = ""
  type        = string
  default = "https://github.com/rabie01/CloudResumeChallenge_Frontend.git"
}
variable "frontend_branch_name" {
  description = "the name of the frontend branch to be pulled and used by amplify"
  default = "main"
  
}
