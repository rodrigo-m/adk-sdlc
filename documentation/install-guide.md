# GCP Installation & Deployment Guide: ADK SDLC Reference Architecture

This guide walks through deploying the entire Google Agent Development Kit (ADK) Software Development Life Cycle (SDLC) on Google Cloud Platform from scratch within 60 minutes.

---

## Architecture Overview

The SDLC spans three isolated GCP projects ensuring defense-in-depth and environment segregation:

![3-Project Architecture: 2 Runtime Environments + 1 SDLC Orchestration Project](./images/three-project-architecture.jpeg)

```
+---------------------------------------------------------------------------------------+
|  1. CI/CD Orchestration Project: [adk-sdlc]                                           |
|  - Cloud Build 2nd Gen GitHub Connection & Repositories                               |
|  - Continuous Deployment Triggers (Automated Test & Manual Approval Prod)             |
|  - Dedicated CI/CD Service Account: sa-adk-cicd-runner@adk-sdlc.iam.gserviceaccount.com|
+---------------------------------------------------------------------------------------+
                    |                                       |
    (Automatic Push to main)                  (Manual Approval Required)
                    v                                       v
+---------------------------------------+   +---------------------------------------+
|  2. Test Project: [adk-sdlc-test-01]  |   |  3. Prod Project: [adk-sdlc-prod-01]  |
|  - Vertex AI Reasoning Engine         |   |  - Vertex AI Reasoning Engine         |
|  - Dependent GCS Bucket               |   |  - Dependent GCS Bucket               |
|  - Least-privilege Test SA            |   |  - Least-privilege Prod SA            |
+---------------------------------------+   +---------------------------------------+
```

---

## Prerequisites

1. **Google Cloud CLI (`gcloud`)** installed and authenticated:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```
2. **Terraform** (>= 1.5.0) installed:
   ```bash
   terraform -version
   ```
3. **`uv` Package Manager** installed:
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
4. **Active Google Cloud Billing Account**.

---

## Step 1: Project Creation & Billing Association

Set your unique project IDs and billing account ID:

```bash
export BILLING_ACCOUNT_ID="YOUR_BILLING_ACCOUNT_ID"
export CI_PROJECT_ID="adk-sdlc"
export TEST_PROJECT_ID="adk-sdlc-test-01"
export PROD_PROJECT_ID="adk-sdlc-prod-01"
export REGION="us-central1"

# Create CI/CD Project
gcloud projects create "${CI_PROJECT_ID}" --name="ADK CI/CD"
gcloud billing projects link "${CI_PROJECT_ID}" --billing-account="${BILLING_ACCOUNT_ID}"

# Create Test Project
gcloud projects create "${TEST_PROJECT_ID}" --name="ADK Test"
gcloud billing projects link "${TEST_PROJECT_ID}" --billing-account="${BILLING_ACCOUNT_ID}"

# Create Prod Project
gcloud projects create "${PROD_PROJECT_ID}" --name="ADK Prod"
gcloud billing projects link "${PROD_PROJECT_ID}" --billing-account="${BILLING_ACCOUNT_ID}"
```

---

## Step 2: Enable Required GCP APIs

Enable the necessary APIs across all three projects:

```bash
SERVICES=(
  aiplatform.googleapis.com
  cloudbuild.googleapis.com
  storage.googleapis.com
  iam.googleapis.com
  logging.googleapis.com
  serviceusage.googleapis.com
)

for PROJECT in "${CI_PROJECT_ID}" "${TEST_PROJECT_ID}" "${PROD_PROJECT_ID}"; do
  echo "Enabling APIs on ${PROJECT}..."
  gcloud services enable "${SERVICES[@]}" --project="${PROJECT}"
