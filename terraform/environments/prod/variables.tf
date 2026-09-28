variable "prod_project_id" {
  description = "Project ID for the Production environment"
  type        = string
}

variable "region" {
  description = "Default Google Cloud region for production resources"
  type        = string
  default     = "us-central1"
}

variable "agent_name" {
  description = "Name of the ADK agent"
  type        = string
  default     = "greeting-agent"
}
