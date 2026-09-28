# Production SDLC Reference Architecture for Google ADK Agents

[![ADK Version](https://img.shields.io/badge/Google%20ADK-v2.9.2-blue.svg)](https://github.com/google/adk)
[![Python](https://img.shields.io/badge/Python-3.12-blue.svg)](https://www.python.org/)
[![GCP Vertex AI](https://img.shields.io/badge/GCP-Vertex%20AI%20Reasoning%20Engine-green.svg)](https://cloud.google.com/vertex-ai)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

An opinionated reference blueprint demonstrating how to implement a software development lifecycle for autonomous agents built with the [Google Agent Development Kit (ADK)](https://github.com/google/adk) on **Gemini Enterprise Agent Platform (GCP)**.

This repository provides an automated CI/CD pipeline spanning three isolated environments: dev (local), test, and prod. It also shows:

- Programmatic evaluation quality gating using ADK standards
- Least-privilege IAM management
- Dependent cloud resource integration
- In-place updates

![Enterprise ADK SDLC Architecture: 2 Runtime Environments + 1 SDLC Orchestration Project](documentation/images/three-project-architecture.jpeg)

> [!NOTE]
> **Architectural Context & Disclaimer**  
> This repository provides a reference implementation informed by practical experience across small and large organizations. However, this repository is a reference architecture, not a universal prescription nor a guaranteed solution. Operational requirements and security policies differ across companies, so be sure to adapt these patterns to your organization's specific governance and compliance needs.

---

## Table of Contents & Section Shortcuts

- [Repository Summary](#repository-summary)
- [The Opinionated Architecture & Stack](#the-opinionated-architecture-stack)
- [Three-Project GCP Topology](#three-project-gcp-topology)
- [Greeting Agent Architecture & Dependencies](#greeting-agent-architecture-dependencies)
- [Evaluation Suite & Programmatic Harness](#evaluation-suite-programmatic-harness)
- [Quickstart: Local Setup in 5 Minutes](#quickstart-local-setup-in-5-minutes)
- [Standing Up the Cloud Environments (Terraform)](#standing-up-the-cloud-environments-terraform)
- [CI/CD Pipelines & Cloud Build Triggers](#cicd-pipelines-cloud-build-triggers)
- [Comprehensive Q&A: ADK SDLC & Operations](#comprehensive-qa-adk-sdlc--operations)
- [Repository File Structure](#repository-file-structure)
- [Step-by-Step Installation Guide](#step-by-step-installation-guide)
- **Deep-Dive Guides**:
  - [Complete GCP Installation Runbook](documentation/install-guide.md)
  - [Terraform Architecture & State Isolation](documentation/terraform-architecture.md)
  - [Agent Dependent Resource Rationale](documentation/agent-example-rationale.md)
  - [Programmatic Evaluation Harness Rationale](documentation/eval-harness-rationale.md)

---

## Repository Summary

In this repository, you will find:
1. **The `greeting_agent`**: A reference ADK agent that warmly greets users, reports its runtime execution environment (`dev`, `test`, `prod`), outputs its active security context (caller identity and authenticated service account principal), surfaces extra variables via strongly-typed Pydantic settings, and audits dependent Google Cloud Storage (GCS) buckets.
2. **Programmatic Evaluation Test Harness (`tests/test_eval_harness.py`)**: A hermetic `pytest` harness executing standard ADK evaluation sets (`greeting_agent/evals/greeting_agent.evalset.json`), asserting tool call trajectories and semantic responses, enforcing non-zero exit codes on failure, and producing standard JUnit XML reports (`reports/eval-results.xml`).
3. **Terraform Infrastructure as Code (`terraform/`)**: Modular, state-isolated declarative configuration with independent remote GCS backends for `bootstrap/`, `test/`, `prod/`, and `cicd/`, provisioning dependent GCS buckets, dedicated service accounts, cross-project least-privilege IAM roles, and Cloud Build 2nd gen triggers. See [Terraform Architecture](documentation/terraform-architecture.md).
4. **Automated CI/CD Pipelines (`cloudbuild-test.yaml`, `cloudbuild-prod.yaml`)**: Continuous deployment to `test` on push to `main`, and manual approval-gated deployment to `prod`.
5. **Operational Automation Scripts (`scripts/`)**: In-place reasoning engine update detection (`get_agent_id.py`), unified deployment runner (`deploy_agent.sh`), and post-deployment live smoke tester (`verify_agent_api.py`).

---

## The Opinionated Architecture & Stack

There are many ways to manage agents and cloud infrastructure. This repository selects and explains a recommended production stack:

| Component | Selected Technology | Rationale & Architectural Considerations |
| :--- | :--- | :--- |
| **Agent Framework** | **Google ADK (>=2.9.2)** | Native Google Agent Development Kit featuring modular agents, built-in runner workflows, and direct Vertex AI Agent Engine integration. |
| **Model Backend** | **Vertex AI SDK (`gemini-2.5-flash`)** | Zero public API keys. Authenticates using Google Application Default Credentials (ADC) and IAM service accounts in `us-central1`. |
| **Package Management** | **`uv` (Astral)** | Next-generation Python package manager providing ultra-fast, deterministic virtual environment management (`uv venv`, `uv sync`). |
| **Configuration & Typing**| **Pydantic Settings (`BaseSettings`)** | Environment-based configuration with strict type validation, field fallbacks, and zero hardcoded secrets. |
| **Source Control** | **GitHub** | Integrated with Cloud Build via 2nd-gen Google Cloud Build GitHub Host Connections. |
| **CI/CD Orchestration** | **Google Cloud Build** | Native GCP serverless CI/CD running within your security perimeter, eliminating external credential exposure. |
| **Quality Gating** | **Programmatic `pytest` + ADK Evals** | Wraps ADK `evalset.json` in deterministic test runners to ensure non-zero exit codes block broken deployments. |
| **Runtime Target** | **Vertex AI Agent Engine / Reasoning Engine** | Managed, autoscaling, serverless agent execution environment with native session management and Cloud Monitoring observability. |
| **Infrastructure as Code**| **Terraform (Google Provider >=6.0)** | Declarative lifecycle management of IAM, Cloud Storage, and Cloud Build triggers. |

---

## Three-Project GCP Topology

To enforce environment isolation, prevent cross-project impact, and maintain separation of duties, the architecture is distributed across three Google Cloud projects:

```
+-------------------------------------------------------------------------------------------------+
|                                    CI/CD Project: [adk-sdlc]                                    |
|                                                                                                 |
|   - 2nd Gen GitHub Host Connection (github-connection-001)                                      |
|   - Connected Repository (your-connected-repo)                                                 |
|   - CI/CD Runner Service Account: sa-adk-cicd-runner@adk-sdlc.iam.gserviceaccount.com           |
|                                                                                                 |
|   +---------------------------------------+   +---------------------------------------------+   |
|   | Test Trigger: deploy-test-pipeline    |   | Prod Trigger: deploy-prod-pipeline          |   |
|   | - Trigger: Push to ^main$             |   | - Trigger: Push to ^main$                   |   |
|   | - Approval: AUTOMATIC                 |   | - Approval: MANUAL REQUIRED                 |   |
|   | - Config: cloudbuild-test.yaml        |   | - Config: cloudbuild-prod.yaml              |   |
|   +---------------------------------------+   +---------------------------------------------+   |
+-------------------------------------------------------------------------------------------------+
                                |                                               |
                  (Deploys on Eval Success)                       (Deploys Post-Approval)
                                v                                               v
+-----------------------------------------------+   +-----------------------------------------------+
|          Test Project: [adk-sdlc-test-01]     |   |          Prod Project: [adk-sdlc-prod-01]     |
|                                               |   |                                               |
| - Gemini Enterprise Agent Runtime             |   | - Gemini Enterprise Agent Runtime             |
| - Dependent Bucket: adk-sdlc-test-01-data     |   | - Dependent Bucket: adk-sdlc-prod-01-data     |
| - Runtime SA: sa-greeting-agent-test          |   | - Runtime SA: sa-greeting-agent-prod          |
| - Storage Permissions: roles/storage.objectUser|  | - Storage Permissions: roles/storage.objectUser|
+-----------------------------------------------+   +-----------------------------------------------+
```

---

## Greeting Agent Architecture & Dependencies

The agent (`greeting_agent`) is designed to showcase practical agent patterns:

1. **Persona & Root Agent**: Defined in [`greeting_agent/agent.py`](greeting_agent/agent.py) with structured system instructions directing tool usage.
2. **Strongly-Typed Config**: Loaded via Pydantic `AgentSettings` in [`greeting_agent/config.py`](greeting_agent/config.py). Reads `ENVIRONMENT`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, `LLM_MODEL`, `GREETING_BANNER`, and `GCS_BUCKET_NAME`.
3. **Operational Tools**:
   - `get_environment_and_security_context`: Inspects the active Google Cloud credential principal, caller identity, target project, and custom `.env` banner.
   - `inspect_dependent_storage`: Exercises dependent cloud infrastructure by connecting to the project's GCS bucket, validating object permissions, and logging a greeting audit payload to `gs://<bucket>/audit/last_greeting.json`.

For architectural rationale on using file-based GCS dropzones without vector RAG complexity, see [Agent Dependent Resource Architecture](documentation/agent-example-rationale.md).

---

## Evaluation Suite & Programmatic Harness

Evaluating agents requires more than running loose prompt tests; it demands automated **quality gating** in CI/CD.

### The Eval Set (`greeting_agent/evals/greeting_agent.evalset.json`)
Contains 5 comprehensive evaluation cases formatted according to ADK standards:
- `eval_01_environment_and_greeting`: Tests warm greeting and environment recognition.
- `eval_02_security_context_inspection`: Tests security context and principal auditing.
- `eval_03_custom_env_variable`: Tests surfacing custom configuration banners from Pydantic.
- `eval_04_dependent_storage_audit`: Tests GCS dependent storage connectivity.
- `eval_05_comprehensive_status_report`: Tests multi-tool invocation for full diagnostics.

### Why a Programmatic Test Harness?
While `adk eval` is convenient for exploratory CLI testing, standard CLI eval tools frequently return exit code `0` even when individual evals fail. The programmatic harness in [`tests/test_eval_harness.py`](tests/test_eval_harness.py):
1. Programmatically loads `greeting_agent.evalset.json`.
2. Runs the agent asynchronously through the ADK `Runner` and `InMemorySessionService`.
3. Performs strict assertions on tool call trajectories and semantic responses.
4. Fails with exit code `1` whenever an assertion fails, reliably blocking deployment.
5. Emits standard JUnit XML test reports (`reports/eval-results.xml`) for CI tracking.

For an in-depth breakdown of exit code gating, JUnit XML reporting, and hermetic mocking, see [Evaluation Harness Rationale](documentation/eval-harness-rationale.md).

---

## Quickstart: Local Setup in 5 Minutes

### 1. Clone & Set Up Python Virtual Environment
```bash
git clone https://github.com/<your-username>/adk-sdlc.git
cd adk-sdlc

# Create hermetic virtual environment using uv
uv venv .venv --python 3.12
source .venv/bin/activate

# Install all dependencies
uv sync
```

### 2. Configure Local Application Environment (`.env`)
Follow the workable template pattern:
```bash
# Copy the sanitized template to active local .env
cp .env.example .env

# Create symbolic link so the greeting_agent package reads root settings
ln -sf ../.env greeting_agent/.env
```
> [!NOTE]
> `.env` is strictly ignored by [`.gitignore`](.gitignore), ensuring active project IDs and settings are never committed to version control.

### 3. Authenticate with Google Cloud
Authenticate your user and Application Default Credentials (ADC):
```bash
gcloud auth login
gcloud auth application-default login
```

### 4. Run the Programmatic Evaluation Suite
Execute the 5-case evaluation harness locally:
```bash
uv run pytest tests/test_eval_harness.py -v --junitxml=reports/eval-results.xml
```

### 5. Run the Agent Locally via ADK Web UI
Launch the ADK interactive browser UI:
```bash
uv run adk web greeting_agent
```

---

## Standing Up the Cloud Environments (Terraform)

Infrastructure is managed across state-isolated layers using Terraform. Just like `.env.example` -> `.env`, Terraform utilizes a **workable template workflow**:

| File | Purpose | Git Status |
| :--- | :--- | :--- |
| `terraform.tfvars.example` | Template with generic placeholders (`your-test-project-id`) | **Tracked** in git |
| `backend.tfvars.example` | Template with generic state bucket name | **Tracked** in git |
| `terraform.tfvars` | Active values; automatically loaded by `terraform plan/apply` | **Ignored** by `.gitignore` |
| `backend.tfvars` | Active state bucket; passed via `-backend-config=backend.tfvars` | **Ignored** by `.gitignore` |

Follow these 4 steps to stand up the complete multi-project infrastructure:

### Step 1: Bootstrap Remote State Storage
Creates the centralized GCS bucket for Terraform remote state with Uniform Bucket-Level Access and Object Versioning:
```bash
./scripts/bootstrap_terraform_state.sh "your-cicd-project-id" "us-central1" "your-state-bucket-name"
```

### Step 2: Stand Up Test Environment
Provisions test project APIs, dedicated test GCS bucket, and runtime service account:
```bash
cd terraform/environments/test
cp terraform.tfvars.example terraform.tfvars     # Fill in test_project_id
cp backend.tfvars.example backend.tfvars         # Fill in state bucket name
terraform init -backend-config=backend.tfvars
terraform apply
```

### Step 3: Stand Up Production Environment
Provisions prod project APIs, dedicated prod GCS bucket, and runtime service account:
```bash
cd ../prod
cp terraform.tfvars.example terraform.tfvars     # Fill in prod_project_id
cp backend.tfvars.example backend.tfvars         # Fill in state bucket name
terraform init -backend-config=backend.tfvars
terraform apply
```

### Step 4: Stand Up CI/CD Pipelines & Cross-Project Triggers
Provisions the Cloud Build runner service account, cross-project IAM roles, and automated triggers:
```bash
cd ../cicd
cp terraform.tfvars.example terraform.tfvars     # Fill in project IDs & github_repo_name
cp backend.tfvars.example backend.tfvars         # Fill in state bucket name
terraform init -backend-config=backend.tfvars
terraform apply
cd ../../..
```

---

## CI/CD Pipelines & Cloud Build Triggers

### Test Pipeline (`cloudbuild-test.yaml`)
Triggered automatically on every `git push` to `main`:
1. **Sync Dependencies**: Installs `uv` and synchronizes required packages.
2. **Quality Gate**: Runs `pytest tests/test_eval_harness.py`. If any evaluation fails, the pipeline aborts immediately.
3. **Artifact Archiving**: Exports `reports/eval-results.xml` to Cloud Storage.
4. **Deploy Agent**: Invokes [`scripts/deploy_agent.sh`](scripts/deploy_agent.sh) to update the Reasoning Engine in `adk-sdlc-test-01`.
5. **Verify API**: Runs [`scripts/verify_agent_api.py`](scripts/verify_agent_api.py) to confirm endpoint health.

### Production Pipeline (`cloudbuild-prod.yaml`)
Triggered on `git push` to `main`, but pauses with `approval_config { approval_required = true }`:
1. Cloud Build alerts release managers that a production build is pending.
2. Upon manual approval via the Google Cloud Console or gcloud CLI, the pipeline runs the production evaluation gate, deploys in-place to `adk-sdlc-prod-01`, and conducts live verification.

---

## Comprehensive Q&A: ADK SDLC & Operations

### 1. How do I manage Terraform across test and prod environments?
**Answer:**
Separate infrastructure lifecycle from application code release, and strictly **isolate state files by environment and layer**:
- Use Terraform to manage static resources that outlive releases: GCS buckets, service accounts, IAM roles, and Cloud Build triggers.
- In this repository, infrastructure is split into distinct directory roots with independent remote GCS state prefixes:
  - `terraform/bootstrap/`: Creates the central GCS state bucket (resolving the chicken-and-egg problem).
  - `terraform/environments/test/`: Manages test project APIs, bucket, and test runtime SA (state prefix: `environments/test`).
  - `terraform/environments/prod/`: Manages prod project APIs, bucket, and prod runtime SA (state prefix: `environments/prod`).
  - `terraform/environments/cicd/`: Manages Cloud Build runner SA, cross-project deployment permissions, and triggers (state prefix: `environments/cicd`).
- Shared logic is encapsulated in reusable modules under `terraform/modules/` (`agent_environment` and `cicd_pipeline`).
- This design isolates environment state files, prevents accidental modifications across test and production, and supports independent concurrency locking. For a full architectural deep-dive, see [Terraform Architecture & State Management](documentation/terraform-architecture.md).

### 2. How do I manage permissions across environments?
**Answer:**
Adopt the **Principle of Least Privilege (PoLP)** and decouple CI/CD deployment identities from agent runtime identities:
- **CI/CD Identity (`sa-adk-cicd-runner@adk-sdlc`)**: Granted cross-project deployment privileges (`roles/aiplatform.admin`, `roles/storage.admin`, and `roles/iam.serviceAccountUser`) on the target test and prod projects. It cannot perform arbitrary project administration.
- **Agent Runtime Identity (`sa-greeting-agent-test` / `prod`)**: Granted only what the agent itself requires: `roles/aiplatform.user` (to query Gemini via Vertex AI) and `roles/storage.objectUser` scoped exclusively to its specific dependent bucket (`adk-sdlc-test-01-data`).
- Cross-project IAM bindings in Terraform explicitly link the CI/CD runner to the target projects without granting broad organization-level roles.

### 3. How do I manage variables (.env and Pydantic)?
**Answer:**
Never rely on loose `os.environ.get()` calls scattered throughout your codebase. Use **Pydantic Settings** (`BaseSettings`):
- Declare a single configuration model ([`greeting_agent/config.py`](greeting_agent/config.py)) specifying data types, default values, and environment variable aliases.
- Pydantic validates configuration upon startup, failing fast with informative error messages if an integer is malformed, a required URL is missing, or an unexpected environment string is provided.
- Load variables via `.env` files locally and environment variables in containerized Cloud Build runs.

### 4. How do I manage sensitive data in .env?
**Answer:**
Enforce strict hygiene to eliminate secret leakage:
1. Provide a sanitized template: [`.env.example`](.env.example) documenting all required variables with placeholder values.
2. Strictly ignore secrets: Ensure `.env`, `.env.*`, `*.key`, `*.json`, and credential files are explicitly barred in [`.gitignore`](.gitignore).
3. In cloud environments, never commit credentials or API keys. ADK leverages **Vertex AI Application Default Credentials (ADC)**. For database passwords or third-party tokens, resolve them dynamically from **Google Cloud Secret Manager** at deployment or runtime.

### 5. How do I make my coding agent smarter about deployments?
**Answer:**
Equip the coding agent with deterministic deployment scripts and CLI tooling:
- Rather than forcing an LLM or CI runner to improvise complex multi-step deployment commands, encapsulate lifecycle logic into dedicated, self-documenting shell and Python scripts ([`scripts/deploy_agent.sh`](scripts/deploy_agent.sh), [`scripts/get_agent_id.py`](scripts/get_agent_id.py), [`scripts/verify_agent_api.py`](scripts/verify_agent_api.py)).
- Expose clear flags (`--project`, `--region`, `--display_name`, `--agent_engine_id`).
- When coding agents assist in infrastructure tasks, provide clear Terraform blueprints and schema constraints so generated infrastructure is compliant by design.

### 6. How do I manage agents in production that are exposed to Gemini Enterprise / Vertex AI?
**Answer:**
**Deploy using the same resource ID (In-place updates).**
When an agent is deployed to Vertex AI Agent Engine or Reasoning Engine, GCP assigns it a unique resource identifier (e.g., `projects/123/locations/us-central1/reasoningEngines/456`).
- Downstream integrations—such as Gemini Enterprise, Slack bots, web frontends, or orchestration workflows—bind directly to this resource ID.
- If you deploy a new agent instance on every build, downstream systems break until manually reconfigured.
- **Solution**: [`scripts/get_agent_id.py`](scripts/get_agent_id.py) queries Vertex AI for existing Reasoning Engines matching `display_name`. If found, `adk deploy agent_engine` passes `--agent_engine_id=<id>`. This performs an in-place container and artifact update, preserving the exact same endpoint URI and eliminating configuration churn.

### 7. How do I run evals across environments?
**Answer:**
Structure evaluations according to the deployment phase:
- **Pre-deployment (CI Quality Gate)**: Run fast, hermetic evaluations using `InMemorySessionService` and mocked or test-scoped cloud resources. These verify prompt compliance, tool call trajectories, and security guardrails before code is deployed.
- **Post-deployment (Staging / Pre-prod Verification)**: Execute end-to-end integration smoke tests against the deployed Reasoning Engine endpoint using real dependent services (GCS, BigQuery, databases) to detect permission regressions or network latency anomalies.
- **Production Monitoring (Continuous Evals & Tracing)**: Enable OpenTelemetry (`--otel_to_cloud`) in ADK to stream runtime traces, latency metrics, and user feedback into Google Cloud Logging and Cloud Monitoring.

---

## Repository File Structure

```
adk-sdlc/
├── .env.example                     # Sanitized configuration template
├── .gitignore                       # Strict ignores for credentials, .env, and terraform
├── pyproject.toml                   # Root project configuration and pytest settings
├── README.md                        # Primary SDLC documentation and architecture guide
├── cloudbuild-test.yaml             # Automated CI/CD pipeline for Test environment
├── cloudbuild-prod.yaml             # Manual-approval CI/CD pipeline for Prod environment
├── greeting_agent/                  # ADK Agent source code
│   ├── __init__.py                  # Package exports
│   ├── agent.py                     # Root agent definition, instructions, and tools
│   ├── config.py                    # Strongly typed Pydantic Settings
│   ├── tools.py                     # Tools for security context & GCS storage inspection
│   ├── requirements.txt             # Agent dependencies
│   └── evals/                       # Evaluation suites
│       └── greeting_agent.evalset.json  # 5 standard ADK evaluation cases
├── tests/                           # Testing & gating
│   └── test_eval_harness.py         # Programmatic pytest harness enforcing non-zero exit codes
├── terraform/                       # Infrastructure as Code (State-Isolated & Modular)
│   ├── README.md                    # Quickstart guide for Terraform operators
│   ├── bootstrap/                   # Provisions remote state GCS bucket (solves chicken-and-egg)
│   ├── modules/                     # Reusable modules (agent_environment, cicd_pipeline)
│   └── environments/                # State-isolated roots (test, prod, cicd)
├── scripts/                         # Operational automation
│   ├── bootstrap_terraform_state.sh # Automated idempotent GCS state bucket bootstrap
│   ├── get_agent_id.py              # Queries existing Reasoning Engine ID for updates
│   ├── deploy_agent.sh              # Unified deployment script with in-place updates
│   └── verify_agent_api.py          # Post-deployment live smoke verification
└── documentation/                   # Deep-dive documentation
    ├── terraform-architecture.md    # Complete guide on Terraform state isolation & bootstrap
    ├── install-guide.md             # Complete step-by-step GCP installation guide
    ├── learning-goals.md            # Project requirements specification
    ├── agent-example-rationale.md   # Architectural rationale for GCS dependent storage
    └── eval-harness-rationale.md    # Architectural rationale for programmatic test harnesses
```

---

## Step-by-Step Installation Guide

For complete, copy-pasteable instructions on initializing Google Cloud projects, setting up GitHub 2nd gen connections, executing Terraform, running evals, and verifying deployed agents, refer to the [Complete Installation Guide](documentation/install-guide.md).
