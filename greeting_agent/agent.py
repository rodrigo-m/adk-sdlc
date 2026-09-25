from google.adk import Agent

root_agent = Agent(
    name="greeting_agent",
    model="gemini-3.8-flash",
    instruction="You are a helpful assistant. Greet the user warmly",
)