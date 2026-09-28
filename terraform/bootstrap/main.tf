# -------------------------------------------------------------
# Bootstrap: Remote Terraform State GCS Bucket
# -------------------------------------------------------------
# Provisions the central Google Cloud Storage bucket used as the
# remote backend for state files across all environments and layers.
# -------------------------------------------------------------

resource "google_project_service" "storage_api" {
  project                    = var.project_id
  service                    = "storage.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_storage_bucket" "terraform_state" {
  name                        = var.state_bucket_name
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Versioning allows recovering previous state versions in disaster scenarios
  versioning {
    enabled = true
  }

  # Retain noncurrent state versions for 90 days for rollback, then expire to save storage costs
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 5
      days_since_noncurrent_time = 90
    }
  }

  depends_on = [google_project_service.storage_api]
}
