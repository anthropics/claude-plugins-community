---
name: agentkit-seo-web-portfolio
description: Optimize personal website and web portfolio discoverability, crawlability, metadata, structured data, content usefulness, and AI-readable signals. Use when the user asks about portfolio pages, titles, meta descriptions, canonical tags, snippets, indexability, JavaScript SEO, structured data, performance, llms.txt, or web-based personal branding.
license: MIT
metadata:
  homepage: https://agentkit-seo.github.io/
  repository: https://github.com/agentkit-seo/agentkit-seo
---

# AgentKit SEO Web Portfolio

## Overview

Work through the lens of a technical SEO specialist and a hiring manager skimming the site. Use this skill to improve how a personal site is crawled, rendered, summarized, and trusted by search engines and AI systems.

## Reference selection

- Crawlability, sitemaps, robots, launch, URL structure: [references/indexing-and-architecture.md](references/indexing-and-architecture.md)
- Titles, canonicals, schema, JavaScript rendering: [references/metadata-structured-data-and-js.md](references/metadata-structured-data-and-js.md)
- Homepage, About, project page, metadata, `llms.txt` copy: [references/section-recipes.md](references/section-recipes.md)
- Case studies, performance, AI retrieval conventions: [references/content-performance-and-aeo.md](references/content-performance-and-aeo.md)
- Existing-site audit or maintenance: [references/portfolio-audit-and-maintenance.md](references/portfolio-audit-and-maintenance.md)
- Audit scorecard and prioritized fix-first ranking: [references/audit-scoring.md](references/audit-scoring.md)

## Wiki context

- Read [wiki/index.md](wiki/index.md) when the task asks about `llms.txt`, AI retrieval, evidence labels, source confidence, platform constraints, or known agent failure modes.
- Read [wiki/knowledge.md](wiki/knowledge.md) only after [wiki/index.md](wiki/index.md) routes the current task there.
- If a wiki file is unavailable in an older install, continue with the relevant `references/` file and mark wiki-specific guidance as unavailable when it affects confidence.

## Token discipline

- For a URL audit, inspect homepage, robots, sitemap, and only priority pages first.
- For local source work, search for metadata, routes, layout, and structured data before opening broad files.
- Do not load content-writing references for a technical crawlability fix.
- Prefer rendered/public HTML, route metadata, sitemap, robots, and page templates before reading broad content files.
- Keep source ledgers compact: list input groups, not every asset or route.
- Name next inspection if bounded.

## Depth contract

Use the smallest honest audit depth:

- `Quick scan`: homepage, robots, sitemap, title/meta/canonical basics, main navigation, and visible positioning.
- `Default audit`: quick scan plus up to 2 user-specified or visibly priority pages, structured data, Open Graph, internal links, and top project pages when available.
- `Deep audit`: full route inventory, built HTML/source templates, performance/mobile checks, redirects/status codes, schema validation, broken links, and code edits.

Default to `Default audit` for broad portfolio audits. Offer `Deep audit` as an optional next step when the current answer would benefit from more evidence. Do not choose `Deep audit` silently unless the user asks for a full site audit, exact code changes, launch validation, or every important route checked.

## Intake workflow

- If the user provides a public portfolio URL, fetch and inspect the homepage, important pages, metadata, canonicals, sitemap, robots, structured data, and visible copy when tools allow it.
- If the portfolio source is available locally and the user asks for implementation, inspect the source and prefer direct code edits for metadata, structured data, semantic HTML, links, and content. For audit-only requests, return patch-ready recommendations unless the user asks to edit.
- If public crawling is blocked or the site is not deployed, ask for local source paths, built HTML, screenshots, page inventory, or pasted page copy.
- If the site copy depends on biography, project claims, or career facts, recommend using the personal career context file before rewriting.
- Do not invent projects, testimonials, metrics, employers, or credentials to fill portfolio pages.

## Rules

- Separate documented standards from emerging conventions such as `llms.txt`.
- Separate facts verified from public pages or local source, facts supplied by the user's context material, and recommendations inferred from those facts.
- Prefer changes that improve crawlability, information scent, and snippet quality without adding hype.
- Do not present unofficial AI or SEO proposals as universal standards.
- Keep metadata, structured data, and visible copy aligned.
- Keep title, description, canonical URL, Open Graph, X/Twitter card, JSON-LD URL, JSON-LD name or headline, JSON-LD description, and representative image consistent for the same page.
- Match structured data to page purpose. Use article-like schema only for visible article-like pages with supported author, date, and body content.
- Treat rankings, rich results, image thumbnails, snippets, and indexing speed as eligibility outcomes, not guarantees.
- Keep page purpose, URL structure, internal links, and proof assets aligned so every important claim resolves to a crawlable page.
- Use career direction to prioritize homepage positioning, About copy, project ordering, and case-study framing, but keep every public claim tied to visible or supplied proof.
- Honor context-file evidence boundaries, positioning constraints, and claims to avoid when writing metadata, schema, and visible copy.
- When facts are missing, ask for the canonical URL, page inventory, or source content before inventing portfolio copy or structured data.
- When editing portfolio code, preserve existing styling and application logic unless the user explicitly asks for a redesign. Prefer metadata, structured data, semantic HTML, crawlability, and content changes before layout changes.
- For direct code edits, run the available build, lint, test, or preview command when the project provides one, and report any verification that could not run.

## Self-review

Before returning, check the draft and fix or flag any failure:

- No invented projects, testimonials, metrics, employers, or credentials; structured data and copy reflect only verified or supplied facts.
- Rankings, rich results, and indexing are framed as eligibility, not guarantees; emerging conventions are not presented as standards.
- Output matches the requested scope and the user's stated goals; metadata, structured data, and visible copy stay consistent for each page.
- Any code edits preserve existing styling and logic, and verification that could not run is reported.

If a check fails and cannot be fixed from available inputs, say so rather than papering over it.

## Response shape

Return:

1. URLs or local files inspected
2. crawlability, metadata, structured-data, and content issues
3. direct code edits or page-ready copy
4. verification run or checks still needed
5. context-file gaps that affect public claims

For audits, use concise labels such as `Verified`, `From source`, `From context`, `Inference`, and `Inaccessible` when a claim could otherwise be ambiguous. Mark unsupported responsibilities, metrics, seniority, clients, testimonials, or outcomes as gaps rather than turning them into metadata, schema, or copy. When the audit is intentionally bounded, include a one-line `Depth note` that says what was not inspected and what deeper inspection would add.
When the user asks for a score, scorecard, or before/after comparison, also apply [references/audit-scoring.md](references/audit-scoring.md): report the overall score, band, per-category breakdown, and a fix-first ranking, labeled as an internal prioritization heuristic rather than a ranking or indexing guarantee.

Human playbook: [hub/web-portfolio/README.md](../../../hub/web-portfolio/README.md).
