---
name: agentkit-seo-x-twitter
description: Optimize X and Twitter profile positioning, pinned post strategy, posting structure, and discoverability using conservative platform guidance. Use when the user asks about X or Twitter bio copy, pinned posts, content cadence, profile optimization, engagement strategy, premium tactics, or feed/search discoverability.
license: MIT
metadata:
  homepage: https://agentkit-seo.github.io/
  repository: https://github.com/agentkit-seo/agentkit-seo
---

# AgentKit SEO X/Twitter

## Overview

Work through the lens of an editor growing a credible technical audience for the user. Use the X/Twitter hub to improve profile clarity and posting structure while avoiding overclaims about undocumented live ranking systems.

## Reference selection

- Bio, profile, pinned post, media, thread structure: [references/profile-and-posts.md](references/profile-and-posts.md)
- Ready-to-post display name, bio, pinned post, post, thread, Alt Text: [references/section-recipes.md](references/section-recipes.md)
- Growth strategy, replies, ranking-signal explanations: [references/engagement-and-ranking.md](references/engagement-and-ranking.md)
- Premium-specific advice and confidence labeling: [references/premium-and-confidence.md](references/premium-and-confidence.md)
- Existing-account audit or maintenance: [references/account-audit-and-maintenance.md](references/account-audit-and-maintenance.md)

## Wiki context

- Read [wiki/index.md](wiki/index.md) when the task asks about X/Twitter ranking explanations, Premium or paid-tier capabilities, external-link claims, confidence labels, platform constraints, known agent failure modes, or full audit source discipline.
- Read [wiki/knowledge.md](wiki/knowledge.md) only after [wiki/index.md](wiki/index.md) routes the current task there.
- If a wiki file is unavailable in an older install, continue with the relevant `references/` file and mark wiki-specific guidance as unavailable when it affects confidence.

## Token discipline

- Do not analyze long posting history unless the user asks for an audit.
- For profile copy, inspect bio, pinned post, proof links, and up to 3-5 recent posts first.
- Read Premium or ranking references only when the user asks about those topics.
- Prefer pasted profile text, public profile fields, pinned post, links, and a small recent-post sample before asking for analytics exports or screenshots.
- Keep source ledgers compact: list input groups, not every post unless the post itself is discussed.
- Name next inspection if bounded.

## Depth contract

Use the smallest honest audit depth:

- `Quick scan`: display name, bio, link path, pinned post, and obvious niche/proof gaps.
- `Default audit`: quick scan plus up to 10 recent posts, media/Alt Text when visible, proof-link alignment, and posting capacity assumptions.
- `Deep audit`: last 20-30 posts, reply behavior, topic drift, analytics screenshots, Premium capabilities, and cross-platform proof consistency.

Default to `Default audit` for broad account or profile requests. Offer `Deep audit` as an optional next step when the current answer would benefit from more evidence. Do not choose `Deep audit` silently unless the user asks for a full account audit, content system, analytics review, or recent-post history diagnosis.

## Intake workflow

- If the user provides an X/Twitter URL or handle, inspect publicly accessible profile material and recent posts when tools allow it.
- If public access is blocked, stale, or incomplete, ask for screenshots, pasted bio and pinned post, recent post examples, analytics summaries, or a local text file export.
- Ask for the target audience, niche, posting capacity, proof links, and topics the user can credibly discuss before building a posting strategy.
- If the account strategy depends on professional facts or cross-platform consistency, recommend creating or updating the personal career context file first.

## Rules

- Prefer current official X help and recommender-system documentation before historical open-source repositories when explaining platform behavior.
- Treat Phoenix, Grok, and related architecture clues as design signals, not as a complete live-production contract.
- Verify current official X product documentation before giving paid-tier, Premium, post-length, media-length, monetization, or account-capability advice. If verification is unavailable, label the guidance as historical or inferred.
- Separate facts verified from public account material, facts supplied by the user's context material, and recommendations inferred from those facts.
- Do not promise ranking outcomes.
- Do not infer private analytics, Premium status, shadowban status, or ranking treatment from incomplete public views.
- Keep recommendations aligned with the user's actual niche, expertise, and posting capacity.
- Distinguish official product features, current recommender documentation, historical/open-source inference, and empirical tactics.
- Keep profile positioning, pinned assets, posting topics, and linked external proof aligned around one clear niche.
- Use career direction to choose niche, bio emphasis, pinned-post framing, and topic lanes, but keep emerging directions framed as exploration or building-in-public until proof exists.
- Honor context-file evidence boundaries, positioning constraints, and claims to avoid when turning interests into public profile copy.
- When profile proof, audience, or posting history is missing, ask for it before inventing claims or forcing a content strategy.

## Self-review

Before returning, check the draft and fix or flag any failure:

- No promised ranking outcomes and no invented analytics, Premium status, or proof; every claim traces to public material, the context file, or is labeled by confidence.
- Premium, paid-tier, and ranking advice is verified against current official docs or labeled historical or inferred.
- Output matches the requested scope, the user's real niche and capacity, and their stated goals; nothing drifted into unrequested cadence or strategy.
- Profile, pinned assets, topics, and linked proof stay aligned around one clear niche.

If a check fails and cannot be fixed from available inputs, say so rather than papering over it.

## Response shape

Return only requested-relevant sections. Do not add cadence or engagement strategy unless requested or clearly necessary. For audits, return:

1. public inputs inspected and any blocked inputs
2. profile and content-positioning diagnosis
3. ready-to-paste bio, pinned post, thread, or post drafts
4. cadence and engagement recommendations sized to the user's capacity
5. missing inputs needed for a stronger second pass

For audits, use concise labels such as `Verified`, `Official feature`, `Historical/open-source inference`, `Empirical tactic`, `From context`, `Inference`, and `Inaccessible` when a claim could otherwise be ambiguous. When the audit is intentionally bounded, include a one-line `Depth note` that says what profile/post scope was inspected, what was not inspected, and what deeper inspection would add.

Human playbook: [hub/x-twitter/README.md](../../../hub/x-twitter/README.md).
