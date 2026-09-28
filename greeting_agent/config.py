"""Configuration management using Pydantic Settings."""

from __future__ import annotations

import os
from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class AgentSettings(BaseSettings):
    """Strongly typed application configuration loaded from environment or .env file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    environment: str = Field(
        default="dev",
        validation_alias="ENVIRONMENT",
        description="Deployment stage: dev, test, or prod",
    )
    google_cloud_project: str = Field(
        default="adk-sdlc-test-01",
        validation_alias="GOOGLE_CLOUD_PROJECT",
        description="Google Cloud Project ID hosting the agent or runtime",
    )
    google_cloud_location: str = Field(
        default="us-central1",
        validation_alias="GOOGLE_CLOUD_LOCATION",
        description="Target GCP Region",
    )
    llm_model: str = Field(
        default="gemini-2.5-flash",
        validation_alias="LLM_MODEL",
        description="Gemini Model Identifier used by ADK",
    )
    greeting_banner: str = Field(
        default="Enterprise ADK SDLC Pipeline Live",
        validation_alias="GREETING_BANNER",
        description="Custom greeting message or banner configured via .env",
    )
    gcs_bucket_name: str = Field(
        default="adk-sdlc-test-01-data",
        validation_alias="GCS_BUCKET_NAME",
        description="Dependent Google Cloud Storage bucket name",
    )


@lru_cache
def get_settings() -> AgentSettings:
    """Returns cached, validated configuration instance and configures environment."""
    settings = AgentSettings()
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
    os.environ.setdefault("GOOGLE_CLOUD_PROJECT", settings.google_cloud_project)
    os.environ.setdefault("GOOGLE_CLOUD_LOCATION", settings.google_cloud_location)
    return settings

