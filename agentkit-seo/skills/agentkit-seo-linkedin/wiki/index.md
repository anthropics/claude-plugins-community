<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-linkedin
  title: "LinkedIn wiki index"
  status: stable
  confidence: stable
  last_reviewed: 2026-05-27
  review_by: 2026-11-27
  source_status: repo
  agent_priority: high
-->

# LinkedIn wiki index

> This file maps the LinkedIn wiki files to the tasks that need them. Load this index before reading LinkedIn wiki entries.

## 1. Load contract

Read this file when `agentkit-seo-linkedin/SKILL.md` routes a task to the local wiki.

If this file is unavailable in an older install, continue with the matching `references/` file and mark wiki-specific guidance as unavailable. Do not fail the task only because the wiki index is missing.

## 2. Wiki files

- [knowledge.md](knowledge.md): Compiled runtime knowledge for LinkedIn profile structure, search visibility, activity, algorithm-confidence boundaries, evidence handling, and known agent failure modes.

## 3. Conditional loads

Read [knowledge.md](knowledge.md) when the task asks about any of these topics:

- Full LinkedIn profile audits, profile architecture, headline, About, Experience, Skills, Featured, or proof alignment
- LinkedIn search visibility, recruiter readability, activity strategy, comments, or topical consistency
- Algorithm explanations, `360Brew`, creator claims, or current-source confidence
- Login-gated public-profile limits, inaccessible fields, endorsements, private metrics, or applicant outcomes
- Audit output that must separate profile evidence from supplied context or inference
- Known LLM failure modes for LinkedIn profiles and activity

Do not read [knowledge.md](knowledge.md) for narrow section rewrites when the supplied section, target role, and proof are enough.

## 4. Eager loads

There are no eager wiki loads for this module. The LinkedIn skill should load wiki entries conditionally after it identifies the task surface.

## 5. Degraded mode

When a wiki file referenced here is missing:

- Continue with the relevant `references/` file.
- Avoid making stronger claims than the loaded reference supports.
- Add a short note only when the missing wiki would affect confidence, source status, or maintenance guidance.
- Do not ask the user to reinstall unless the missing file blocks a requested wiki-specific maintenance task.

Root wiki: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md).
