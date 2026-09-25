Goal: build a clear and easy to use repo that explains how sdlc works for ADK agents. 

Success criteria:
* A thorough readme with key questions that helps a developer learn about GCP, GEAP-based, ADK-based SDLC faster.
* Clear and concise instructions
* Clear and concise Q&A about ADK SDLC
* A well organized readme with sections
* Readme opens with a brief summary of what the user will find in this repo and a list of shortcuts to the sections.
* The simple agent greets the user and prints which environment it's running on, the security context, and one more variable that was set in .env.

Guidance:
* The repo will be opinionated. There are lots of ways to do this. We will select a stack and explain that stack.
* Use an agent that is simple and requires a gcs bucket as a dependent resource. This will call for permissions, etc. This agent will be based on the greeting_agent already in the repo. 
* A simple eval set with 3 evaluations using ADK evaluations.


Stack components:
* Source control: GitHub
* Build and Deployment: Cloud Build. This is a simplified version.
* Environment variables: .env plus pydantic
* Project structure: Dev is local. Cloud has one for test, one for prod.
* The prod build-deploy requires manual approval. The test build-deploy is automatic.
* ADK version above 2.x
* Vertex AI authentication, no API keys.


Implementation Details:
* Three projects: <your-cloud-build-project-id>, <agent-test-project-id>, <agent-prod-project-id>
* The GitHub connection, repo, and triggers are in the <your-cloud-build-project-id> project.
* Create terraform to setup the three projects, permissions, and infrastructure that is not part of the release process. Shell scripts for everything else.


Questions addressed:
* How do I manage terraform across test and prod environments?
* How do I manage permissions across enviroments?
* How do I manage variables (.env and pydantic)
* How do I manage sensitive data in .env (use a .env.example, use .gitignore)
* How do I make my coding agent smarter about deployments? Use cli to create terraform and deployment scripts.
* How do I manage agents in production that are exposed to GE? Deploy using the same id.
* How do I run evals across environments?