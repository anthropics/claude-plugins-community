<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo-web-portfolio
  title: "Web portfolio runtime knowledge"
  status: stable
  confidence: likely
  last_reviewed: 2026-05-27
  review_by: 2026-08-27
  source_status: mixed
  agent_priority: high
-->

# Web portfolio runtime knowledge

> This file contains durable web-portfolio knowledge for agents. Use it to keep portfolio SEO, metadata, AI retrieval, and public-claim handling factual and source-aware.

## 1. Load contract

Read this file only after [index.md](index.md) indicates that the current task needs compiled web-portfolio knowledge.

If this file is unavailable in an older install, continue with `references/content-performance-and-aeo.md`, `references/indexing-and-architecture.md`, `references/metadata-structured-data-and-js.md`, or `references/section-recipes.md` as appropriate. Mark `llms.txt`, AI retrieval, and confidence-label guidance as lower confidence if the wiki is unavailable.

## 2. Confidence labels

Use these labels when making portfolio recommendations:

- `stable`: Supported by durable web standards, repository policy, or visible source evidence that is unlikely to change quickly.
- `likely`: Supported by current common practice or project methodology, but still dependent on implementation details or platform behavior.
- `inferred`: Reasoned from available evidence, but not directly documented or verified in the inspected source.
- `disputed`: Conflicting, unstable, unofficial, or not broadly adopted enough to present as settled behavior.

Do not convert `likely`, `inferred`, or `disputed` claims into guarantees.

## 3. Canonical definitions

**Web portfolio SEO** means making a personal website crawlable, understandable, internally coherent, and useful to searchers, recruiters, technical reviewers, and AI-assisted retrieval tools.

**AEO** means answer engine optimization. In this module, it refers to making pages easier for AI search and assistant systems to retrieve, summarize, and cite accurately. It does not replace standard SEO.

**AI retrieval layer** means optional files and page structures that help LLM-based tools understand the site at inference time, including `llms.txt`, `llms-full.txt`, clean Markdown mirrors, concise page summaries, and explicit crawler policy.

**Canonical page** means the public page that should be treated as the source of truth for a claim, project, person, article, or profile surface.

## 4. Platform and web constraints

- `stable`: Important public pages should expose title, description, canonical URL, primary heading, visible body content, and important links in rendered HTML.
- `stable`: Metadata, visible copy, canonical URL, social-preview tags, and JSON-LD should describe the same page and entity.
- `stable`: Structured data must match visible page content. Do not add schema fields for facts that are not present in the page or verified source material.
- `stable`: Article-like schema belongs on article-like pages with visible article content and real author and date fields.
- `stable`: Missing pages should return real missing-page status codes instead of indexable soft-404 content.
- `stable`: Mobile and desktop versions should expose the same primary content and navigation targets.
- `likely`: Static generation, SSR, or hybrid rendering is safer for portfolio core pages than client-only rendering when crawlability and reliable snippets matter.
- `likely`: Project-detail pages are stronger proof assets than a single homepage section when a portfolio needs to support specific claims.
- `inferred`: A project screenshot is usually a stronger social-preview image for a project page than a generic site logo, if the screenshot is readable and representative.

## 5. `llms.txt` convention

- `likely`: `llms.txt` is an emerging Markdown convention for giving LLM-based tools a concise map of a site's most useful pages.
- `likely`: The file usually belongs at `/llms.txt` for a public site, with an optional `/llms-full.txt` companion for fuller context.
- `likely`: `llms.txt` should be curated. It should not duplicate every sitemap URL.
- `likely`: Strong portfolio candidates for `llms.txt` include the homepage, About page, Projects hub, best project-detail pages, writing hub, and selected case studies.
- `likely`: `llms-full.txt` is useful only when full-context Markdown is intentionally generated from canonical content and kept synchronized.
- `disputed`: No major search or AI provider should be assumed to guarantee ranking, citation, ingestion, or retrieval benefits from `llms.txt`.
- `stable`: Treat `llms.txt` as inference-time guidance, not as crawler permission policy. Use `robots.txt` and provider-specific bot controls for crawler permissions.

AgentKit SEO's web-portfolio methodology treats `llms.txt` as an optional AI-readability layer after canonical pages, metadata, structured data, sitemap, robots, and visible proof are coherent.

## 6. Evidence and inference rules

Use the AgentKit SEO evidence labels defined in `agentkit-seo/wiki/agentkit-seo.md`.

For web-portfolio work, `Verified` means the fact was observed in public pages, rendered HTML, local source files, built output, HTTP responses, metadata tags, structured data, sitemap or robots files, supplied screenshots, a supplied context file, or pasted source material.

`Inaccessible` commonly applies to blocked URLs, private pages, login-gated dashboards, search-console data, analytics, crawler behavior that was not tested, deployed runtime behavior that was not rendered, and AI retrieval or citation behavior that cannot be observed directly.

## 7. Known agent failure modes

- Turning sparse biography notes into exaggerated professional claims.
- Adding schema fields for facts that are not visible on the page.
- Marking simple landing pages as `Article`, `BlogPosting`, or `TechArticle`.
- Treating `llms.txt` as a ranking guarantee or official search-engine standard.
- Creating an AI-only shadow site that drifts from canonical HTML.
- Recommending broad redesigns when metadata, crawlability, content alignment, or structured data would solve the issue.
- Reading every route for a bounded audit instead of following the skill's depth contract.
- Ignoring rendered HTML and relying only on source templates when the deployment behavior matters.
- Treating social-preview images, snippets, rich results, AI citations, or indexing speed as guaranteed outcomes.

## 8. Output rules

When producing a web-portfolio audit or implementation plan:

- State which URLs, files, or rendered outputs were inspected.
- Separate crawlability, metadata, structured-data, content, and AI-retrieval issues.
- Label unsupported public claims as gaps.
- Prefer canonical-page improvements before generated AI-facing mirrors.
- Keep `llms.txt` recommendations short, curated, and synchronized with public pages.
- Name the smallest next inspection when the current audit is bounded.

Shared taxonomy: [agentkit-seo/wiki/agentkit-seo.md](../../agentkit-seo/wiki/agentkit-seo.md). Source grounding: [hub/web-portfolio/sources.md](../../../../hub/web-portfolio/sources.md).
