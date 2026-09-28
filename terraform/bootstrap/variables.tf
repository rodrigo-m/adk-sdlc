variable "project_id" {
  description = "Google Cloud Project ID where the Terraform remote state bucket will be hosted (typically the CI/CD project)"
  type        = string
}

variable "region" {
  description = "Google Cloud region for the Terraform remote state bucket"
  type        = string
  default     = "us-central1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform GCS state bucket"
  type        = string
}
