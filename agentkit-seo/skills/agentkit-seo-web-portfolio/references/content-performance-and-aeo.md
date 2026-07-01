# Web portfolio content, performance, and AI retrieval

## Content rules

- Give the site a clear professional focus.
- Make authorship and proof explicit.
- Keep the About page factual and specific.
- Give every serious project its own detail page.
- Use internal links to connect related proof.
- Retire or update stale pages.
- Publish writing or case studies only when they add first-hand value.

## Case study pattern

Default structure:

1. what the project is
2. why it exists
3. role and ownership
4. stack and constraints
5. key decisions and tradeoffs
6. outcome or metrics
7. proof links

Case-study writing rules:

- state the exact role and ownership scope
- explain the target problem or audience
- include constraints and tradeoffs, not just features
- prefer verifiable outcomes over hype
- use screenshots as supporting evidence, not as the whole page

## Performance and mobile rules

- mobile and desktop should expose the same main content
- serve HTTPS and redirect HTTP
- keep LCP, INP, and CLS within healthy ranges on important pages
- reserve media dimensions to avoid layout shift
- use `font-display: swap` for web fonts
- compress and size media intentionally
- keep ornamentation off the critical path

## AI retrieval layer

- `llms.txt` is optional and should be treated as curated guidance, not as a second sitemap.
- `llms-full.txt` can be useful when the site intentionally publishes mirrored, synchronized markdown for full-context retrieval.
- Keep canonical pages self-contained enough to summarize accurately.
- If mirrored markdown exists, keep it synchronized with canonical HTML.
- Separate retrieval policy from training policy where bot controls differ.

## Confidence rule

Treat AI-discovery conventions such as `llms.txt` as emerging conventions, not as search-engine standards.
