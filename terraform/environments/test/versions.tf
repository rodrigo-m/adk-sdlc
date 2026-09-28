terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    # Specify remote state bucket via:
    # terraform init -backend-config=backend.tfvars (or -backend-config="bucket=<bucket-name>")
    prefix = "environments/test"
  }
}

provider "google" {
  project = var.test_project_id
  region  = var.region
}
