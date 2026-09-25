# ADK Agent SDLC

A practical, opinionated reference repository demonstrating a complete Software Development Life Cycle (SDLC) for autonomous agents built with the Google **Agent Development Kit (ADK)**.

---

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Architecture & Stack](#architecture--stack)
  - [Agent Example Rationale](documentation/agent-example-rationale.md)
- [Testing & Evaluation](#testing--evaluation)
  - [Evaluation Harness Rationale](documentation/eval-harness-rationale.md)
- [Frequently Asked Questions (Q&A)](#frequently-asked-questions-qa)
- [Getting Started](#getting-started)

---

## Overview

This repository provides an end-to-end blueprint for developing, evaluating, and deploying ADK agents across distinct environments (development, test, and production). It emphasizes standard software engineering practices—including automated CI/CD gating, deterministic evaluation test suites, configuration management via environment variables and Pydantic, and infrastructure-as-code.

---

## Repository Structure

```text
adk-sdlc/
├── documentation/
│   ├── agent-example-rationale.md  # Architectural rationale for the reconciliation_agent
│   └── eval-harness-rationale.md   # Architectural rationale for the CI evaluation harness
├── greeting_agent/
│   ├── agent.py                    # Root ADK agent definition and tools
│   ├── requirements.txt            # Python dependencies
│   └── learning-goals.md           # Project scope and SDLC objectives
├── README.md                       # Main repository guide
```

---

## Testing & Evaluation

Evaluating agents in an automated CI/CD pipeline requires reliable, reproducible test runs that can block faulty pull requests and prevent regressions from shipping to downstream environments.

- **ADK Evaluation Format**: Test datasets are authored and stored using standard ADK evaluation sets (`*.evalset.json`), allowing test cases to be maintained in a clean, declarative schema.
- **Programmatic Test Harness**: Rather than invoking interactive CLI commands directly in CI pipelines, automated testing is executed via a programmatic test harness.

👉 **Deep Dive:** For a detailed breakdown of why an automated test harness is used in CI instead of raw CLI commands, read the [Evaluation Harness Rationale](documentation/eval-harness-rationale.md).

---

## Frequently Asked Questions (Q&A)

### How do we run evaluations across environments in CI/CD?
Evaluations are run hermetically as quality gates before deployment using the programmatic test harness. Test cases are authored in standard ADK format, while the harness guarantees deterministic non-zero exit codes on failure and outputs JUnit XML reports for pipeline visibility. See [Evaluation Harness Rationale](documentation/eval-harness-rationale.md) for details.

### How are environment variables and sensitive configuration managed?
Environment variables are managed using `.env` files paired with Pydantic settings models for schema validation. Sensitive values are excluded from source control using `.gitignore`, and a documented `.env.example` file provides placeholder values for onboarding.

### How do we manage permissions across environments?
Infrastructure and permissions are declared using Terraform, separating shared foundation resources from environment-specific deployments (test and prod).

---

## Getting Started

1. **Clone the repository and enter the directory:**
   ```bash
   git clone <repo-url>
   cd adk-sdlc
   ```

2. **Set up a Python virtual environment:**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r greeting_agent/requirements.txt
   ```

3. **Explore documentation:**
   Review [documentation/eval-harness-rationale.md](documentation/eval-harness-rationale.md) to understand the automated evaluation architecture.
