# Agent Architecture Rationale: Dependent Cloud Storage & SDLC Demonstration

The greeting_agent is intentionally simple to make it easier to focus on the SDLC and the rationale behind the architecture. The agent depends on a GCS bucket and is intended to demonstrate features that production-facing agents need:
1. **Cross-Project IAM Roles**: Autonomous workloads must authenticate and operate under strict least-privilege service accounts without public API keys.
2. **Infrastructure as Code (IaC)**: Supporting cloud resources must be provisioned and tracked across isolated environments (`test`, `prod`) using declarative Terraform.
3. **Environment-Specific Configuration**: Runtime settings must be strongly validated via Pydantic without hardcoded variables.
4. **Integration Evaluations**: CI/CD pipelines must gate releases using deterministic test harnesses that verify agent tool trajectories and dependent resource connectivity.

---

## 2. The Reference Implementation: `greeting_agent`

In this repository, the primary implementation embodying this architecture is the **`greeting_agent`** (located in [`greeting_agent/`](../greeting_agent/)):

```mermaid
flowchart LR
    subgraph Client ["Client / Caller"]
        User["User Prompt"]
    end

    subgraph AgentRuntime ["Vertex AI Reasoning Engine / greeting_agent"]
        Agent["ADK root_agent<br/>(Gemini 3.8 Flash)"]
        ToolEnv["get_environment_and_security_context()"]
        ToolGCS["inspect_dependent_storage()"]
        Config["Pydantic AgentSettings<br/>(.env / environment variables)"]
    end

    subgraph Storage ["Google Cloud Storage"]
        Bucket["gs://<project-id>-data/audit/last_greeting.json"]
    end

    User --> Agent
    Agent -.-> Config
    Agent --> ToolEnv
    Agent --> ToolGCS
    ToolGCS -->|Uploads JSON Audit| Bucket
```

### Key Responsibilities of `greeting_agent`:
1. **Warm Greeting & Environment Reporting**: Inspects runtime configuration (`dev`, `test`, `prod`) from Pydantic Settings.
2. **Security Context Auditing**: Surfaces active Google Cloud credentials, caller identity, target project ID, and region.
3. **Custom Configuration**: Outputs custom variables set via `.env` (such as `GREETING_BANNER`).
4. **Dependent Storage Audit**: Invokes `inspect_dependent_storage()` to connect to the project's dedicated GCS bucket (`adk-sdlc-test-01-data` or `adk-sdlc-prod-01-data`), verifying write access by recording an audit payload to `gs://<bucket>/audit/last_greeting.json`.

---