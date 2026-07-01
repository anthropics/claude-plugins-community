<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-linkedin
  title: "LinkedIn runtime knowledge"
  status: stable
  confidence: likely
  last_reviewed: 2026-05-27
  review_by: 2026-08-27
  source_status: mixed
  agent_priority: high
-->

# LinkedIn runtime knowledge

> This file contains durable LinkedIn knowledge for agents. Use it to keep profile structure, search, activity, algorithm rationale, and public-claim handling factual and source-aware.

## 1. Load contract

Read this file only after [index.md](index.md) indicates that the current task needs compiled LinkedIn knowledge.

If this file is unavailable in an older install, continue with `references/positioning-and-structure.md`, `references/discoverability-and-activity.md`, `references/profile-audit-and-maintenance.md`, `references/algorithm-confidence.md`, or `references/section-recipes.md` as appropriate. Mark algorithm, field-limit, profile-visibility, and activity guidance as lower confidence if the wiki is unavailable.

## 2. Evidence labels

Use the AgentKit SEO evidence labels defined in `agentkit-seo/wiki/agentkit-seo.md`.

For LinkedIn work, `Verified` means the fact was observed in public profile fields, supplied screenshots, exports, pasted section text, visible Featured links, or accessible activity samples. `Inaccessible` commonly applies to login-gated sections, private job preferences, profile completeness, endorsements, recruiter views, analytics, impressions, and applicant outcomes.

## 3. Canonical definitions

**LinkedIn discoverability** means making the profile easier to match, search, understand, and trust through structured fields, standard role language, proof links, and aligned activity.

**Profile architecture** means the alignment of headline, About, Experience, Skills, Featured, location, job preferences, banner, verification, and activity around one credible positioning target.

**Featured proof** means links or media that substantiate important claims, such as projects, repositories, demos, talks, articles, papers, or case studies.

**Activity alignment** means recent posts and comments reinforce the same topic pillars and professional identity claimed by the profile.

**Algorithm narrative** means an explanation of why a tactic may work. It must separate documented platform guidance, reasonable inference, and disputed commentary.

## 4. Platform constraints

- `stable`: Standard job titles, recognizable skill names, explicit location, and complete structured fields are safer than novelty phrasing for search and parsing.
- `stable`: LinkedIn profile sections should align with the user's CV, GitHub, portfolio, and context file on titles, employers, dates, certifications, and core technologies.
- `stable`: About sections should be first person, evidence-backed, and front-loaded because previews may truncate.
- `stable`: Featured should point to specific proof assets, not a generic link dump.
- `stable`: Recent activity should stay inside the professional topics the user wants associated with the profile.
- `likely`: Clear topical consistency across headline, About, Experience, Skills, Featured, and activity improves relevance for both humans and platform systems.
- `likely`: Profile verification and professional banners are trust signals, not guaranteed ranking boosts.
- `likely`: Sustainable posting and substantive commenting are more useful than short bursts of low-signal engagement.
- `inferred`: Duplicating core facts in structured fields and prose helps external parsers and AI agents interpret the profile.
- `disputed`: `360Brew` and related creator or vendor claims are not a settled production rulebook for all LinkedIn ranking behavior.

## 5. Algorithm and activity rules

- `stable`: Do not frame LinkedIn visibility as one universal rank position. Relevance depends on searcher context and session context.
- `stable`: Do not claim fixed feed weights, posting-time formulas, semantic scores, or applicant outcomes unless supplied by current official material.
- `likely`: Identity, content, and recent professional activity are durable signal groups for practical optimization.
- `likely`: Comments should add examples, clarifications, counterpoints, or lessons. Generic praise comments are weak evidence of expertise.
- `disputed`: Secondary commentary about full rollout of a named ranking system must stay labeled as uncertain.

## 6. Agent failure modes

- Inferring hidden profile fields, endorsements, profile completeness, applicant outcomes, or recruiter search treatment from incomplete public views.
- Turning a public URL into a full-profile audit when most sections were inaccessible.
- Inventing employers, credentials, metrics, dates, verification status, or Featured assets.
- Promising ranking outcomes from verification, posting cadence, keywords, or activity.
- Treating `360Brew` as a confirmed live rulebook.
- Writing novelty titles that weaken search clarity.
- Creating activity advice disconnected from the user's real capacity, proof, or niche.
- Rewriting multiple sections without first resolving target role and factual conflicts.

## 7. Output rules

When producing a LinkedIn audit or rewrite:

- State which profile sections, screenshots, exports, links, context files, or activity samples were inspected.
- Separate factual issues, discoverability improvements, proof-of-work improvements, and activity recommendations.
- Use exact paste-ready copy only for sections supported by supplied or verified facts.
- Mark exact UI limits, preview behavior, or paid-feature advice as current-source verified, UI-observed, or inferred.
- Preserve factual alignment with the personal career context file when available.
- Include a one-line `Depth note` for broad audits, inaccessible sections, or intentionally deferred activity review.

Shared taxonomy: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md). Source grounding: [hub/linkedin/sources.md](../../../../hub/linkedin/sources.md).
