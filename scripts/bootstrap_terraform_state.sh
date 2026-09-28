#!/usr/bin/env bash
# ==============================================================================
# Bootstrap Terraform Remote State Bucket (GCP Cloud Storage)
# ==============================================================================
# This script automates solving the Terraform chicken-and-egg bootstrap problem.
# It provisions the central GCS bucket used by all environment backends with:
#   - Uniform bucket-level access
#   - Object versioning (for disaster recovery and state rollback)
#   - Public access prevention
#
# Usage:
#   ./scripts/bootstrap_terraform_state.sh [PROJECT_ID] [REGION] [BUCKET_NAME]
#
# Defaults:
CI_PROJECT_ID="${1:-${GOOGLE_CLOUD_PROJECT:-}}"
REGION="${2:-${GOOGLE_CLOUD_LOCATION:-us-central1}}"
BUCKET_NAME="${3:-${CI_PROJECT_ID:+$CI_PROJECT_ID-terraform-state}}"

if [[ -z "${CI_PROJECT_ID}" ]]; then
  echo "[-] ERROR: Google Cloud Project ID must be supplied as argument 1 or via GOOGLE_CLOUD_PROJECT." >&2
  echo "    Usage: $0 [PROJECT_ID] [REGION] [BUCKET_NAME]" >&2
  exit 1
fi

echo "=================================================================="
echo " Bootstrapping Terraform Remote State Backend"
echo "=================================================================="
echo " Project:     ${CI_PROJECT_ID}"
echo " Region:      ${REGION}"
echo " State Bucket: gs://${BUCKET_NAME}"
echo "=================================================================="

# 1. Verify gcloud credentials
if ! gcloud auth print-access-token >/dev/null 2>&1; then
  echo "[-] ERROR: Google Cloud CLI is not authenticated. Run 'gcloud auth login' first." >&2
  exit 1
fi

# 2. Enable Storage API on CI Project
echo "[+] Enabling storage.googleapis.com on ${CI_PROJECT_ID}..."
gcloud services enable storage.googleapis.com --project="${CI_PROJECT_ID}"

# 3. Check if bucket already exists
if gcloud storage buckets describe "gs://${BUCKET_NAME}" --project="${CI_PROJECT_ID}" >/dev/null 2>&1; then
  echo "[*] Bucket gs://${BUCKET_NAME} already exists."
else
  echo "[+] Creating state bucket gs://${BUCKET_NAME}..."
  gcloud storage buckets create "gs://${BUCKET_NAME}" \
    --project="${CI_PROJECT_ID}" \
    --location="${REGION}" \
    --uniform-bucket-level-access \
    --public-access-prevention
fi

# 4. Ensure Object Versioning is enabled for state disaster recovery
echo "[+] Ensuring object versioning is enabled on gs://${BUCKET_NAME}..."
gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning

echo "=================================================================="
echo "[+] SUCCESS: Terraform backend bucket is ready!"
echo "    GCS URI: gs://${BUCKET_NAME}"
echo "    You can now run 'terraform init' in your environment directories:"
echo "      - terraform/environments/test"
echo "      - terraform/environments/prod"
echo "      - terraform/environments/cicd"
echo "=================================================================="
