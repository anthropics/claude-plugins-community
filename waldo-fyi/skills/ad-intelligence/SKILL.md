---
name: ad-intelligence
description: >-
  Trigger when the user says "what ads is [brand] running", "show me
  [competitor] creatives", "how is [brand] advertising", "what's [brand]
  saying in ads", "compare ad strategies", "ad library", "find ads for
  [keyword]", or asks about competitor ads, paid media presence, ad creative,
  ad messaging, hook/value-prop comparisons, or regional campaign mapping on
  Meta/Google/LinkedIn — even without saying "ad". Do NOT trigger for ad
  performance metrics (ROAS, CTR, spend — not available); defer to Social
  Intelligence for organic posts.
---

# Ad Intelligence

<hard_rules>
- **NEVER answer ad-related questions from memory or training data.** Always use the ad library tools defined in this skill to retrieve live data before making any claims about a brand's advertising activity. If tools return no results, say so — do not guess, infer, or fabricate ad details.
- Every specific ad referenced in your output MUST include a citation (see Citation Formatting below).
</hard_rules>

<dependency_checks>
Before calling any ad library tool, run through this gate:

1. **Brand name or keyword** — HARD REQUIREMENT. If missing, ask and do not proceed until provided.

2. **Optional parameters** (category, platform, region):
   - First, scan the conversation history for any prior clarification question you asked about these parameters.
   - **If you have NOT yet asked a clarification question in this conversation**: Ask ONE round of clarifications covering any ambiguous optional params (category, platform, region). Keep it brief — a single message, not multiple back-and-forths. Then STOP and wait for the user's response.
   - **If you HAVE already asked a clarification question (whether the user answered it or not)**: Do NOT ask again. Infer reasonable defaults for anything still missing and proceed immediately.

   Default inference rules when proceeding without answers:
   - **Category**: Infer from brand context (e.g. dental brand → healthcare)
   - **Platform(s)**: Search all three (Meta, Google, LinkedIn)
   - **Region**: Infer from user location or brand HQ. Use ISO 2-letter codes. If unknown, assume US

   State your inferred assumptions briefly before executing searches.

**Summary: You get exactly ONE clarification round for these params. If chat history already contains a platform/category/region question, skip straight to inference and execution.**
</dependency_checks>

---

## Ad Library Tools

### Meta — `search_meta_ads`
Required params: `query`, `country`, `category`, `activity_status`.
- **query**: Brand name or product keyword. Keep it short (1-3 words).
- **country**: ISO 2-letter code. Use "ALL" only if user explicitly says global.
- **activity_status**: Use "ACTIVE" for current, "INACTIVE" for ended, "ALL" for both.
- **Optional filters**: `platform`, `media_type`, `start_date`/`end_date`, `language`.

**Tip**: Use `get_meta_ad_search_auto_fill` or `meta_advertiser_search` to resolve a brand's page ID, then pass as `advertiser` param.

### Google — `search_google_ads`
Requires either `advertiser_id` or `domain`.
- **domain**: Brand's website domain (e.g. "nike.com").
- **time_period**: "today", "last_7_days", "last_30_days", or "YYYY-MM-DD..YYYY-MM-DD".
- **Optional filters**: `ad_format`, `platform`, `region`.

### LinkedIn — `search_linkedin_ads`
Provide at least one of `q` or `advertiser`.
- **country**: ISO 2-letter codes, comma-separated for multiple markets.
- **time_period**: "last_year", "this_year", "this_month", "last_30_days", or "YYYY-MM-DD..YYYY-MM-DD".
- Turn off zero retention, do not use that param.

### Tool Budget For Search Ads Tools
- 1 call per tool per brand is the default
- Only make a 2nd call if the 1st returns insufficient results — adjust parameters (e.g. broader date range, different filters) on retry
- For multi-brand searches: apply the same 1-default / 2-max rule per tool per brand and search in parallel when possible
- Default settings:
  - `search_meta_ads`: no constraints as one call by default has only 30 max results
  - `search_google_ads`: `num=30`
  - `search_linkedin_ads`: `time_period=last_30_days` (unless user wants older specifically)
- If more ads are available beyond what was retrieved, suggest further research to the user in your output explaining that more are available if needed.

---

## Advertiser Discovery (Meta)

1. `meta_advertiser_search` or `get_meta_ad_search_auto_fill` to find the page ID
2. `search_meta_ads` with that page ID as `advertiser`
3. `get_meta_ad_details` or `get_meta_ad_summary_details` to drill into specifics

---

<parallel_tool_calling>
Batch all independent ad library searches into a single response:
- Searching the same advertiser across Meta, Google, and LinkedIn → 3 parallel calls
- Comparing 3 brands on Meta → 3 parallel calls
- Running advertiser discovery + initial search on different platforms → parallel
- Fetching ad details or creative analysis for multiple ads → all parallel
- Sequential only when one call's output is needed as input (e.g., `meta_advertiser_search` to get a page ID, then `search_meta_ads` with that ID)
</parallel_tool_calling>

---

## Creative Analysis

Use `fetch_and_analyze_image` and `fetch_and_analyze_video` when the user asks about visual elements, creative themes, or design patterns.

1. Run the ad search tool first to get results with media URLs
2. Pass media URLs to analysis tools with a descriptive prompt — **batch all analysis calls in parallel**
3. Write prompts specific to the user's question
4. **Fetch and Analyze Tools Budget**: Only run analysis for max 10 ads in a batch. Then stop, provide the answer, and offer additional batches if necessary or available.

---

## Citation Formatting

Every specific ad you mention in the output MUST have a citation.

- **Format:** `[[Ad title or campaign name]](adUrl)` — placed after the period at the end of the sentence. Source name should describe the creative (not just a domain or ad ID). Preserve inline format across all response languages.
- **Images:** `![Ad title](image_url)`
- Only cite URLs from your current search results or fetched pages. Never cite from memory.
- No results? Say so plainly. Do not fabricate citations.
- Use the minimum citations necessary to support each claim — do not over-cite.

---

## Platform Coverage Gaps

Direct ad library tools exist for **Meta**, **Google**, and **LinkedIn** only. For TikTok, YouTube (beyond Google Ads), programmatic, CTV, X/Twitter, Pinterest, Snapchat, Reddit — fall back to `search_web`.

---

## Competitive Analysis Patterns

### Side-by-side comparison
Run all brand searches **in parallel**. Compare:
- **Volume**: Number of active ads
- **Platforms**: Where each brand invests
- **Creative formats**: Video vs. static, carousel vs. single image
- **Messaging themes**: Value propositions, CTAs, offers
- **Recency**: Creative refresh frequency
- **Regional presence**: Market targeting differences

### Category mapping
1. Use `search_web` to identify key players
2. Suggest 3-5 brands and confirm with user
3. Run ad library searches for each **in parallel**
4. Synthesize into comparative view

---

## Skill Deferral

This skill handles paid advertising only. Route elsewhere for:
- Social media sentiment/organic posts → Social Intelligence skill
- General web/news research → Web Research skill
- Data files or statistical analysis → Data Analysis skill
- Archived brand signals/insights → Archival Knowledge skill
