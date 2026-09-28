# -------------------------------------------------------------
# Module: Agent Environment
# -------------------------------------------------------------
# Encapsulates foundational infrastructure needed by an ADK agent
# environment: required GCP APIs, dependent storage bucket, and
# least-privilege agent runtime Service Account.
# -------------------------------------------------------------

locals {
  services = [
    "aiplatform.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com"
  ]

  bucket_name = var.custom_bucket_name != "" ? var.custom_bucket_name : "${var.project_id}-data"
  sa_account_id = "sa-${var.agent_name}-${var.environment}"
}

# 1. Required APIs
resource "google_project_service" "env_services" {
  for_each                   = toset(local.services)
  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# 2. Dependent GCS Storage Bucket
resource "google_storage_bucket" "env_bucket" {
  name                        = local.bucket_name
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.env_services]
}

# 3. Agent Runtime Service Account (Least Privilege)
resource "google_service_account" "agent_sa" {
  project      = var.project_id
  account_id   = local.sa_account_id
  display_name = "${title(var.agent_name)} ${title(var.environment)} SA"
  depends_on   = [google_project_service.env_services]
}

# Grant Vertex AI user role so agent can query Gemini via ADC
resource "google_project_iam_member" "agent_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

# Grant objectUser role ONLY on the specific dependent GCS bucket
resource "google_storage_bucket_iam_member" "agent_storage" {
  bucket = google_storage_bucket.env_bucket.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.agent_sa.email}"
}
