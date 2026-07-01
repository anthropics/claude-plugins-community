<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-x-twitter
  title: "X Twitter wiki index"
  status: stable
  confidence: stable
  last_reviewed: 2026-05-27
  review_by: 2026-11-27
  source_status: repo
  agent_priority: high
-->

# X Twitter wiki index

> This file maps the X/Twitter wiki files to the tasks that need them. Load this index before reading X/Twitter wiki entries.

## 1. Load contract

Read this file when `agentkit-seo-x-twitter/SKILL.md` routes a task to the local wiki.

If this file is unavailable in an older install, continue with the matching `references/` file and mark wiki-specific guidance as unavailable. Do not fail the task only because the wiki index is missing.

## 2. Wiki files

- [knowledge.md](knowledge.md): Compiled runtime knowledge for X/Twitter profile positioning, post structure, ranking-confidence boundaries, Premium guidance, evidence handling, and known agent failure modes.

## 3. Conditional loads

Read [knowledge.md](knowledge.md) when the task asks about any of these topics:

- Full account audits, profile positioning, bio rewrites, pinned posts, highlights, link paths, or proof alignment
- Posting structure, threads, Alt Text, media, external-link handling, or recent-post review
- Ranking explanations, Phoenix, Grok, historical open-source recommendation signals, or empirical tactics
- Premium, paid tiers, reply prioritization, long-form posts, media limits, monetization, or capability-specific advice
- Audit output that must separate public account evidence from supplied context, official features, empirical tactics, or inference
- Known LLM failure modes for X/Twitter profiles and posting systems

Do not read [knowledge.md](knowledge.md) for a narrow bio or post rewrite when the supplied copy, target audience, and proof are enough.

## 4. Eager loads

There are no eager wiki loads for this module. The X/Twitter skill should load wiki entries conditionally after it identifies the task surface.

## 5. Degraded mode

When a wiki file referenced here is missing:

- Continue with the relevant `references/` file.
- Avoid making stronger claims than the loaded reference supports.
- Add a short note only when the missing wiki would affect confidence, source status, or maintenance guidance.
- Do not ask the user to reinstall unless the missing file blocks a requested wiki-specific maintenance task.

Root wiki: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md).
