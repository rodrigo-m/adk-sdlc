output "test_project_id" {
  description = "Project ID for the test environment"
  value       = module.test_environment.project_id
}

output "test_bucket_name" {
  description = "Dependent GCS bucket in Test environment"
  value       = module.test_environment.bucket_name
}

output "test_bucket_url" {
  description = "GCS URL of dependent bucket in Test"
  value       = module.test_environment.bucket_url
}

output "test_agent_service_account" {
  description = "Service Account email executing greeting agent in Test"
  value       = module.test_environment.agent_service_account_email
}
