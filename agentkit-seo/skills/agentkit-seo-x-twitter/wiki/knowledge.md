<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-x-twitter
  title: "X Twitter runtime knowledge"
  status: stable
  confidence: likely
  last_reviewed: 2026-05-27
  review_by: 2026-08-27
  source_status: mixed
  agent_priority: high
-->

# X Twitter runtime knowledge

> This file contains durable X/Twitter knowledge for agents. Use it to keep profile, post, engagement, Premium, and ranking-confidence advice conservative and source-aware.

## 1. Load contract

Read this file only after [index.md](index.md) indicates that the current task needs compiled X/Twitter knowledge.

If this file is unavailable in an older install, continue with `references/profile-and-posts.md`, `references/engagement-and-ranking.md`, `references/premium-and-confidence.md`, `references/account-audit-and-maintenance.md`, or `references/section-recipes.md` as appropriate. Mark ranking, Premium, paid-feature, and confidence-label guidance as lower confidence if the wiki is unavailable.

## 2. Evidence labels

Use the AgentKit SEO evidence labels defined in `agentkit-seo/wiki/agentkit-seo.md`.

For X/Twitter work, `Verified` means the fact was observed in public account fields, visible posts, pinned posts, accessible media, supplied screenshots, analytics summaries, exports, pasted text, or inspected proof links. `Inaccessible` commonly applies to private analytics, Premium status unless visible or supplied, hidden ranking treatment, shadowban claims, paid tools, monetization, and account settings.

## 3. Canonical definitions

**X/Twitter profile positioning** means making display name, handle, bio, profile image, header, link, pinned asset, and recent content communicate one credible niche or professional identity.

**Pinned asset** means the post or curated profile item that acts as the account's strongest evergreen proof or conversion path.

**Native value** means a post provides enough insight, proof, or context inside X/Twitter itself that the reader benefits even if they do not click an external link.

**Empirical tactic** means a practice based on observed behavior or creator testing, not official platform documentation.

**Ranking-confidence boundary** means separating official product capabilities, historical open-source or architecture-level inference, and tactics that require testing on the user's account.

## 4. Platform constraints

- `stable`: X profile bio is limited to 160 characters.
- `inferred`: Treat the bio as a compact landing page for niche, value, proof, and next step.
- `stable`: X profiles support editable profile image, header image, name, bio, location, website, birth date, and pinned post fields.
- `likely`: X account search gives preference to profiles with complete name, username, and bio fields.
- `inferred`: Profile image, header, bio, link path, pinned post, and recent topics should align around the user's credible niche.
- `stable`: Alt Text is for accessibility first and AI interpretation second.
- `inferred`: Use threads or longer posts only when the topic needs depth; do not make them the default format for every idea.
- `stable`: Standard posts support up to 280 characters and up to 4 total media items.
- `likely`: Longer posts are Premium-dependent and documented limits vary by client and current product state, so verify current X documentation before drafting beyond 280 characters.
- `likely`: Native value plus a relevant external link is safer than a post that only points away from the platform.
- `likely`: Substantive replies and conversation depth are stronger practical signals than shallow engagement volume.
- `inferred`: Staying available to reply while discussion is active can support conversation quality, but timing tactics should be sized to the user's real capacity.
- `inferred`: Burst posting can make a user's own posts compete for attention when audience overlap is high.
- `likely`: X publishes current account action limits, including daily post and reply limits for unverified accounts, but states that limits may be temporarily reduced during heavy site usage.
- `disputed`: A universal external-link penalty should not be presented as settled fact.
- `disputed`: Exact live ranking weights across all X surfaces, universal posting-frequency thresholds, and whether Phoenix or Grok-era repository behavior exactly matches production should not be claimed as complete current truth.

## 5. Premium and ranking rules

- `stable`: Verify current official X documentation, visible account settings, or supplied screenshots before giving paid-tier or capability-specific advice.
- `stable`: Verify whether the user actually has Premium before suggesting Premium-only tactics.
- `stable`: Treat paid Boost tools as separate from organic ranking behavior.
- `likely`: Premium may change capabilities such as longer posts, longer video, and reply prioritization, but it is not a viral-growth guarantee.
- `likely`: Current X recommender help pages support directional priors around candidate sourcing, personalization signals, ranking, filtering, user controls, and engagement feedback.
- `inferred`: Historical open-source recommendation repositories can inform architecture priors, but should not be treated as complete current production behavior unless linked from current X documentation.
- `inferred`: Topical consistency helps out-of-network matching and reader trust, but exact matching behavior is not a live public contract.

## 6. Agent failure modes

- Promising ranking outcomes, virality, reach recovery, or shadowban diagnosis from incomplete public evidence.
- Inferring private analytics, Premium status, monetization eligibility, or account settings without supplied proof.
- Treating historical open-source ranking snapshots as current immutable production rules.
- Turning empirical tactics into official platform behavior.
- Forcing a weak pinned post when no evergreen asset exists yet.
- Recommending cadence or engagement systems larger than the user's real capacity.
- Writing bio or post copy around proof the user has not supplied.
- Treating external links, long-form posts, Premium, or reply priority as universally good tactics.

## 7. Output rules

When producing an X/Twitter audit or content plan:

- State which profile fields, posts, pinned assets, media, links, context files, screenshots, or analytics summaries were inspected.
- Separate profile clarity, content structure, engagement or conversation, consistency or proof, and optional Premium opportunities.
- Label product-capability advice as official/current, supplied-account evidence, historical/open-source inference, empirical tactic, or inference.
- Do not add cadence or engagement strategy unless requested or necessary for the user's stated goal.
- Size recommendations to the user's posting capacity and credible niche.
- Include a one-line `Depth note` when the audit did not inspect enough post history, replies, analytics, or Premium state.

Shared taxonomy: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md). Source grounding: [hub/x-twitter/sources.md](../../../../hub/x-twitter/sources.md).
