output "prod_project_id" {
  description = "Project ID for the production environment"
  value       = module.prod_environment.project_id
}

output "prod_bucket_name" {
  description = "Dependent GCS bucket in Prod environment"
  value       = module.prod_environment.bucket_name
}

output "prod_bucket_url" {
  description = "GCS URL of dependent bucket in Prod"
  value       = module.prod_environment.bucket_url
}

output "prod_agent_service_account" {
  description = "Service Account email executing greeting agent in Prod"
  value       = module.prod_environment.agent_service_account_email
}
