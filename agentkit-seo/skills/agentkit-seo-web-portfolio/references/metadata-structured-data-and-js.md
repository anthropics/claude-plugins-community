# Web portfolio metadata, structured data, and JavaScript SEO

## Metadata rules

- Every indexable page needs a unique title.
- Lead with the page topic, then the site or person name.
- Keep titles concise enough to avoid common truncation.
- Write a real meta description for important pages.
- Keep visible copy aligned with metadata.
- Choose one canonical host and protocol.
- Keep the visible `h1` aligned with the page topic so titles and headings do not send conflicting signals.

## Social-preview rules

- Set `og:title`, `og:description`, `og:image`, and `og:url` on public pages.
- Use page-specific preview images where possible.
- Add X card tags as a fallback.
- Prefer a project screenshot over a generic site logo on project pages.
- Keep `og:image`, `twitter:image`, and JSON-LD `image` aligned when one image represents the page.

## Structured-data rules

- Use a small, accurate schema set.
- Homepage: `WebSite`
- About/profile page: `ProfilePage` with `Person`
- hierarchical pages: `BreadcrumbList`
- index/listing pages: `CollectionPage`
- contact pages: `ContactPage`
- software project pages: `SoftwareSourceCode` or `SoftwareApplication` when the visible page actually supports that type
- writing pages: `Article`, `BlogPosting`, or `TechArticle` only when visible content supports article fields
- outbound identity links: `rel="me"` where useful, without presenting it as a guaranteed identity or ranking mechanism

Keep markup aligned with visible content. Do not pile on unrelated schema types.

For article-like pages, only emit `headline`, `description`, `url`, `mainEntityOfPage`, `image`, `author`, `publisher`, `datePublished`, `dateModified`, `keywords`, and `inLanguage` when the page or source has real values. Make update dates visible when using freshness fields.

Schema quality matters more than schema quantity. Do not mark contact pages, index pages, provider pages, or simple project landing pages as articles unless they are genuinely written and presented as articles.

Structured data can make pages clearer and eligible for enhanced presentation. It does not guarantee rankings, rich results, image thumbnails, snippets, indexing, or traffic.

## JavaScript SEO rules

- Prefer static generation, SSR, or hybrid rendering for core pages.
- Ensure titles, headings, primary copy, canonical tags, structured data, and important links exist in rendered HTML.
- Lazy-load media, not the main meaning of the page.
- Provide lightweight fallback identity content when a strict environment may skip JS entirely.
- Return real status codes for missing pages.
- Treat dynamic rendering as a workaround, not the ideal default.
