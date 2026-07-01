---
name: testdino-health
description: Use when the user wants to check TestDino connection status, validate their PAT, discover available organizations and projects, or find the right projectId. Always call this first when the project context is ambiguous before any other TestDino tool.
---

# TestDino Health

Use TestDino's `health` tool first when the user wants to:

- check whether TestDino is connected
- list available organizations or projects
- find the right `projectId`
- validate that their PAT is working

Guidance:

- Start with `health` before project-specific TestDino actions if `projectId` is unknown.
- Extract the correct organization and project from the response.
- Reuse the chosen `projectId` for the rest of the conversation.
- After `health`, ask the user which organization or project they want only if the correct target is still ambiguous.

What `health` confirms:

- PAT validation status
- connection status
- organization access
- project access
- available modules for each project
