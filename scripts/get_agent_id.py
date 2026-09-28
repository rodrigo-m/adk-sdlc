#!/usr/bin/env python3
"""Queries Vertex AI Reasoning Engine / Agent Engine resource ID for in-place updates."""

from __future__ import annotations

import argparse
import sys
import vertexai
from vertexai.preview import reasoning_engines


def get_agent_id(project: str, location: str, display_name: str) -> str:
    """Finds existing Reasoning Engine resource ID by display_name."""
    try:
        vertexai.init(project=project, location=location)
        engines = list(reasoning_engines.ReasoningEngine.list())
        for engine in engines:
            if getattr(engine, "display_name", "") == display_name:
                return engine.resource_name.split("/")[-1]
    except Exception as exc:
        print(f"Warning: error listing ReasoningEngines: {exc}", file=sys.stderr)
    return ""


def main():
    parser = argparse.ArgumentParser(description="Find existing Agent Engine ID.")
    parser.add_argument("--project", required=True, help="GCP Project ID")
    parser.add_argument("--region", default="us-central1", help="GCP Region")
    parser.add_argument("--display_name", default="greeting_agent", help="Agent display name")
    args = parser.parse_args()

    agent_id = get_agent_id(args.project, args.region, args.display_name)
    if agent_id:
        print(agent_id)


if __name__ == "__main__":
    main()
