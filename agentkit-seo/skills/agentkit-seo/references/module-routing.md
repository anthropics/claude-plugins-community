# Module routing

Use this routing table when deciding which AgentKit SEO skill to load.

| User intent | Shared skill | Internal skill references to start with |
| --- | --- | --- |
| Personal context file, source-of-truth document, fact consolidation | `agentkit-seo-agent-context-optimization` | `references/spec-and-structure.md`, `references/operating-workflow.md` |
| CV rewrite, ATS-safe formatting, keyword strategy | `agentkit-seo-cv-ats` | `references/structure-and-formatting.md`, `references/keywords-and-bullets.md` |
| GitHub profile, repos, README, discoverability, Copilot-facing repo context | `agentkit-seo-github` | `references/profile-and-repo-structure.md`, `references/copilot-and-agent-readiness.md` |
| LinkedIn headline, about, featured, experience, skills, profile discoverability | `agentkit-seo-linkedin` | `references/positioning-and-structure.md`, `references/discoverability-and-activity.md` |
| Personal site, metadata, snippets, structured data, JavaScript SEO, llms.txt | `agentkit-seo-web-portfolio` | `references/indexing-and-architecture.md`, `references/metadata-structured-data-and-js.md` |
| X/Twitter bio, pinned post, posting strategy, discoverability | `agentkit-seo-x-twitter` | `references/profile-and-posts.md`, `references/engagement-and-ranking.md` |

## Cross-platform sequence

When a request spans multiple surfaces, use this order unless the user asks otherwise:

1. `agentkit-seo-agent-context-optimization`
2. Target output surface, such as `agentkit-seo-linkedin`
3. Supporting surfaces that must align with the same positioning

## Ambiguity tie-breakers

Use these defaults when the user asks for broad improvement without naming a platform:

- Job search, applications, recruiter screens, or a specific job description: start with `agentkit-seo-cv-ats`.
- Recruiter discovery, profile search, or professional positioning: start with `agentkit-seo-linkedin`.
- Developer credibility, proof-of-work, repositories, README quality, or technical trust: start with `agentkit-seo-github`.
- Personal site, Google snippets, crawlability, structured data, or portfolio pages: start with `agentkit-seo-web-portfolio`.
- Audience building, posting, niche, pinned post, or engagement loop: start with `agentkit-seo-x-twitter`.
- Mixed facts, inconsistent claims, or more than one public surface: start with `agentkit-seo-agent-context-optimization`.

If two routes remain plausible, state the assumption and proceed with the route that can produce the smallest useful next action.
