#!/usr/bin/env bash
# ==============================================================================
# Enterprise ADK Deployment Script
# ==============================================================================
# Deploys greeting_agent to Vertex AI Agent Engine / Reasoning Engine.
# Supports automated in-place updates when existing agent ID is found.

set -euo pipefail

TARGET_PROJECT="${1:-${GOOGLE_CLOUD_PROJECT:-}}"
TARGET_REGION="${2:-${GOOGLE_CLOUD_LOCATION:-us-central1}}"
TARGET_ENV="${3:-${ENVIRONMENT:-test}}"
TARGET_BUCKET="${4:-${GCS_BUCKET_NAME:-${TARGET_PROJECT:+$TARGET_PROJECT-data}}}"
DISPLAY_NAME="${DISPLAY_NAME:-greeting_agent}"

if [[ -z "${TARGET_PROJECT}" ]]; then
  echo "[-] ERROR: Target Project ID must be supplied as argument 1 or via GOOGLE_CLOUD_PROJECT." >&2
  echo "    Usage: $0 [PROJECT_ID] [REGION] [ENVIRONMENT] [BUCKET_NAME]" >&2
  exit 1
fi

echo "================================================================="
echo "Starting ADK Agent Deployment"
echo "  Target Project:  ${TARGET_PROJECT}"
echo "  Target Region:   ${TARGET_REGION}"
echo "  Environment:     ${TARGET_ENV}"
echo "  Storage Bucket:  ${TARGET_BUCKET}"
echo "  Display Name:    ${DISPLAY_NAME}"
echo "================================================================="

# 1. Prepare stage-specific .env for deployment packaging
echo "[1/4] Preparing stage-specific environment configuration..."
rm -f greeting_agent/.env
cat <<EOF > greeting_agent/.env
ENVIRONMENT=${TARGET_ENV}
GOOGLE_CLOUD_PROJECT=${TARGET_PROJECT}
GOOGLE_CLOUD_LOCATION=global
LLM_LOCATION=global
LLM_MODEL=gemini-3.8-flash
GOOGLE_GENAI_USE_VERTEXAI=true
GOOGLE_GENAI_USE_ENTERPRISE=true
GREETING_BANNER=Enterprise ADK SDLC Pipeline Live (${TARGET_ENV})
GCS_BUCKET_NAME=${TARGET_BUCKET}
EOF

# Determine python and adk command runners (avoiding redundant venv sync in CI containers)
if command -v adk >/dev/null 2>&1; then
  PYTHON_BIN="python3"
  ADK_BIN="adk"
elif [[ -d ".venv" && -f ".venv/bin/adk" ]]; then
  PYTHON_BIN=".venv/bin/python"
  ADK_BIN=".venv/bin/adk"
elif command -v uv >/dev/null 2>&1; then
  PYTHON_BIN="uv run --no-project python"
  ADK_BIN="uv run --no-project adk"
else
  PYTHON_BIN="python3"
  ADK_BIN="adk"
fi

# 2. Check for existing deployment ID for in-place update
echo "[2/4] Inspecting existing Reasoning Engines in ${TARGET_PROJECT}..."
EXISTING_ID=$(${PYTHON_BIN} scripts/get_agent_id.py --project="${TARGET_PROJECT}" --region="${TARGET_REGION}" --display_name="${DISPLAY_NAME}" || true)

# 3. Execute ADK deployment
echo "[3/4] Deploying agent to Vertex AI Agent Engine..."
DEPLOY_ARGS=(
  "deploy" "agent_engine"
  "--project=${TARGET_PROJECT}"
  "--region=${TARGET_REGION}"
  "--display_name=${DISPLAY_NAME}"
  "--description=Enterprise Greeting Agent with SDLC gating and GCS dependent storage"
)

if [[ -n "${EXISTING_ID}" ]]; then
  echo "Found existing Reasoning Engine ID: ${EXISTING_ID}. Performing in-place update..."
  DEPLOY_ARGS+=("--agent_engine_id=${EXISTING_ID}")
else
  echo "No existing Reasoning Engine found. Performing fresh deployment..."
fi

DEPLOY_ARGS+=("greeting_agent")

${ADK_BIN} "${DEPLOY_ARGS[@]}"

# 4. Verify deployment
echo "[4/4] Verifying deployed Reasoning Engine..."
NEW_ID=$(${PYTHON_BIN} scripts/get_agent_id.py --project="${TARGET_PROJECT}" --region="${TARGET_REGION}" --display_name="${DISPLAY_NAME}")
if [[ -z "${NEW_ID}" ]]; then
  echo "ERROR: Unable to locate deployed Reasoning Engine ID after deployment." >&2
  exit 1
fi

echo "Deployed Reasoning Engine ID: ${NEW_ID}"
${PYTHON_BIN} scripts/verify_agent_api.py --project="${TARGET_PROJECT}" --region="${TARGET_REGION}" --agent_id="${NEW_ID}"

echo "================================================================="
echo "Deployment and verification SUCCEEDED for ${TARGET_PROJECT}!"
echo "================================================================="
