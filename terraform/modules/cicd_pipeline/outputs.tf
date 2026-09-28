output "cloudbuild_service_account" {
  description = "Dedicated Service Account executing Cloud Build pipelines"
  value       = google_service_account.cloudbuild_sa.email
}

output "cloudbuild_service_account_id" {
  description = "Fully qualified ID of the Cloud Build runner Service Account"
  value       = google_service_account.cloudbuild_sa.id
}

output "test_trigger_id" {
  description = "Cloud Build Trigger ID for automated Test deployments"
  value       = google_cloudbuild_trigger.test_trigger.trigger_id
}

output "prod_trigger_id" {
  description = "Cloud Build Trigger ID for gated Prod deployments"
  value       = google_cloudbuild_trigger.prod_trigger.trigger_id
}
