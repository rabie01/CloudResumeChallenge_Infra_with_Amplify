output "amplify_default_domain_url" {
  # for info only but wont render the labda function bc it is blocked by cors
  value = "NOTE: This domain won't render Lambda due to CORS -> ${module.amplify.default_domain}"
}

output "amplify_custom_domain_url" {
  value = module.amplify.custom_domain
}
