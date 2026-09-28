#!/usr/bin/env python3
"""Performs post-deployment smoke testing on the deployed Vertex AI Reasoning Engine / Agent Engine."""

from __future__ import annotations

import argparse
import json
import sys
from google.api_core.client_options import ClientOptions
from google.cloud.aiplatform_v1beta1.services.reasoning_engine_execution_service import (
    ReasoningEngineExecutionServiceClient,
)
from google.protobuf import struct_pb2


def verify_agent(project: str, region: str, agent_id: str) -> bool:
    """Verifies that the deployed agent responds to an operational prompt."""
    print(f"Connecting to Agent Engine '{agent_id}' in project '{project}' ({region})...")
    
    endpoint = f"{region}-aiplatform.googleapis.com"
    client_options = ClientOptions(api_endpoint=endpoint)
    client = ReasoningEngineExecutionServiceClient(client_options=client_options)

    if agent_id.startswith("projects/"):
        resource_name = agent_id
    else:
        resource_name = f"projects/{project}/locations/{region}/reasoningEngines/{agent_id}"

    test_prompt = "Hello! Please report your environment, security context, and status."
    print(f"Sending verification prompt to {resource_name}...")

    input_struct = struct_pb2.Struct()
    input_struct.update({
        "message": test_prompt,
        "user_id": "sdlc_post_deploy_verifier",
    })

    try:
        stream = client.stream_query_reasoning_engine(
            request={
                "name": resource_name,
                "input": input_struct,
                "class_method": "stream_query",
            }
        )
        
        full_response_text = []
        for chunk in stream:
            data_str = chunk.data.decode("utf-8")
            try:
                data_json = json.loads(data_str)
                parts = data_json.get("content", {}).get("parts", [])
                for part in parts:
                    if "text" in part:
                        full_response_text.append(part["text"])
                    elif "function_call" in part:
                        print(f"  [Tool Invocation] {part['function_call'].get('name')}")
            except Exception:
                full_response_text.append(data_str)

        response_summary = "".join(full_response_text).strip()
        print("\nAgent Response:")
        print("-----------------------------------------------------------------")
        print(response_summary)
        print("-----------------------------------------------------------------")
        
        if response_summary:
            print("Post-deployment verification PASSED.")
            return True
        else:
            print("Warning: Received empty text response from agent.", file=sys.stderr)
            return False

    except Exception as exc:
        print(f"Verification FAILED: {exc}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(description="Verify deployed Reasoning Engine.")
    parser.add_argument("--project", required=True, help="GCP Project ID")
    parser.add_argument("--region", default="us-central1", help="GCP Region")
    parser.add_argument("--agent_id", required=True, help="Reasoning Engine ID or resource name")
    args = parser.parse_args()

    success = verify_agent(args.project, args.region, args.agent_id)
    if not success:
        sys.exit(1)


if __name__ == "__main__":
    main()
