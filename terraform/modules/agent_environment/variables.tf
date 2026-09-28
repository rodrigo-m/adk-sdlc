variable "project_id" {
  description = "Target Google Cloud Project ID for this agent environment"
  type        = string
}

variable "environment" {
  description = "Environment identifier (e.g., 'test', 'prod')"
  type        = string
}

variable "region" {
  description = "Google Cloud region for resources"
  type        = string
  default     = "us-central1"
}

variable "agent_name" {
  description = "Name of the ADK agent (used for service account and naming)"
  type        = string
  default     = "greeting-agent"
}

variable "custom_bucket_name" {
  description = "Optional custom name for the dependent GCS bucket. Defaults to '{project_id}-data'"
  type        = string
  default     = ""
}
