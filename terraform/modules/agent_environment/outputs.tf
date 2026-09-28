output "project_id" {
  description = "Target project ID for this environment"
  value       = var.project_id
}

output "bucket_name" {
  description = "Name of the dependent GCS bucket created for this environment"
  value       = google_storage_bucket.env_bucket.name
}

output "bucket_url" {
  description = "GCS URL of the dependent storage bucket"
  value       = google_storage_bucket.env_bucket.url
}

output "agent_service_account_email" {
  description = "Email of the dedicated runtime Service Account"
  value       = google_service_account.agent_sa.email
}

output "agent_service_account_id" {
  description = "Fully qualified ID of the runtime Service Account"
  value       = google_service_account.agent_sa.id
}
