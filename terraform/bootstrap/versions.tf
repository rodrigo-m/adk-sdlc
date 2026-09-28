terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # NOTE: To bootstrap the backend bucket from scratch (solving the chicken-and-egg problem),
  # this module initially runs with a local backend.
  # Once the bucket is created, you may optionally configure:
  #
  # backend "gcs" {
  #   bucket = "adk-sdlc-terraform-state"
  #   prefix = "bootstrap/state"
  # }
  #
  # and run `terraform init -migrate-state`.
}

provider "google" {
  project = var.project_id
  region  = var.region
}
