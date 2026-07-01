<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-web-portfolio
  title: "Web portfolio wiki index"
  status: stable
  confidence: stable
  last_reviewed: 2026-05-27
  review_by: 2026-11-27
  source_status: repo
  agent_priority: high
-->

# Web portfolio wiki index

> This file maps the web portfolio wiki files to the tasks that need them. Load this index before reading web-portfolio wiki entries.

## 1. Load contract

Read this file when `agentkit-seo-web-portfolio/SKILL.md` routes a task to the local wiki.

If this file is unavailable in an older install, continue with the matching `references/` file and mark wiki-specific guidance as unavailable. Do not fail the task only because the wiki index is missing.

## 2. Wiki files

- [knowledge.md](knowledge.md): Compiled runtime knowledge for portfolio SEO, AI retrieval conventions, metadata alignment, evidence handling, and known agent failure modes.

## 3. Conditional loads

Read [knowledge.md](knowledge.md) when the task asks about any of these topics:

- `llms.txt`, `llms-full.txt`, AI retrieval, AEO, or LLM-readable portfolio content
- Metadata, canonical tags, Open Graph, X/Twitter card tags, or structured data where claims need confidence labels
- Indexability, crawler policy, sitemap, robots, JavaScript rendering, or rendered HTML constraints
- Portfolio page copy that depends on user facts, project ownership, metrics, testimonials, or professional positioning
- Audit output that must separate verified evidence from inference
- Known LLM failure modes for personal websites

Do not read [knowledge.md](knowledge.md) for narrow code-only edits that do not affect crawlability, metadata, structured data, public claims, or AI retrieval.

## 4. Eager loads

There are no eager wiki loads for this module. The web-portfolio skill should load wiki entries conditionally after it identifies the task surface.

## 5. Degraded mode

When a wiki file referenced here is missing:

- Continue with the relevant `references/` file.
- Avoid making stronger claims than the loaded reference supports.
- Add a short note only when the missing wiki would affect confidence, source status, or maintenance guidance.
- Do not ask the user to reinstall unless the missing file blocks a requested wiki-specific maintenance task.

Root wiki: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md).
