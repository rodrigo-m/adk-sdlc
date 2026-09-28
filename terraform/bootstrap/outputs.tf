output "state_bucket_name" {
  description = "The name of the Terraform remote state storage bucket"
  value       = google_storage_bucket.terraform_state.name
}

output "state_bucket_url" {
  description = "The GCS URL of the Terraform remote state storage bucket"
  value       = google_storage_bucket.terraform_state.url
}