done
```

---

## Step 3: Configure Cloud Build 2nd Gen GitHub Connection

1. In the Google Cloud Console for project `${CI_PROJECT_ID}`, navigate to **Cloud Build** -> **Repositories (2nd gen)**.
2. Click **Create Host Connection**, select **GitHub**, and authorize the Google Cloud Build GitHub App.
   - Example connection name: `github-connection-001` (region: `us-central1`).
3. Click **Link Repository** and select your connected repository.

---

## Step 4: Provision Infrastructure via Terraform (State-Isolated)

Terraform manages all non-release infrastructure: dependent GCS storage buckets, dedicated service accounts, cross-project IAM roles, and Cloud Build triggers. Infrastructure state is isolated across distinct directories and backends to prevent cross-environment state mutation and unintended side effects (see [Terraform Architecture & State Management](terraform-architecture.md)).

Each environment directory uses `terraform.tfvars.example` and `backend.tfvars.example` templates, keeping active credentials and bucket configurations out of version control.

1. **Bootstrap the Remote GCS State Storage Bucket**:
   Run the automated bootstrap script to resolve the chicken-and-egg problem:
   ```bash
   ./scripts/bootstrap_terraform_state.sh "${CI_PROJECT_ID}" "${REGION}" "${CI_PROJECT_ID}-terraform-state"
   ```
   *(Alternatively, run `cd terraform/bootstrap && cp terraform.tfvars.example terraform.tfvars && terraform init && terraform apply && cd ../..`)*

2. **Provision Test Environment**:
   ```bash
   cd terraform/environments/test
   cp terraform.tfvars.example terraform.tfvars     # Populate test_project_id
   cp backend.tfvars.example backend.tfvars         # Populate bucket name
   terraform init -backend-config=backend.tfvars
   terraform apply -auto-approve
   ```

3. **Provision Production Environment**:
   ```bash
   cd ../prod
   cp terraform.tfvars.example terraform.tfvars     # Populate prod_project_id
   cp backend.tfvars.example backend.tfvars         # Populate bucket name
   terraform init -backend-config=backend.tfvars
   terraform apply -auto-approve
   ```

4. **Provision CI/CD Pipeline Triggers & Cross-Project IAM**:
   ```bash
   cd ../cicd
   cp terraform.tfvars.example terraform.tfvars     # Populate project IDs and GitHub repo
   cp backend.tfvars.example backend.tfvars         # Populate bucket name
   terraform init -backend-config=backend.tfvars
   terraform apply -auto-approve
   cd ../../..
   ```

---

## Step 5: Local Environment Setup (`uv` and `.env`)

1. Create and activate a hermetic Python virtual environment using `uv`:
   ```bash
   uv venv .venv --python 3.12
   source .venv/bin/activate
   uv sync
   ```
2. Configure local development variables:
   ```bash
   cp .env.example .env
   ln -sf ../.env greeting_agent/.env
   ```
3. Verify settings are loaded through Pydantic:
   ```bash
   uv run python -c "from greeting_agent.config import get_settings; print(get_settings())"
   ```

---

## Step 6: Execute Programmatic Evaluation Suite

Run the evaluation test harness locally to verify agent tool calling, environment detection, and GCS bucket connectivity:

```bash
uv run pytest tests/test_eval_harness.py -v --junitxml=reports/eval-results.xml
```

All 5 evaluation cases must pass. The resulting `reports/eval-results.xml` file is generated for automated CI consumption.

---

## Step 7: Deploying to Google Cloud

### Manual / Local CLI Deployment:
Deploy directly to the test project:
```bash
./scripts/deploy_agent.sh "${TEST_PROJECT_ID}" "${REGION}" "test" "${TEST_PROJECT_ID}-data"
```

### Automated CI/CD Pipeline (Cloud Build):
1. Push your changes to the `main` branch:
   ```bash
   git add .
   git commit -m "feat: implement enterprise ADK SDLC pipeline"
   git push origin main
   ```
2. **Test Pipeline**: Automatically starts, runs the pytest evaluation harness, and deploys to `adk-sdlc-test-01`.
3. **Production Pipeline**: Triggers on push, executes quality gating, and pauses with status `PENDING_APPROVAL`. Once an authorized engineer approves the build in the Cloud Build Console, it deploys in-place to `adk-sdlc-prod-01`.

---

## Step 8: Post-Deployment Verification

Verify the live reasoning engine endpoint:
```bash
AGENT_ID=$(uv run python scripts/get_agent_id.py --project="${TEST_PROJECT_ID}" --region="${REGION}" --display_name="greeting_agent")
uv run python scripts/verify_agent_api.py --project="${TEST_PROJECT_ID}" --region="${REGION}" --agent_id="${AGENT_ID}"
```
