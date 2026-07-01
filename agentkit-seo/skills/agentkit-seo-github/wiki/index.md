<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-github
  title: "GitHub wiki index"
  status: stable
  confidence: stable
  last_reviewed: 2026-05-27
  review_by: 2026-11-27
  source_status: repo
  agent_priority: high
-->

# GitHub wiki index

> This file maps the GitHub wiki files to the tasks that need them. Load this index before reading GitHub wiki entries.

## 1. Load contract

Read this file when `agentkit-seo-github/SKILL.md` routes a task to the local wiki.

If this file is unavailable in an older install, continue with the matching `references/` file and mark wiki-specific guidance as unavailable. Do not fail the task only because the wiki index is missing.

## 2. Wiki files

- [knowledge.md](knowledge.md): Compiled runtime knowledge for GitHub profile and repository discoverability, search constraints, Linguist handling, agent-readiness, evidence handling, and known agent failure modes.

## 3. Conditional loads

Read [knowledge.md](knowledge.md) when the task asks about any of these topics:

- GitHub profile audits, pinned repository selection, profile README positioning, or repository packaging
- Repository About text, topic tags, social previews, README structure, trust files, or proof-of-work signals
- GitHub searchability, default branches, archived repositories, forks, file-size limits, or code-search constraints
- Linguist language stats, `.gitattributes`, vendored/generated files, or language-bar corrections
- `AGENTS.md`, Copilot instructions, AI-readable repository structure, or external-agent readiness
- Audit output that must separate verified GitHub evidence from supplied context or inference
- Known LLM failure modes for GitHub profiles and repositories

Do not read [knowledge.md](knowledge.md) for narrow copy edits that do not depend on GitHub constraints, searchability, repository structure, agent-readiness, or confidence labeling.

## 4. Eager loads

There are no eager wiki loads for this module. The GitHub skill should load wiki entries conditionally after it identifies the task surface.

## 5. Degraded mode

When a wiki file referenced here is missing:

- Continue with the relevant `references/` file.
- Avoid making stronger claims than the loaded reference supports.
- Add a short note only when the missing wiki would affect confidence, source status, or maintenance guidance.
- Do not ask the user to reinstall unless the missing file blocks a requested wiki-specific maintenance task.

Root wiki: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md).
