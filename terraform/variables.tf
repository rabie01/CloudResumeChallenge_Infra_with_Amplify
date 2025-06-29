variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "hosted_zone_name" {
  description = "The root domain name that has a Route 53 hosted zone (e.g., rabietech.dpdns.org)"
  type        = string
  default     = "rabietech.dpdns.org"
}

variable "custom_domain_names" {
  type = list(string)
  description = "List of custom domains (no protocol, e.g. 'myresume.rabietech.dpdns.org')"
  default = [
    "www.myresume.rabietech.dpdns.org",
    "myresume.rabietech.dpdns.org"
  ]
}

variable "fronend_repo_url" {
  description = "url for the frontend repo"
  default = "https://github.com/rabie01/CloudResumeChallenge_Frontend.git"
}

