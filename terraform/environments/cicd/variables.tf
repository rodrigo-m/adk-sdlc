variable "cloud_build_project_id" {
  description = "Project ID hosting Cloud Build triggers and GitHub host connection"
  type        = string
}

variable "region" {
  description = "Default Google Cloud region for CI/CD resources"
  type        = string
  default     = "us-central1"
}

variable "github_connection_name" {
  description = "Cloud Build 2nd gen GitHub connection name"
  type        = string
  default     = "github-connection-001"
}

variable "github_repo_name" {
  description = "Connected GitHub repository name in Cloud Build"
  type        = string
}

variable "test_project_id" {
  description = "Project ID for the Test environment"
  type        = string
}

variable "test_bucket_name" {
  description = "Dependent GCS bucket in Test environment"
  type        = string
}

variable "prod_project_id" {
  description = "Project ID for the Production environment"
  type        = string
}

variable "prod_bucket_name" {
  description = "Dependent GCS bucket in Prod environment"
  type        = string
}
