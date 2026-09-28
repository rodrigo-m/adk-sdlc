"""Programmatic evaluation harness for greeting_agent.

This test harness executes evaluation cases from greeting_agent.evalset.json,
verifying tool trajectories, environment configuration, and security context.
Failures trigger non-zero exit codes (blocking CI/CD deployment pipelines).
"""

from __future__ import annotations

import json
from pathlib import Path
import pytest
from google.adk.runners import Runner
from google.adk.sessions.in_memory_session_service import InMemorySessionService
from google.genai import types

from greeting_agent.agent import root_agent
from greeting_agent.config import get_settings


EVAL_SET_PATH = Path(__file__).parent.parent / "greeting_agent" / "evals" / "greeting_agent.evalset.json"


def load_eval_cases():
    """Loads eval cases from standard ADK evalset JSON file."""
    with open(EVAL_SET_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    cases = data.get("eval_cases", [])
    return [(case["eval_id"], case) for case in cases]


@pytest.fixture(scope="session")
def agent_settings():
    """Initializes and returns settings fixture."""
    return get_settings()


@pytest.mark.asyncio
@pytest.mark.parametrize("eval_id,case_data", load_eval_cases())
async def test_eval_case_trajectory_and_assertions(eval_id: str, case_data: dict, agent_settings):
    """Executes a single ADK eval case and asserts tool trajectory and response semantics."""
    session_service = InMemorySessionService()
    session = await session_service.create_session(app_name="greeting_eval_harness", user_id="eval_user_ci")
    runner = Runner(agent=root_agent, app_name="greeting_eval_harness", session_service=session_service)

    turn = case_data["conversation"][0]
    user_prompt = turn["user_content"]["parts"][0]["text"]
    expected_tool_calls = [t["name"] for t in turn.get("expected_tool_calls", [])]

    actual_tool_calls = []
    final_responses = []

    async for event in runner.run_async(
        session_id=session.id,
        user_id="eval_user_ci",
        new_message=types.Content(
            role="user",
            parts=[types.Part.from_text(text=user_prompt)],
        ),
    ):
        if hasattr(event, "content") and event.content:
            for part in event.content.parts:
                if part.function_call:
                    actual_tool_calls.append(part.function_call.name)
                if part.text:
                    final_responses.append(part.text)

    full_response_text = " ".join(final_responses).lower()

    # 1. Trajectory Assertion: Expected tools must be called
    for expected_tool in expected_tool_calls:
        assert expected_tool in actual_tool_calls, (
            f"[{eval_id}] Trajectory failure: expected tool '{expected_tool}' was not invoked. "
            f"Actual calls: {actual_tool_calls}"
        )

    # 2. Granular Semantic & Context Assertions per eval_id
    if eval_id == "eval_01_environment_and_greeting":
        assert any(word in full_response_text for word in ["hello", "greet", "welcome"]), (
            f"[{eval_id}] Missing warm greeting in response: {full_response_text}"
        )
        assert agent_settings.environment.lower() in full_response_text, (
            f"[{eval_id}] Expected environment '{agent_settings.environment}' missing in response."
        )

    elif eval_id == "eval_02_security_context_inspection":
        assert any(kw in full_response_text for kw in ["security", "principal", "project", "caller", "service account"]), (
            f"[{eval_id}] Security context details missing in response: {full_response_text}"
        )

    elif eval_id == "eval_03_custom_env_variable":
        assert agent_settings.greeting_banner.lower() in full_response_text or "banner" in full_response_text, (
            f"[{eval_id}] Custom env variable banner missing in response: {full_response_text}"
        )

    elif eval_id == "eval_04_dependent_storage_audit":
        assert any(kw in full_response_text for kw in ["bucket", "storage", "audit", "connected"]), (
            f"[{eval_id}] Storage audit details missing in response: {full_response_text}"
        )

    elif eval_id == "eval_05_comprehensive_status_report":
        assert "get_environment_and_security_context" in actual_tool_calls, f"[{eval_id}] Missing env tool"
        assert "inspect_dependent_storage" in actual_tool_calls, f"[{eval_id}] Missing storage tool"
