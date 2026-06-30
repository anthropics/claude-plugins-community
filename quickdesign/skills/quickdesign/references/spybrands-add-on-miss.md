---
name: When `spy brands --search` returns 0 — research and add the brand on demand
description: When a user asks for a brand's ads / DNA / inspo and the search comes back empty, don't dead-end. Confirm the user wants to add it via AskUserQuestion, resolve the brand's Facebook page URL (homepage scrape → web search → ask), then run `quickdesign spy add <fb-input>` to register it. The BFF inserts the row, LLM-categorizes it, and triggers an initial Meta Ad Library scrape (~10s) in one call. Don't auto-add — paid endpoint with no rate limit, always gate via AskUserQuestion.
---

The Spy Brands library is curated, not exhaustive. When a user asks for ads from a brand that isn't indexed yet, `quickdesign spy brands --search "<X>"` returns `[]`. Before v0.6.0 this was a dead-end. Now there's an add path — but use it carefully: it's auth-only with no rate limit, and a misadded brand needs manual cleanup until `spy remove` ships.

## When this rule fires

The `0 results` trigger is shared between two scenarios; they need different responses:

| User intent signal | Response |
|---|---|
| **Ad-seeking** ("get me ads from X", "analyze X's ads", "inspo from X for my campaign") | Missing brand = blocker. Proceed to confirm + add. |
| **Exploratory search** ("is X in the library?", "do we have X?", "list brands matching X") | Report the miss. Offer add as ONE option but don't push — the user wasn't necessarily asking for the data. |

Don't auto-add in either case. Even ad-seeking users deserve a confirmation gate (cardinal rule #5 + #6) — the add hits Meta Ad Library and inserts a public-DB row.

## Pre-flight check

Before declaring a real miss, make sure you ruled out the search-quality reasons. The v0.5.3 search fix already handles diacritics + prefix/suffix wrapping (`flufie` ↔ `Flufié`, `myflufie` → `Flufié`, `https://myflufie.com` → `Flufié`). If the user's brand has unusual characters, try a few variants in case the BFF you're hitting hasn't deployed v0.5.3 yet:

```bash
quickdesign spy brands --search "flufie"
quickdesign spy brands --search "flufié"
quickdesign spy brands --search "myflufie"
```

If all three return `[]`, the brand is genuinely not indexed.

## Workflow when the user wants ads from a missing brand

### Step 1 — confirm via `AskUserQuestion`

Never auto-add. Surface the choice:

```
Brand X isn't in the Spy Brands library yet. How should we proceed?

  (a) Add it now — research the brand's Facebook page, register, scrape
      the first batch of ads (~10s). Recommended.
  (b) Try a different spelling — re-search with variants.
  (c) Skip — pick a different brand or abort.
```

### Step 2 — resolve the Facebook page URL or ID

The `quickdesign spy add` command accepts ONE of (in order of preference):
1. **Numeric page ID** — `258418472728406`. Most reliable; bypasses BFF's slug-resolve Playwright probe entirely.
2. Facebook page URL — `https://facebook.com/<slug>`, `fb.com/<slug>`, `m.facebook.com/...`. BFF runs a Playwright Ad Library probe to resolve the slug to a numeric ID; this fails for ~10-20% of slugs (page renamed, geo-restricted, brand uses non-obvious URL handle).
3. Meta Ad Library URL with `view_all_page_id=<id>` — **avoid for now**. The BFF's `extractPageId()` parser doesn't extract `view_all_page_id` from query strings cleanly; passing a full Ad Library URL has been observed to create garbage brand entries (the URL itself becomes the slug). If the user gives you an Ad Library URL, manually parse out the `view_all_page_id=...` value and pass JUST the numeric ID to the CLI.

Four resolution strategies, in order. Move down the list when each step fails:

