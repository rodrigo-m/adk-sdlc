# -------------------------------------------------------------
# Environment: TEST
# -------------------------------------------------------------
# Isolated Terraform state prefix: environments/test
# Manages APIs, dependent storage, and agent runtime identity for TEST.
# -------------------------------------------------------------

module "test_environment" {
  source      = "../../modules/agent_environment"
  project_id  = var.test_project_id
  environment = "test"
  region      = var.region
  agent_name  = var.agent_name
}
