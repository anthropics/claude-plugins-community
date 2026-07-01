# Web portfolio audit and maintenance

## Audit workflow

For default audits, sample only the bounded default scope from `SKILL.md`: homepage, robots, sitemap, and up to 2 user-specified or visibly priority pages. Use the full checklist only when the user asks for a full-site audit, launch or relaunch review, recurring maintenance, or exact code remediation.

Review the site in this order:

1. canonical host, protocol, and redirects
2. indexability of core URLs
3. crawlable navigation and internal links
4. metadata and canonical consistency
5. structured data coverage and fit
6. project-page depth and proof quality
7. mobile and performance risks
8. AI-retrieval extras such as `llms.txt`, if relevant

## Core URL checklist

For full audits, check at minimum:

- homepage
- About page
- Projects hub
- top project detail pages
- Writing hub or key articles, if present
- Contact page

For each URL, verify:

- intended status code
- canonical URL
- unique title
- usable summary in visible copy
- crawlable inbound links
- alignment between page purpose and actual content

## Technical checklist

- Important public pages return `200`.
- Missing pages return `404` or `410`.
- `robots.txt` and `sitemap.xml` are live and production-safe.
- The sitemap includes only canonical, index-worthy URLs.
- Important rendering assets are crawlable.
- Main navigation and contextual links use real anchors and URLs.

## Content and proof checklist

- The site has a clear professional focus.
- The About page identifies the person and current operating domain clearly.
- Every serious project has a dedicated detail page.
- Case studies explain role, scope, constraints, and outcome.
- Proof links resolve and point to real demos, repositories, or artifacts.
- Stale or weak pages are updated, merged, redirected, or removed from the canonical set.

## Metadata and schema checklist

- Titles are unique and topic-led.
- Meta descriptions summarize the actual page.
- Canonicals point to the representative URL only.
- Open Graph tags exist on public pages.
- Structured data matches visible content and page type.
- JSON-LD URL, name or headline, description, and image align with canonical, title, meta description, Open Graph, and X/Twitter tags.
- Article-like schema has visible author, publisher, published date, modified date when used, and representative image support.
- Page-specific preview images are used for important project, article, playbook, or skill pages when possible.
- Home identity, About identity, and external profile names do not conflict.
- External profile links use `rel="me"` when they represent the same public identity.

## Performance and mobile checklist

- Mobile retains the same main content and metadata as desktop.
- Main meaning is present in rendered HTML.
- Images reserve dimensions and use meaningful alt text where appropriate.
- Large media and ornamentation do not delay the main heading or first paragraph.
- HTTPS is enforced consistently.

## Maintenance rules

- Re-audit the canonical pages after major design, routing, or CMS changes.
- Recheck metadata and structured data after template edits.
- Update `llms.txt` or mirrored markdown only when canonical pages also change.
- Remove or repair broken proof links quickly; they age a portfolio faster than modest design flaws do.

## Code-edit safety workflow

When the task requires changing portfolio source code:

1. identify the exact pages, templates, or metadata files involved
2. state the SEO, AEO, accessibility, or crawlability purpose of the edit
3. preserve existing styling and behavior unless the user requests a redesign
4. prefer metadata, structured data, semantic HTML, link, and copy fixes before layout changes
5. run the available build, lint, test, or preview command when one exists
6. report any verification step that could not be performed

Default to a proposed diff or dry-run plan when the requested edit may affect layout, routing, hydration, or application logic.

## Output format for audits

When reporting findings, group them by:

1. blocking indexability issues
2. metadata or structured-data issues
3. architecture or content-depth issues
4. performance or mobile risks
5. optional AI-retrieval improvements

For each issue, name:

- affected page or template
- observed problem
- why it matters
- recommended fix

When reporting code edits, include:

- files changed
- SEO or AEO purpose
- behavioral risk level
- verification performed

For bounded audits, include one `Depth note` naming the URLs or templates inspected, what was not inspected, and what a deeper pass would add.
