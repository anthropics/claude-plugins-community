---
name: web-research
description: >-
  Trigger when the user says "research [brand/topic]", "deep dive on [X]",
  "compare [A] vs [B]", "audit [website]", "what does [brand] do", "draft a
  POV on [topic]", "give me a POV on [X]", "summarize this PDF", "analyze
  this whitepaper", "how does [competitor] position", or asks any open-ended
  brand/category/competitor question, persona simulation, or demographic
  breakdown. POV and persona prompts always need fresh research grounding —
  never answer from training alone. Conducts multi-source web research with
  PDF analysis, page screenshots, and visual/UX audits. Do NOT trigger for ad
  library searches (use Ad Intelligence) or social sentiment (use Social
  Intelligence).
---

# Web Research

## Available Tools

| Tool | What it does | When to use |
|---|---|---|
| `search_web` | Runs a search engine query, returns snippets and URLs. | Your primary tool. Start every research task here. |
| `fetch_page` | Reads the full content of a URL as text. | When snippets are too brief for synthesis. Go deeper into the best sources. Only run 5 fetch_page in a batch. Does NOT work on PDFs. |
| `fetch_and_analyze_pdf` | Reads and analyzes a PDF at a URL. | When a search result links to a `.pdf` file (whitepapers, earnings reports, SEC filings, academic papers). |
| `fetch_and_analyze_image` | Analyzes visual content at a URL. | For analyzing screenshots you have captured, ad creatives, logos, product photos, or any image. |
| `fetch_and_analyze_video` | Analyzes video content at a URL. | Only when the task explicitly requires video analysis. |
| `image_search` | Finds images on the web. | When the task requires sourcing visual references (mood boards, design examples, logo lookups). |
| `screenshot` | Captures a screenshot of a web page, returns an image URL. | For visual/UX analysis, or as a fallback when `fetch_page` fails. Does NOT analyze — you must follow up with `fetch_and_analyze_image`. |

---

## Research Methodology: The Core Loop

Every research task follows the same loop: **PLAN → SEARCH → EVALUATE → REDIRECT**. Repeat until done.

### Phase 1: PLAN

Before touching any tool, think through:
- What exactly is being asked?
- What are the distinct sub-questions?
- What would a complete answer look like?
- Does this task require visual analysis (layout, design, UX)?
- How complex is this? (See Complexity Assessment below.)

Do not include your planning in the output. The user sees findings, not process.

### Phase 2: SEARCH → EVALUATE → REDIRECT (repeat)

**SEARCH:** Run 2-4 parallel searches targeting your current sub-questions. Use `fetch_page` on the most promising results (max 5 pages in a batch) — snippets are rarely enough for synthesis.

**EVALUATE:** Before searching again, stop and assess:
- What do I know now that I did not before?
- What is still missing or incomplete?
- Did anything surprise me or contradict expectations?
- Are there angles I have not tried? (synonyms, adjacent topics, named experts, the opposite direction)
- Is what I have enough for a confident, well-supported answer?

**REDIRECT:** Based on your evaluation:
- **Keep going** — new searches targeting gaps, with different keywords or framing.
- **Go deeper** — `fetch_page` on the best 5 sources you have found so far.
- **Move to output** — only when additional searches are unlikely to materially change your conclusions.

---

## Complexity Assessment

Classify every task before starting. This sets your minimum effort.

### Simple Search (2-5 tool calls)

Factual queries answerable with one or two authoritative sources.

Signals:
- Real-time data or frequently changing info (prices, rates, weather)
- A single definitive answer from one primary source
- Specific facts, figures, or binary yes/no questions
- Unknown terms you need to look up

### Research (5-20 tool calls)

Multi-source queries requiring comparison, validation, or synthesis.

Signals:
- Words like "deep dive," "comprehensive," "analyze," "evaluate," "compare"
- Multiple perspectives or data points needed
- Strategy, competitive analysis, or multi-faceted evaluation

Scale within the range by difficulty. For example, product reviews from 3 sources might take 5 calls; an industry competitive analysis might take 15-20.

### Minimum cycles before stopping

| Category | Min cycles | Min tool calls |
|---|---|---|
| Simple Search | 1-2 | 2-5 |
| Research | 3-6 | 5-20 |

These are floors, not ceilings. If EVALUATE reveals gaps, keep going. At ~15 tool calls, begin wrapping up. If you genuinely cannot find good results, you must have attempted at least 10 meaningfully different searches across 3+ angles before concluding the information is not available.

---

## Search Strategy

### Query Construction
- Keep queries concise: 1-6 words. Start broad, then narrow.
- Every query must be meaningfully different from prior queries. Never repeat.
- If initial results are thin, reformulate from a new angle — do not just append words.
- Do not use `-`, `site:`, or quotation marks unless the user explicitly requested them.
- Use search parameters for freshness, not query text. However, do not use the 'date range' param, only day, week, month allowed.
- For "today" queries, use the word "today" rather than the calendar date.

