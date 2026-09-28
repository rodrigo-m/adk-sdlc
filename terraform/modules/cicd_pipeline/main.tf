# -------------------------------------------------------------
# Module: CI/CD Pipeline & Cross-Project IAM
# -------------------------------------------------------------
# Provisions the dedicated Cloud Build runner service account,
# cross-project deployment IAM bindings into test/prod projects,
# and Cloud Build triggers (continuous test & gated prod).
# -------------------------------------------------------------

locals {
  cb_services = [
    "aiplatform.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com"
  ]

  repo_resource_name = "projects/${var.cloud_build_project_id}/locations/${var.region}/connections/${var.github_connection_name}/repositories/${var.github_repo_name}"
}

# 1. Enable Required Services in CI/CD Project
resource "google_project_service" "cb_services" {
  for_each                   = toset(local.cb_services)
  project                    = var.cloud_build_project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false
}

# 2. Dedicated Cloud Build CI/CD Service Account
resource "google_service_account" "cloudbuild_sa" {
  project      = var.cloud_build_project_id
  account_id   = "sa-adk-cicd-runner"
  display_name = "ADK CI/CD Cloud Build Runner"
  depends_on   = [google_project_service.cb_services]
}

# Default Cloud Build SA reference
data "google_project" "cb_project" {
  project_id = var.cloud_build_project_id
}

locals {
  cb_service_accounts = [
    "serviceAccount:${google_service_account.cloudbuild_sa.email}",
    "serviceAccount:${data.google_project.cb_project.number}@cloudbuild.gserviceaccount.com"
  ]
}

# 3. Grant Roles in CI/CD Project
resource "google_project_iam_member" "cb_sa_log_writer" {
  for_each = toset(local.cb_service_accounts)
  project  = var.cloud_build_project_id
  role     = "roles/logging.logWriter"
  member   = each.value
}

resource "google_project_iam_member" "cb_sa_storage_admin" {
  for_each = toset(local.cb_service_accounts)
  project  = var.cloud_build_project_id
  role     = "roles/storage.admin"
  member   = each.value
}

# 4. Cross-Project IAM Permissions into TEST Project
resource "google_project_iam_member" "test_aiplatform_admin" {
  for_each = toset(local.cb_service_accounts)
  project  = var.test_project_id
  role     = "roles/aiplatform.admin"
  member   = each.value
}

resource "google_project_iam_member" "test_storage_admin" {
  for_each = toset(local.cb_service_accounts)
  project  = var.test_project_id
  role     = "roles/storage.admin"
  member   = each.value
}

resource "google_project_iam_member" "test_sa_user" {
  for_each = toset(local.cb_service_accounts)
  project  = var.test_project_id
  role     = "roles/iam.serviceAccountUser"
  member   = each.value
}

# 5. Cross-Project IAM Permissions into PROD Project
resource "google_project_iam_member" "prod_aiplatform_admin" {
  for_each = toset(local.cb_service_accounts)
  project  = var.prod_project_id
  role     = "roles/aiplatform.admin"
  member   = each.value
}

resource "google_project_iam_member" "prod_storage_admin" {
  for_each = toset(local.cb_service_accounts)
  project  = var.prod_project_id
  role     = "roles/storage.admin"
  member   = each.value
}

resource "google_project_iam_member" "prod_sa_user" {
  for_each = toset(local.cb_service_accounts)
  project  = var.prod_project_id
  role     = "roles/iam.serviceAccountUser"
  member   = each.value
}

# 6. Cloud Build Triggers
resource "google_cloudbuild_trigger" "test_trigger" {
  name        = "deploy-test-pipeline"
  project     = var.cloud_build_project_id
  location    = var.region
  description = "Continuous Deployment to TEST on git push to main"

  repository_event_config {
    repository = local.repo_resource_name
    push {
      branch = "^main$"
    }
  }

  filename        = "cloudbuild-test.yaml"
  service_account = google_service_account.cloudbuild_sa.id

  substitutions = {
    _TEST_PROJECT_ID = var.test_project_id
    _TEST_BUCKET     = var.test_bucket_name
    _REGION          = var.region
  }

  depends_on = [
    google_project_service.cb_services,
    google_project_iam_member.test_aiplatform_admin,
    google_project_iam_member.test_storage_admin
  ]
}

resource "google_cloudbuild_trigger" "prod_trigger" {
  name        = "deploy-prod-pipeline"
  project     = var.cloud_build_project_id
  location    = var.region
  description = "Production Deployment Pipeline - Requires Manual Approval"

  repository_event_config {
    repository = local.repo_resource_name
    push {
      branch = "^main$"
    }
  }

  approval_config {
    approval_required = true
  }

  filename        = "cloudbuild-prod.yaml"
  service_account = google_service_account.cloudbuild_sa.id

  substitutions = {
    _PROD_PROJECT_ID = var.prod_project_id
    _PROD_BUCKET     = var.prod_bucket_name
    _REGION          = var.region
  }

  depends_on = [
    google_project_service.cb_services,
    google_project_iam_member.prod_aiplatform_admin,
    google_project_iam_member.prod_storage_admin
  ]
}
