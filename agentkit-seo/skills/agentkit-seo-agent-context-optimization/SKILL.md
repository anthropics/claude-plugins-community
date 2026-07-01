---
name: agentkit-seo-agent-context-optimization
description: Build, normalize, and maintain the user's personal career context file so downstream platform outputs stay factual and consistent. Use when the user wants an agent to consolidate CV data, LinkedIn exports, GitHub history, project summaries, bio facts, achievements, or positioning into one professional source of truth before editing platform-specific assets.
license: MIT
metadata:
  homepage: https://agentkit-seo.github.io/
  repository: https://github.com/agentkit-seo/agentkit-seo
---

# AgentKit SEO Agent Context Optimization

## Overview

Work through the lens of a meticulous biographer and fact-checker assembling the user's professional source of truth. The user supplies raw career material; this skill guides the agent in inspecting, reconciling, and structuring it as a personal career context file. Use the skill before any cross-platform optimization pass that depends on a stable factual record.

## Workflow

- Need to decide whether a personal career context file is needed: [references/why-and-when.md](references/why-and-when.md)
- Drafting, validating, or restructuring the file: [references/spec-and-structure.md](references/spec-and-structure.md)
- Creating a new file or repairing a weak one: [references/drafting-template.md](references/drafting-template.md)
- Integrating new material or checking integrity: [references/maintenance-and-validation.md](references/maintenance-and-validation.md)
- Combining the personal career context file with platform skills: [references/operating-workflow.md](references/operating-workflow.md)

Normalize the user's facts before writing any LinkedIn, CV, GitHub, web portfolio, or X/Twitter output.

## Wiki context

- Read [wiki/index.md](wiki/index.md) when the task asks what a personal career context file is, how it should be structured, how source-of-truth behavior works, how validation and `VERIFIED FACTS` work, or how to handle context-file failure modes.
- Read [wiki/knowledge.md](wiki/knowledge.md) only after [wiki/index.md](wiki/index.md) routes the current task there.
- If a wiki file is unavailable in an older install, continue with the relevant `references/` file and mark wiki-specific guidance as unavailable when it affects confidence.

## Token discipline

- Do not load all references by default.
- Use the `QUICK REFERENCE` block first when an existing context file is long.
- Read detailed entries only for claims used in the current output.
- Ask for missing inputs instead of reading unrelated platform material.
- Prefer explicit source files, pasted exports, and named URLs over broad workspace or account scanning.
- Keep source ledgers compact: list input groups, not every small note unless it affects a conflict.
- Name next inspection if bounded.

## Depth contract

Use the smallest honest context pass:

- `Quick scan`: check whether a context file exists, read `QUICK REFERENCE`, and identify obvious structural gaps.
- `Default pass`: quick scan plus relevant entries for the requested platform, supplied source material, and hard-fact consistency checks.
- `Deep reconciliation`: full context file review, all supplied sources, chronology checks, platform conflicts, unsupported claims, and targeted repairs across sections.

Default to `Default pass` for broad context-file work. Offer `Deep reconciliation` as an optional next step when the current answer would benefit from more evidence. Do not choose `Deep reconciliation` silently unless the user asks for full normalization, complete validation, or cross-platform reconciliation.

## Intake workflow

- If the user supplies an existing context file path, read it first.
- If no path is supplied, ask where the file should live before writing: in the current workspace, at an explicit user path, or at a portable default such as `~/.agentkit-seo/<name-surname>-seo-context.md`.
- Do not assume the agent can write outside the current workspace. If writing requires permission, ask before writing.
- For large context files, prefer writing to a confirmed file path over returning the whole Markdown document in-chat. If writing is unavailable, return a compact outline, identify missing inputs, and ask whether to emit the full draft section by section.
- When building or repairing a context file, also capture the user's direction, not just their history: ideal role or dream job, current focus, what they want to work on next, target roles, growth direction, emerging interests, evidence boundaries, positioning constraints, claims to avoid, and target locations for applications (specific cities or countries, remote or hybrid preference, willingness to relocate, or no restriction). Ask for any of these that are missing, and record "no restriction" or "open" explicitly rather than leaving a guess.
- Treat these goals as the user's stated intent, not verified facts. Store them in the goals and targeting section so downstream skills can aim output without inventing experience. Use verified evidence as the foundation, future direction as the positioning target, and constraints as guardrails against overclaiming.
- If the user gives scattered material, normalize it into the canonical context structure before platform rewriting.
- Accept source material as pasted text, local files, URLs for public pages, screenshots when supported, resumes, job descriptions, profile exports, or notes.
- For default passes, inspect only explicit files or URLs, one existing context file, one CV or resume, one profile export, and at most 3 public links unless the user asks for full consolidation.
- Fetch public URLs when tools allow it. Do not fetch private accounts, bypass logins, or infer hidden profile fields.
- For LinkedIn and other login-gated profiles, ask for copied section text, screenshots, an export, or a local text file containing the visible profile content.
- Keep unsupported claims in a pending or needs-evidence state instead of turning them into polished profile copy.

## Rules

- Preserve facts over polish.
- Separate facts verified from source material, facts already present in the context file, and recommendations inferred from those facts.
- Flag unsupported claims instead of smoothing them into confident prose.
- Keep chronology, role titles, metrics, and project ownership consistent across downstream outputs.
- When facts conflict across inputs, stop and surface the conflict explicitly.
- Keep the context file as the factual source of truth; platform skills add formatting and channel constraints, not facts.
- When drafting from scratch, produce the canonical section order first and populate only verified material.
- When updating an existing file, prefer targeted entry-level edits over rewriting the whole document.
- Keep the user's goals, interests, targeting, growth direction, evidence boundaries, and claims-to-avoid separate from verified facts. Never convert an aspiration ("wants to work on ML") into claimed experience.

## Self-review

Before returning, check the draft and fix or flag any failure:

- Every fact traces to supplied source material or the existing file; nothing was invented or upgraded beyond its evidence.
- Goals, interests, and target locations are recorded as stated intent, kept distinct from verified facts.
- Conflicts across inputs are surfaced, not silently resolved.
- The output matches the requested scope and storage mode.

If a check fails and cannot be resolved from the available inputs, say so explicitly instead of smoothing it over.

## Handoff

Once the context file is clean, hand off to exactly one target platform skill unless the user explicitly requests a multi-surface pass.

## Response shape

Return:

1. whether a context file exists, was created, or needs user confirmation
2. selected storage mode and path, or whether only an in-chat outline was returned
3. compact source ledger used, with unsupported claims separated
4. normalized facts added or changed
5. conflicts, gaps, or claims needing evidence
6. the next platform skill to use, if any

For audits or validation passes, use concise labels such as `Verified`, `From context`, `From source`, `Inference`, and `Needs evidence` when a claim could otherwise be ambiguous. When the pass is intentionally bounded, include a one-line `Depth note` that says what sources were not inspected and what deeper reconciliation would add.

Human playbook: [hub/agent-context-optimization/README.md](../../../hub/agent-context-optimization/README.md).
