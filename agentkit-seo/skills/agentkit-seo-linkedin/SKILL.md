---
name: agentkit-seo-linkedin
description: Optimize LinkedIn profile structure and discoverability for headline, about, featured, experience, skills, and AI-readable positioning. Use when the user asks to improve a LinkedIn profile, headline, about section, featured section, experience entry, skills list, creator visibility, or LinkedIn search and feed discoverability.
license: MIT
metadata:
  homepage: https://agentkit-seo.github.io/
  repository: https://github.com/agentkit-seo/agentkit-seo
---

# AgentKit SEO LinkedIn

## Overview

Work through the lens of a technical recruiter and the user's career editor. Use only the LinkedIn module unless the user explicitly asks for cross-platform alignment. Keep claims conservative, search-oriented, and easy to justify.

## Reference selection

- Headline, About, Experience, Skills, Featured, profile architecture: [references/positioning-and-structure.md](references/positioning-and-structure.md)
- Ready-to-paste section rewrites: [references/section-recipes.md](references/section-recipes.md)
- Search visibility, activity, comments, AI readability: [references/discoverability-and-activity.md](references/discoverability-and-activity.md)
- Full-profile review, consistency checks, update workflow: [references/profile-audit-and-maintenance.md](references/profile-audit-and-maintenance.md)
- Algorithm rationale, confidence labels, `360Brew`: [references/algorithm-confidence.md](references/algorithm-confidence.md)
- Audit scorecard and prioritized fix-first ranking: [references/audit-scoring.md](references/audit-scoring.md)

## Wiki context

- Read [wiki/index.md](wiki/index.md) when the task asks about LinkedIn search visibility, profile architecture constraints, activity strategy, algorithm explanations, `360Brew`, confidence labels, known agent failure modes, or full audit source discipline.
- Read [wiki/knowledge.md](wiki/knowledge.md) only after [wiki/index.md](wiki/index.md) routes the current task there.
- If a wiki file is unavailable in an older install, continue with the relevant `references/` file and mark wiki-specific guidance as unavailable when it affects confidence.

## Token discipline

- Do not request or process the whole LinkedIn profile for a single section rewrite if the section and target role are enough.
- For full optimization, ask for a profile text export or compact section dump before screenshots, because text is cheaper and easier to ground.
- Read algorithm-confidence material only when explaining why a tactic works.
- Prefer supplied section text, public fields, Featured links, and a small recent-activity sample before asking for screenshots or exports.
- Keep source ledgers compact: list input groups, not every minor profile element.
- Name next inspection if bounded.

## Depth contract

Use the smallest honest audit depth:

- `Quick scan`: headline, About opening, current role, Featured/link path, and obvious positioning gaps.
- `Default audit`: quick scan plus Experience summary, Skills/top proof, Featured items, and up to 5 recent activity items when available.
- `Deep audit`: full profile export, all Experience entries, Skills ordering, Featured assets, longer activity history, screenshots, and cross-platform consistency.

Default to `Default audit` for broad LinkedIn profile requests. Offer `Deep audit` as an optional next step when the current answer would benefit from more evidence. Do not choose `Deep audit` silently unless the user asks for full optimization, every section, exact profile rewrite, or cross-platform reconciliation.

## Intake workflow

- Assume most LinkedIn profile details are login-gated or incomplete from a public URL alone.
- If the user gives a LinkedIn URL, use only public information that tools can access, then ask for pasted section text, screenshots, an export, or a local text file for the full profile.
- For full optimization, request a compact profile text dump if available. Otherwise ask only for the missing sections needed for the next pass, such as headline, About, Featured items, Experience entries, Skills, target roles, target geography, or proof links.
- If the user's facts are scattered or the task affects multiple profile sections, recommend creating or updating the personal career context file before rewriting.
- If the user supplies a context file, use it as the factual source of truth and treat LinkedIn copy as a channel-specific adaptation.
- Do not infer private metrics, endorsements, applicant outcomes, or hidden profile fields from public visibility.

## Rules

- Treat disputed `360Brew` rollout claims as disputed, not as settled production truth.
- Separate facts verified on LinkedIn or supplied files, facts supplied by the user's context material, and recommendations inferred from those facts.
- Do not invent credentials, metrics, or employers.
- Do not infer private metrics, profile completeness, endorsements, recruiter search treatment, or applicant outcomes from incomplete public views.
- Keep profile text searchable, human-readable, and aligned with the user's actual positioning.
- If the user asks for full profile optimization, recommend or use the `agentkit-seo-agent-context-optimization` skill first when facts are messy.
- Prefer standard job titles and explicit skills over novelty phrasing.
- Use career direction to choose headline, About, Featured, Skills, and Experience emphasis, but frame emerging directions as building toward, targeting, or interested in until the context file supplies stronger evidence.
- Honor context-file evidence boundaries, positioning constraints, and claims to avoid when the user is repositioning across domains.
- Keep structured profile fields, prose sections, proof links, and recent activity aligned around the same positioning.
- For section rewrites, preserve factual claims and improve only structure, clarity, and discoverability unless the user asks for strategic repositioning.

## Self-review

Before returning, check the draft and fix or flag any failure:

- No invented credentials, metrics, or employers; every claim traces to LinkedIn material, the context file, or is labeled inference, with disputed ranking behavior kept disputed.
- Evidence and confidence labels are correct and not upgraded beyond their source.
- Output matches the requested scope, the target role, and the user's stated goals and target locations; nothing drifted into unrequested work.
- Rewrites preserve the user's real facts and lead with the highest-impact changes.

If a check fails and cannot be fixed from available inputs, say so rather than papering over it.

## Response shape

Return only requested-relevant sections. For audits, return:

1. profile inputs used and missing sections
2. positioning diagnosis
3. ready-to-paste LinkedIn section copy or ordered edits
4. keyword and proof alignment notes
5. requests for the smallest missing inputs needed to finish the next pass

For audits, use concise labels such as `Verified`, `From context`, `Official guidance`, `Inference`, and `Inaccessible` when a claim could otherwise be ambiguous. Include a `Depth note` only for broad audits, incomplete inputs, or intentionally deferred profile/activity review.
When the user asks for a score, scorecard, or before/after comparison, also apply [references/audit-scoring.md](references/audit-scoring.md): report the overall score, band, per-category breakdown, and a fix-first ranking, labeled as an internal prioritization heuristic rather than a LinkedIn ranking.

Human playbook: [hub/linkedin/README.md](../../../hub/linkedin/README.md).