**(a) Scrape the brand's homepage for the FB link** — usually the cheapest. Use `WebFetch` or the `firecrawl-scrape` skill on the brand's website (the user's request typically mentions a URL like `myflufie.com`). Look for `<a href="https://www.facebook.com/...">` in the page source / footer. Pass the discovered URL to `spy add`.

**(b) Web search "<brand-name> facebook page"** — use `WebSearch`. Pick the result whose URL is `facebook.com/<slug>` and whose title matches the brand. Skip personal pages, fan pages, and pages clearly belonging to a different entity. Pass the URL to `spy add`.

**(c) If `spy add <slug-url>` returns 400 with `Could not resolve "..." to a numeric Facebook page ID`,** the slug-resolve Playwright probe gave up. **Don't keep retrying URL variants** — the brand's FB handle is unusual (e.g. `Bombas` resolved fine for nothing despite `facebook.com/bombas` being the actual URL on facebook.com itself; this happens). Pivot to (d) below.

**(d) Ask the user for the numeric page ID** — most reliable fallback. One short prose question pointing them at Meta Ad Library, since copying a page ID from there takes them ~15 seconds:

```
Couldn't auto-resolve <brand>'s Facebook page from the slug. Could you grab
the numeric page ID for me?

  1. Open https://www.facebook.com/ads/library/
  2. Search "<brand>" in the brand search field
  3. Click the brand to open its ad library page
  4. Copy the value of `view_all_page_id=` from the URL
     (e.g. for `?...&view_all_page_id=155577444523958`, copy
     `155577444523958`)
  5. Paste it back to me
```

Then call `quickdesign spy add <numeric-id>` with whatever they paste. The numeric ID path skips Playwright entirely and goes straight to the Meta API.

If the user doesn't know how / doesn't want to look it up, fall back to "skip" — don't loop. Tell them the brand can't be added in this turn and continue with the parts of the original task that don't depend on it.

### Step 3 — register the brand

```bash
quickdesign spy add <facebook-input> --human
```

The BFF will:
1. Resolve `<facebook-input>` to a numeric page ID (handles slug, URL, ad-library URL).
2. Dedup-check by `facebook_page_id`. Returns 409 with the existing `brandId` if already indexed (different name / spelling than what the user asked for).
3. Fetch the canonical page name from a 1-ad probe.
4. Ask Claude Opus 4.6 to pick the most specific category from the 20 seeded labels (or use `--category <slug-or-uuid>` to override).
5. Generate kebab-case slug.
6. Insert the row with `idx=9999` (newest-first sort).
7. Run `fetchEnrichAndSaveBrandAds()` inline — Meta API + Playwright fallback, enriches with creative previews, upserts ads. **This is what makes the call ~10s.**
8. Return `{ success, data: brandRow, suggestedCategory }` plus initial `ad_count`.

### Step 4 — verify identity before continuing

The BFF doesn't validate that the FB page actually belongs to the brand the user asked for. If you resolved the page URL via web search, it's possible you registered the wrong page. Surface the result for verification:

```
✓ Registered "<page name>" (id=<uuid>, slug=<slug>, category=<llm-pick>)
   First ads:
   - "<ad 1 title>"
   - "<ad 2 title>"
```

If either the page name or the first ads obviously don't match what the user wanted, flag it immediately. There's no `spy remove` yet — misadds need manual cleanup via Supabase SQL Editor. The user should know now, not three operations later.

**Special case — `ad_count: 0` on a successful add:** Two distinct causes:
1. **Meta API genuinely has no active ads for this brand.** The brand legitimately doesn't run paid Meta ads (common for premium / editorial brands like Aimé Leon Dore). Brand row is fine; nothing to scrape.
2. **Initial scrape silently failed or timed out.** The BFF's `fetchEnrichAndSaveBrandAds()` call inside add can return empty even when ads exist — most often a 504 on the Playwright fallback path.

To distinguish: open `https://www.facebook.com/ads/library/?active_status=active&view_all_page_id=<page_id>` in a browser. If you see ads there but `ad_count: 0` was returned, it's case 2 — partial failure, the brand row is otherwise correct. There's no `quickdesign spy refresh-ads` subcommand yet to retry; flag this for the user as a known follow-up. If the Ad Library page itself is empty, it's case 1 — accept and move on.

### Step 5 — continue with the original task

```bash
quickdesign spy brand-ads <new-id> --status active --sort most_impressions --human
```

…or `spy best-ads`, brand DNA scrape, etc. — whatever the user originally asked for.

## What NOT to do

- ❌ **Auto-add silently.** Always `AskUserQuestion` first. Cardinal rule #5 (confirmation gates) applies even though `spy add` doesn't burn user-visible credits — it does hit Meta Ad Library and creates a public DB row that other users will see in `spy brands` lists.
- ❌ **Loop the FB-resolve step indefinitely.** If strategies (a) (b) (c) all fail, accept that the brand can't be added in this turn. Tell the user, suggest they grab the FB URL manually.
- ❌ **Force-add when 409 fires.** The dedup means the brand already exists under a different name. The CLI surfaces the existing `brandId` in stderr — short-circuit to that ID instead of nagging the user.
- ❌ **Add multiple brands in one turn without re-asking.** If the user's request implicitly involves N brands ("compare X, Y, Z's ads"), surface ALL the misses in one `AskUserQuestion` with a multi-select, not N separate prompts.

## Cost / latency expectations

Set the user expectation in the plan summary BEFORE running `spy add`:

> **Step:** Register `<brand>` in Spy Brands → fetch first batch of ads.
> **Cost:** 0 credits (server-side Meta API call).
> **Latency:** ~10s (Meta Ad Library scrape blocks the response).

The CLI emits a one-line stderr notice during the wait so the user sees the "fetching first ads" message even in auto mode.

## Cleanup of misadds

Until `spy remove` ships:
1. Get the brand UUID from the previous `spy add` output.
2. Send the user the SQL needed: `DELETE FROM spy_brand_ads WHERE brand_id = '<uuid>'; DELETE FROM spy_brands WHERE id = '<uuid>';`
3. They run it via Supabase Studio's SQL Editor (agents are forbidden from touching the live DB per CLAUDE.md).
