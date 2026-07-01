---
name: news-digest
description: Weekly digest of significant news, signals, and brand mentions for a brand or topic — what mattered, why it matters, what to watch next. Synthesis, not a feed dump.
argument-hint: <brand or topic>
allowed-tools: ["Skill"]
---

Load the waldo-fyi:archival-knowledge skill using the Skill tool.

**Brand or topic for digest:** $ARGUMENTS

Produce a digest, NOT a feed dump. Structure:

1. The 3 things that matter this week, ranked by significance.
2. Per item: what happened, why it matters for this brand, sources.
3. What to watch next week.

Pull from Brand Mentions, Category News, Owned Media, Trending Topics, and From Management feeds. Apply the published-status filter and keep results focused.

If no brand or topic is specified above, ask the user what to digest before invoking the skill.
