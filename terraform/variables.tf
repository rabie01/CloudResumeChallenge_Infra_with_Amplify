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
