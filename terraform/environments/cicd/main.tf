# -------------------------------------------------------------
# Environment: CI/CD Orchestration Layer
# -------------------------------------------------------------
# Isolated Terraform state prefix: environments/cicd
# Manages Cloud Build runners, cross-project deployment IAM bindings,
# and Cloud Build pipeline triggers for Test and Prod.
# -------------------------------------------------------------

module "cicd_pipeline" {
  source                 = "../../modules/cicd_pipeline"
  cloud_build_project_id = var.cloud_build_project_id
  region                 = var.region
  github_connection_name = var.github_connection_name
  github_repo_name       = var.github_repo_name
  test_project_id        = var.test_project_id
  test_bucket_name       = var.test_bucket_name
  prod_project_id        = var.prod_project_id
  prod_bucket_name       = var.prod_bucket_name
}
