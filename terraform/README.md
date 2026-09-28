# Terraform Infrastructure as Code for Google ADK SDLC

This directory organizes the infrastructure for the 3-project Google ADK SDLC topology using modular, state-isolated Terraform.

## Directory Structure

```text
terraform/
├── bootstrap/               # Bootstraps the GCS remote state storage bucket (solves chicken-and-egg)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── modules/                 # Reusable Terraform modules
│   ├── agent_environment/  # Provisions APIs, GCS bucket, and runtime SA for Test & Prod
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── cicd_pipeline/      # Provisions Cloud Build runner SA, IAM, and triggers
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/            # State-isolated root modules (independent remote backends)
    ├── test/               # State prefix: environments/test
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    ├── prod/               # State prefix: environments/prod
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── versions.tf
    └── cicd/               # State prefix: environments/cicd
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

## Configuration & Workable Environment Pattern

Each root module follows the standard `.env` / `.env.example` workflow:
1. **Variables Template**: `terraform.tfvars.example` is committed to git with sanitized placeholders.
2. **Active Variables**: Copy `terraform.tfvars.example` to `terraform.tfvars`. Terraform automatically reads this file on `plan` / `apply`. It is strictly ignored by [`.gitignore`](../../.gitignore).
3. **Backend Template**: Copy `backend.tfvars.example` to `backend.tfvars`. Initialize with `terraform init -backend-config=backend.tfvars`.

## Quickstart

1. **Bootstrap State Backend**:
   ```bash
   ./scripts/bootstrap_terraform_state.sh "your-cicd-project-id" "us-central1" "your-state-bucket-name"
   ```

2. **Deploy Test Environment**:
   ```bash
   cd terraform/environments/test
   cp terraform.tfvars.example terraform.tfvars   # Edit with your project ID
   cp backend.tfvars.example backend.tfvars       # Edit with your state bucket
   terraform init -backend-config=backend.tfvars
   terraform apply
   ```

3. **Deploy Production Environment**:
   ```bash
   cd ../prod
   cp terraform.tfvars.example terraform.tfvars   # Edit with your project ID
   cp backend.tfvars.example backend.tfvars       # Edit with your state bucket
   terraform init -backend-config=backend.tfvars
   terraform apply
   ```

4. **Deploy CI/CD Pipelines & Triggers**:
   ```bash
   cd ../cicd
   cp terraform.tfvars.example terraform.tfvars   # Edit with your IDs & GitHub repo
   cp backend.tfvars.example backend.tfvars       # Edit with your state bucket
   terraform init -backend-config=backend.tfvars
   terraform apply
   ```

For comprehensive details on state isolation, disaster recovery, locking, and chicken-and-egg bootstrapping, see [`documentation/terraform-architecture.md`](../documentation/terraform-architecture.md).
