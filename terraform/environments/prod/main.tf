# -------------------------------------------------------------
# Environment: PRODUCTION
# -------------------------------------------------------------
# Isolated Terraform state prefix: environments/prod
# Manages APIs, dependent storage, and agent runtime identity for PROD.
# -------------------------------------------------------------

module "prod_environment" {
  source      = "../../modules/agent_environment"
  project_id  = var.prod_project_id
  environment = "prod"
  region      = var.region
  agent_name  = var.agent_name
}
