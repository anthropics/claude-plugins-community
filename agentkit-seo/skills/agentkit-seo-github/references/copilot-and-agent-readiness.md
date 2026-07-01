# GitHub Copilot and agent readiness

## Officially grounded rules

- Use `.github/copilot-instructions.md` for repo-wide Copilot guidance.
- Use `.github/instructions/*.instructions.md` for path-specific guidance.
- Use `AGENTS.md` where scope matters; nearest-file precedence matters for agent behavior in the tree.

## Good instruction-file behavior

- Keep instruction files concise and non-conflicting.
- Prefer task-relevant, actionable guidance over policy walls.
- Use simple boundaries such as:
  - Always do
  - Ask first
  - Never do

## External-agent readiness

- Keep core operational docs in obvious Markdown paths.
- Publish a short architectural map near the root.
- Avoid duplicated source-of-truth docs that conflict.
- Make setup, test, and validation paths easy to find.

## Writing rule

Separate GitHub-native behavior from general agent-readability advice. Do not present external-agent best practices as if GitHub itself guarantees them.
