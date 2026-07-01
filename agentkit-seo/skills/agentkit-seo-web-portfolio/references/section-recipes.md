# Web portfolio section recipes

## Homepage recipe

The homepage should orient the visitor quickly and route them into deeper pages. Keep it concise.

Default structure:

1. clear professional identifier
2. one-paragraph focus statement
3. links to core hubs or featured proof
4. selected recent or representative work
5. contact or next-step path

Default writing posture:

- Lead with who the person is and what kind of work they do.
- Keep role, domain, and proof visible above the fold.
- Link outward to the strongest supporting pages rather than overloading the homepage with every detail.

## About page recipe

The About page is the main identity page. It should support `ProfilePage` and `Person` markup cleanly.

Default structure:

1. current role and professional focus
2. core strengths or recurring domains
3. evidence of experience or shipped work
4. link set to external identities and primary proof

Default writing posture:

- Use factual first-person or close third-person language.
- Prefer specific domain, stack, and ownership statements over mission language.
- Keep the page self-contained enough that an agent or search system can summarize the person without stitching together multiple pages.

## Project or case-study recipe

Every serious project should have a dedicated detail page with enough depth to stand on its own.

Default structure:

1. what the project is
2. why it exists
3. role and ownership
4. stack and constraints
5. key decisions and tradeoffs
6. outcome, metrics, or current status
7. proof links: repository, demo, article, screenshots, talk

Writing rules:

- State exact ownership boundaries when the work was collaborative.
- Name the intended audience or problem space early.
- Use screenshots and demos as supporting proof, not as the only explanation.
- If metrics are unavailable, describe concrete outputs or operational changes instead of inventing impact numbers.

## Metadata recipe

For each indexable page, draft:

- a unique title with the page topic first
- a concise meta description grounded in visible content
- page-specific Open Graph title, description, URL, and image
- the canonical URL

Title pattern examples:

- homepage: `Name | Role or domain`
- About page: `About | Name`
- projects hub: `Projects | Name`
- project detail page: `Project name | Case Study | Name`
- writing page: `Article title | Name`

## llms.txt recipe

Use `llms.txt` only when AI retrieval is an explicit goal.

Default structure:

1. site name and one-line description
2. core pages
3. optional pages

Rules:

- Keep it short and curated.
- Point to canonical public URLs.
- Do not let it drift away from the actual live site.

## Rewrite posture

When rewriting a portfolio page:

- preserve verified facts
- remove vague, hype-heavy language
- improve information scent and scanability
- align visible copy with metadata and structured data
- call out missing proof instead of fabricating it
