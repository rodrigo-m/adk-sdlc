variable "test_project_id" {
  description = "Project ID for the Test environment"
  type        = string
}

variable "region" {
  description = "Default Google Cloud region for test resources"
  type        = string
  default     = "us-central1"
}

variable "agent_name" {
  description = "Name of the ADK agent"
  type        = string
  default     = "greeting-agent"
}
