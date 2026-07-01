# Personal career context file operating workflow

## Session workflow

1. load the personal career context file first
2. state the task and hard constraints
3. load the matching platform skill only if needed
4. review the output against factual grounding
5. revise the personal career context file if the task exposed missing or conflicting facts

## File discovery convention

Prefer an explicit path supplied by the user. Good options include:

```text
Use the personal career context file at ~/career/name-surname-seo-context.md.
Create a draft in this workspace at ./name-surname-seo-context.md.
```

If the user wants a portable default, suggest:

```text
~/.agentkit-seo/<name-surname>-seo-context.md
```

The generic fallback `~/.agentkit-seo/context.md` is acceptable only when the user prefers it.

Do not search the user's full filesystem for a context file. If no explicit path or confirmed default exists, ask for the path before using this skill.

Do not assume the agent can write outside the current workspace. Before creating or overwriting a file, confirm the destination and respect the provider's permission model.

## Source ingestion scope

For default passes, use explicit inputs only: one existing context file, one CV or resume, one profile export, and at most 3 public links. Expand beyond that only when the user asks for full consolidation or confirms a deeper reconciliation pass.

For large files, avoid dumping the full context file into chat by default. Prefer one of these outputs:

1. write the file to a confirmed path
2. return a concise outline plus gaps to fill
3. return a targeted diff or patch for an existing file
4. emit the full Markdown draft section by section only after the user asks for it

## Combination rule

The personal career context file supplies facts.

The goals and targeting section supplies direction, priorities, and constraints.

The platform skill supplies formatting, discoverability, and channel-specific constraints.

Do not let the platform skill become the factual source of truth.

When tailoring output, use verified evidence as the foundation, future direction as the positioning target, and constraints or claims-to-avoid as guardrails. Do not turn a growth direction into a claimed credential, completed project, employer responsibility, or mature expertise unless the context file supplies evidence.

## Maintenance rules

- update only when a fact is real and verifiable
- do not add speculative future items to verified record sections
- record aspirations, target roles, growth direction, and claims to avoid in `Goals and targeting`
- when adding new content, also update the `VERIFIED FACTS` anchor if relevant
- keep a version history, ideally in Git
- when a file is structurally weak, repair canonical structure before downstream rewriting

## Token management

- keep the `QUICK REFERENCE` block current and selective
- preserve the full historical record in the body
- compress peripheral detail rather than deleting important evidence
- keep source ledgers grouped and short; do not list every tiny note unless it affects a conflict or hard factual claim

## Agent editing rule

When integrating new material, add or revise only the relevant entry and avoid gratuitous rewrites of unrelated sections.
