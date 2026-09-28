output "cloud_build_project_id" {
  description = "Project ID hosting Cloud Build and host connections"
  value       = var.cloud_build_project_id
}

output "cloudbuild_service_account" {
  description = "Dedicated Service Account executing Cloud Build pipelines"
  value       = module.cicd_pipeline.cloudbuild_service_account
}

output "test_trigger_id" {
  description = "Cloud Build Trigger ID for automated Test deployments"
  value       = module.cicd_pipeline.test_trigger_id
}

output "prod_trigger_id" {
  description = "Cloud Build Trigger ID for gated Prod deployments"
  value       = module.cicd_pipeline.prod_trigger_id
}
