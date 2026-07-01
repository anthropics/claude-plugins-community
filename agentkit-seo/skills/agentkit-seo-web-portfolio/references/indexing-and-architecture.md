# Web portfolio indexing and architecture

## Indexability rules

- Important public pages must return HTTP `200`.
- Important pages must contain indexable text.
- Keep rendering assets crawlable when they are required for the page to work.
- Use `noindex` for deindexing, not `robots.txt`.
- Publish `/robots.txt` and include the sitemap location.
- Publish `/sitemap.xml` with canonical, index-worthy URLs only.
- Do not rely on deprecated Google sitemap ping behavior; use Search Console, `robots.txt`, and normal crawling.

## Submission workflow

- verify the production domain in Google Search Console
- submit the sitemap
- inspect priority URLs
- add Bing Webmaster Tools
- use IndexNow where supported

Launch order:

1. confirm canonical HTTPS host and direct redirects
2. verify core pages return the intended status codes
3. confirm `robots.txt` and `sitemap.xml` are live
4. inspect the homepage, About page, Projects hub, and key project URLs
5. request indexing only for production-ready priority pages

## Architecture rules

- Give important intents their own URLs.
- Keep a shallow, obvious hierarchy.
- Use readable, lowercase, hyphenated URLs.
- Use real anchor links for navigation.
- Keep project, writing, and About pages reachable from crawlable parent pages.
- Keep important pages internally linked.
- Return real `404` or `410` for missing routes.

## Baseline URL map

```text
/
/about/
/projects/
/projects/<slug>/
/writing/
/contact/
```

## Anti-patterns

- blocked production sites
- single-page-only portfolios with no project detail URLs
- orphan pages
- JS-only route changes with no real `href`
- redirect chains between host or protocol variants
