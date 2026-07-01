<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-cv-ats
  title: "CV ATS wiki index"
  status: stable
  confidence: stable
  last_reviewed: 2026-05-27
  review_by: 2026-11-27
  source_status: repo
  agent_priority: high
-->

# CV ATS wiki index

> This file maps the CV ATS wiki files to the tasks that need them. Load this index before reading CV ATS wiki entries.

## 1. Load contract

Read this file when `agentkit-seo-cv-ats/SKILL.md` routes a task to the local wiki.

If this file is unavailable in an older install, continue with the matching `references/` file and mark wiki-specific guidance as unavailable. Do not fail the task only because the wiki index is missing.

## 2. Wiki files

- [knowledge.md](knowledge.md): Compiled runtime knowledge for ATS-safe CV structure, parser risks, tailoring, job-description alignment, evidence handling, and known agent failure modes.

## 3. Conditional loads

Read [knowledge.md](knowledge.md) when the task asks about any of these topics:

- Full CV or resume audits, ATS safety reviews, parser debugging, or plain-text extraction checks
- Layout, section order, file type, typography, contact block, dates, URLs, or LaTeX PDF QA
- Job-description tailoring, keyword integration, bullet rewrites, or role-specific summaries
- Fact consistency across CV, context file, LinkedIn, GitHub, portfolio, or public proof
- Audit output that must separate CV evidence, job-description requirements, supplied context, and inference
- Known LLM failure modes for CV and ATS work

Do not read [knowledge.md](knowledge.md) for a narrow bullet rewrite when the supplied bullet, target role, and supporting facts are enough.

## 4. Eager loads

There are no eager wiki loads for this module. The CV ATS skill should load wiki entries conditionally after it identifies the task surface.

## 5. Degraded mode

When a wiki file referenced here is missing:

- Continue with the relevant `references/` file.
- Avoid making stronger claims than the loaded reference supports.
- Add a short note only when the missing wiki would affect confidence, source status, or maintenance guidance.
- Do not ask the user to reinstall unless the missing file blocks a requested wiki-specific maintenance task.

Root wiki: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md).
