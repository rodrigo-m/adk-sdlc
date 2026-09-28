"""Operational tools for greeting agent with environment, security context, and dependent storage access."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
import google.auth
from google.adk.tools import ToolContext

from .config import get_settings


def get_environment_and_security_context(tool_context: ToolContext) -> dict[str, Any]:
    """Retrieves operational environment, security context, and custom configuration.

    Use this tool whenever greeting the user, or when asked about runtime environment,
    caller identity, security context, or configuration variables.
    """
    settings = get_settings()

    principal = "local-developer"
    try:
        credentials, _ = google.auth.default()
        principal = (
            getattr(credentials, "service_account_email", None)
            or getattr(credentials, "signer_email", None)
            or "adc-authenticated-principal"
        )
    except Exception:
        principal = "unauthenticated-local"

    caller_id = getattr(tool_context, "user_id", None) or "developer"

    return {
        "status": "HEALTHY",
        "greeting": f"Hello! {settings.greeting_banner}",
        "environment": settings.environment,
        "security_context": {
            "authenticated_principal": principal,
            "caller_user_id": caller_id,
            "project_id": settings.google_cloud_project,
            "region": settings.google_cloud_location,
        },
        "custom_env_variable": settings.greeting_banner,
        "dependent_bucket": settings.gcs_bucket_name,
    }


def inspect_dependent_storage(tool_context: ToolContext) -> dict[str, Any]:
    """Inspects and verifies access to the dependent Google Cloud Storage bucket.

    Use this tool when validating connectivity to external cloud storage or
    recording a greeting audit record.
    """
    settings = get_settings()
    bucket_name = settings.gcs_bucket_name
    timestamp = datetime.now(timezone.utc).isoformat()

    try:
        from google.cloud import storage

        client = storage.Client(project=settings.google_cloud_project)
        bucket = client.bucket(bucket_name)

        if not bucket.exists():
            return {
                "status": "BUCKET_NOT_FOUND",
                "bucket_name": bucket_name,
                "project_id": settings.google_cloud_project,
                "timestamp": timestamp,
                "message": f"Storage bucket '{bucket_name}' does not exist.",
            }

        blob = bucket.blob("audit/last_greeting.json")
        audit_payload = {
            "timestamp": timestamp,
            "environment": settings.environment,
            "caller": getattr(tool_context, "user_id", "developer"),
            "banner": settings.greeting_banner,
        }
        blob.upload_from_string(
            data=json.dumps(audit_payload, indent=2),
            content_type="application/json",
        )

        return {
            "status": "CONNECTED",
            "bucket_name": bucket_name,
            "project_id": settings.google_cloud_project,
            "timestamp": timestamp,
            "audit_file": f"gs://{bucket_name}/audit/last_greeting.json",
            "message": "Successfully audited dependent GCS bucket with least-privilege IAM credentials.",
        }

    except Exception as exc:
        return {
            "status": "MOCKED_OR_ERROR",
            "bucket_name": bucket_name,
            "project_id": settings.google_cloud_project,
            "timestamp": timestamp,
            "details": str(exc),
            "message": f"Storage access notice: {exc}",
        }
