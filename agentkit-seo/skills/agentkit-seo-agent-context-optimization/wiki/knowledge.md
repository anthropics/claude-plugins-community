<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-agent-context-optimization
  title: "Agent context optimization runtime knowledge"
  status: stable
  confidence: stable
  last_reviewed: 2026-05-27
  review_by: 2026-11-27
  source_status: repo
  agent_priority: high
-->

# Agent context optimization runtime knowledge

> This file contains durable agent-context knowledge for agents. Use it to keep personal source-of-truth files structured, private, factual, and maintainable.

## 1. Load contract

Read this file only after [index.md](index.md) indicates that the current task needs compiled agent-context knowledge.

If this file is unavailable in an older install, continue with `references/why-and-when.md`, `references/spec-and-structure.md`, `references/drafting-template.md`, `references/maintenance-and-validation.md`, or `references/operating-workflow.md` as appropriate. Mark source-of-truth and validation guidance as lower confidence if the wiki is unavailable.

## 2. Evidence labels

Use the AgentKit SEO evidence labels defined in `agentkit-seo/wiki/agentkit-seo.md`.

For context-file work, `From context` means a fact is already present in the existing personal career context file. Do not treat `From context` as verified against external evidence unless the source entry or inspected material supports it.

## 3. Canonical definitions

**Personal career context file** means a private Markdown source of truth for a person's professional facts and stated career direction, used to ground repeated CV, LinkedIn, GitHub, portfolio, and X/Twitter work.

**Agent context optimization** means building, normalizing, validating, and maintaining that file so downstream platform outputs reuse facts instead of inventing or re-asking for them.

**QUICK REFERENCE** means the selective YAML snapshot directly under the H1. It carries current positioning, target roles, top skills, tools, credentials, and public links for fast agent loading.

**Goals and targeting** means the stated-intent section that records ideal role, current focus, target roles, target locations, growth direction, interests, evidence boundaries, positioning constraints, and claims to avoid. It guides platform outputs but is not a verified-facts record.

**VERIFIED FACTS** means the HTML comment in the scope declaration that stores hard factual anchors such as dates, grades, scores, IDs, rankings, and other facts that must not be guessed.

**Semantic tags** mean stable bracketed labels such as `[DEGREE]`, `[COURSE]`, `[PROJECT]`, `[THESIS]`, `[ROLE]`, `[PAPER]`, `[PREPRINT]`, `[CERT]`, `[COMPETITION]`, `[AWARD]`, and `[ORG]`.

## 4. Structural constraints

- `stable`: The context file is one Markdown document with exactly one H1.
- `stable`: The H1 uses `# Full Name - positioning descriptor`.
- `stable`: `QUICK REFERENCE` appears immediately after the title and uses a fenced YAML block.
- `stable`: QUICK REFERENCE values should stay flat and selective; omit empty fields.
- `stable`: `Goals and targeting` appears after QUICK REFERENCE unless the user intentionally declines direction capture.
- `stable`: Goals, growth direction, emerging interests, evidence boundaries, positioning constraints, and claims to avoid are stated intent, not verified facts.
- `stable`: Required sections include scope declaration, education, skills index, and languages.
- `stable`: Conditional sections appear only when relevant material exists, including professional experience, research and publications, certifications and achievements, and extracurricular or leadership material.
- `stable`: The scope declaration closes with a `VERIFIED FACTS` HTML comment.
- `stable`: Skills in the skills index must be evidenced elsewhere in the file.
- `stable`: Languages should be represented as a table.
- `likely`: `~/.agentkit-seo/<name-surname>-seo-context.md` is a portable default path when the user wants a reusable file, but an explicit user path always wins.

## 5. Maintenance and validation rules

- `stable`: Update only when a real-world fact is verifiable.
- `stable`: Do not add speculative future roles, awards, certifications, or project outcomes.
- `stable`: Use future direction to select emphasis, not to invent evidence. Frame weakly evidenced direction as "building toward", "targeting", or "interested in" until a verified project, role, course, or artifact supports stronger wording.
- `stable`: Repair structure before polishing language when the file is structurally weak.
- `stable`: Preserve chronology, role titles, metrics, and project ownership across downstream outputs.
- `stable`: Surface conflicts instead of silently normalizing them.
- `stable`: Prefer targeted entry-level edits over whole-file rewrites.
- `likely`: Keep a version history, ideally in Git, when the file is maintained over time.
- `inferred`: Compress peripheral detail rather than deleting important evidence when token growth becomes a problem.

## 6. Agent failure modes

- Treating memory, pasted exports, or chat history as a stable source of truth instead of writing a maintained file.
- Searching the user's full filesystem for a context file without an explicit path or confirmed default.
- Writing outside the workspace without confirming the destination and provider permissions.
- Turning unsupported claims into polished public copy.
- Adding skills to QUICK REFERENCE or the skills index without evidence in the body.
- Converting target roles, growth direction, or emerging interests into claimed mature expertise.
- Omitting claims-to-avoid or evidence boundaries when a user is repositioning across fields.
- Reordering canonical sections for style reasons.
- Rewriting the whole context file when a targeted entry update would preserve history and reduce risk.
- Treating `From context` as externally verified when no evidence line or inspected source supports it.

## 7. Output rules

When producing a context-file audit, creation plan, or maintenance edit:

- State whether a context file exists, was created, or needs a confirmed path.
- Name the selected storage mode and path when writing is part of the task.
- Keep the source ledger grouped by input type or file.
- Separate normalized facts, conflicts, gaps, and claims needing evidence.
- Update `VERIFIED FACTS` when adding hard factual anchors.
- Hand off to exactly one platform skill after context cleanup unless the user asks for a multi-surface pass.
- Include a one-line `Depth note` when sources, sections, or cross-platform checks were intentionally bounded.

Shared taxonomy: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md). Source grounding: [hub/agent-context-optimization/sources.md](../../../../hub/agent-context-optimization/sources.md).
