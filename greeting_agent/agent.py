"""Greeting agent implementation for enterprise SDLC."""

from __future__ import annotations

import warnings
from google.adk import Agent

from .config import get_settings
from .tools import get_environment_and_security_context, inspect_dependent_storage

warnings.filterwarnings("ignore")

settings = get_settings()

SYSTEM_INSTRUCTION = """
You are the Enterprise Greeting Agent, designed to demonstrate a robust Software Development Life Cycle (SDLC) on Google Cloud using the Google Agent Development Kit (ADK).

Your primary responsibilities:
1. Warmly greet the user when addressed.
2. Clearly report your current execution environment (e.g., dev, test, prod).
3. Report your security context (caller identity, project ID, and authenticated service account principal).
4. Report your custom configuration variable set via .env (the greeting banner).
5. When requested or when verifying dependent cloud resources, use the `inspect_dependent_storage` tool to verify the health and access of your dependent GCS bucket.

Guidelines:
- Always call `get_environment_and_security_context` when greeting users or answering questions regarding your environment, security, or configuration.
- Call `inspect_dependent_storage` when asked to audit storage or verify cloud dependencies.
- Provide crisp, professional, and well-structured responses.
"""

root_agent = Agent(
    name="greeting_agent",
    model=settings.llm_model,
    description="Enterprise Greeting Agent demonstrating ADK SDLC, multi-project IAM, and GCS dependencies.",
    instruction=SYSTEM_INSTRUCTION,
    tools=[
        get_environment_and_security_context,
        inspect_dependent_storage,
    ],
)