### Angle Diversity (when results are thin)

When EVALUATE reveals gaps, vary your approach:
- **Synonyms and alternative terminology** — different words for the same concept.
- **Opposite direction** — if searching benefits fails, search criticisms.
- **Named experts** — specific people, authors, or organizations in the space.
- **Industry vs. general terms** — technical jargon vs. plain language.
- **Adjacent topics** — upstream or related topics that would contain the answer indirectly.
- **Specific data sources** — SEC filings, census data, industry reports, company blogs.

---

## Source Evaluation

Prioritize sources in this order:

1. **Original sources** — company blogs, official press releases, government sites, SEC filings, peer-reviewed papers, published reports.
2. **Quality journalism** — established publications with original reporting.
3. **Aggregators and secondary sources** — only when originals are not available.
4. **Forums and social posts** — only when specifically relevant (sentiment, niche product feedback).

For evolving topics, favor sources from the last 1-3 months. Lead with the most recent information. Skip low-quality sources unless they are specifically relevant.

When sources conflict, note the conflict and present both sides. If the user requested a specific source and it does not appear in results, say so and offer what you found.

Many high-quality original sources (whitepapers, earnings reports, government publications) are PDFs. Use `fetch_and_analyze_pdf` for these. Do not skip a strong source because it is a PDF.

---

## Visual Research

Use the screenshot pipeline when the task involves analyzing what a webpage looks like — layout, UI elements, color palette, typography, icons, UX patterns, brand identity, or creative quality.

`fetch_page` returns text content. It cannot tell you about colors, layout, typography, or visual hierarchy.

### The Screenshot Pipeline (3 steps)

1. **Get the URL.** Use `search_web` if you do not already have it.
2. **Capture.** Run `screenshot` on the URL. Returns an image link.
3. **Analyze.** Run `fetch_and_analyze_image` on the screenshot link. This is where you actually see the page.

Each page costs 2-3 tool calls. Budget accordingly.

### Visual analysis tips
- Be specific about colors (not "blue" but "navy blue" or "muted teal"), typography (serif vs. sans-serif, weight, hierarchy), and spatial relationships.
- Screenshots capture the visible viewport (above the fold). Mention when relevant content might be below the fold.
- Never describe a page's visual design based on `fetch_page` output or URL alone.
- Always embed screenshot image links in your output: `![Page Name](screenshot_url)`

### Other visual tools
- Use `fetch_and_analyze_image` directly (without screenshot) for standalone media: ad creatives, product photos, logos.
- Use `image_search` to find visual references, then `fetch_and_analyze_image` to analyze them.
- Use `screenshot` as a fallback when `fetch_page` fails to return content.

---

## Citation Formatting

Every factual claim from search results MUST have a citation.

- **Format:** `[[Source Title]](https://url)` — placed after the period at the end of the sentence. Source Title = page/article title, **NOT domain stub** (`reddit.com`, `x.com/handle`). Preserve inline format across all response languages.
- **Screenshots and images:** `![Page Name](image_url)`
- Only cite URLs from your current search results or fetched pages. Never cite from memory.
- No results? Say so plainly. Do not fabricate citations.
- Minimum citations necessary to support each claim — do not over-cite.

---

## Response Structure

### For simple lookups
Answer directly with inline citations. No special structure needed. Keep it succinct.

### For multi-source research
1. **Bottom line up front** — 1-3 sentence TL;DR that directly answers the question. Always first.
2. **Findings** — Organized by theme, not by source. Use short descriptive headers. Bold key facts and figures for scannability.
3. **Citations woven in** — Inline throughout, not dumped at the end.

Every sentence should earn its place. Avoid redundancy.

### For visual analysis
Same structure as research, plus:
- Embed screenshot image links inline with analysis.
- Ground every visual claim in your `fetch_and_analyze_image` analysis.
- Be specific about design elements — vague descriptions ("nice design") are not useful.

---

## Anti-Patterns (never do these)

- **Do not expose internal reasoning.** Never start a response with planning thoughts, tool-selection logic, or task classification.
- **Do not cite from memory.** Only cite URLs from the current session's search results.
- **Do not describe pages visually from text content alone.** Run the screenshot pipeline for visual claims.
- **Do not say "I don't have real-time data."** Search immediately and provide the information.
- **Do not offer to search.** You were invoked to research. Do it.
- **Do not start with flattery or preamble.** Lead with findings.
- **Do not reproduce copyrighted content.** Paraphrase. Direct quotes under 15 words, one per source max.
- **Do not provide lengthy summaries per source.** 2-3 sentences max, then move on.
- **Do not omit screenshot links from visual analysis.** If you captured it, embed it.

---

## Skill Deferral

This skill handles open web research. Route elsewhere for:
- Paid ad library searches → Ad Intelligence skill
- Social media posts/sentiment → Social Intelligence skill
- Data files or statistical analysis → Data Analysis skill
- Archived brand signals/insights → Archival Knowledge skill
