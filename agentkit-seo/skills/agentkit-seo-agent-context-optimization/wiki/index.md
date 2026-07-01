<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-agent-context-optimization
  title: "Agent context optimization wiki index"
  status: stable
  confidence: stable
  last_reviewed: 2026-05-27
  review_by: 2026-11-27
  source_status: repo
  agent_priority: high
-->

# Agent context optimization wiki index

> This file maps the agent-context wiki files to the tasks that need them. Load this index before reading agent-context wiki entries.

## 1. Load contract

Read this file when `agentkit-seo-agent-context-optimization/SKILL.md` routes a task to the local wiki.

If this file is unavailable in an older install, continue with the matching `references/` file and mark wiki-specific guidance as unavailable. Do not fail the task only because the wiki index is missing.

## 2. Wiki files

- [knowledge.md](knowledge.md): Compiled runtime knowledge for personal career context file structure, source-of-truth behavior, maintenance, validation, evidence handling, and known agent failure modes.

## 3. Conditional loads

Read [knowledge.md](knowledge.md) when the task asks about any of these topics:

- What a personal career context file is, when to create one, where to store it, or how it relates to platform skills
- Context-file structure, `QUICK REFERENCE`, canonical section order, semantic tags, or `VERIFIED FACTS`
- Maintenance, validation, chronology checks, source ledgers, or targeted updates
- Cross-platform fact conflicts, unsupported claims, or downstream public-output grounding
- Audit output that must separate existing context facts, supplied sources, inference, and needs-evidence claims
- Known LLM failure modes for context-file creation and maintenance

Do not read [knowledge.md](knowledge.md) for a single downstream platform rewrite when the context file is already clean and the platform skill has enough facts.

## 4. Eager loads

There are no eager wiki loads for this module. The agent-context skill should load wiki entries conditionally after it identifies the task surface.

## 5. Degraded mode

When a wiki file referenced here is missing:

- Continue with the relevant `references/` file.
- Avoid making stronger claims than the loaded reference supports.
- Add a short note only when the missing wiki would affect confidence, source status, or maintenance guidance.
- Do not ask the user to reinstall unless the missing file blocks a requested wiki-specific maintenance task.

Root wiki: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md).
