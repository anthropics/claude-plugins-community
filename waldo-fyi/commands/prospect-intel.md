---
name: prospect-intel
description: Cold new-business prospect research — company snapshot, org-chart map, executive profile, agency relationships, and outreach hooks for BD/growth leads.
argument-hint: <company or executive name>
allowed-tools: ["Skill"]
---

Load the waldo-fyi:web-research skill using the Skill tool.

**Prospect to research:** $ARGUMENTS

Produce:

1. **Company snapshot** — who they are, what they sell, recent financial signals from filings (10-K/10-Q), market position.
2. **Org-chart map** — marketing/comms leadership, reporting lines, recent hires and departures.
3. **Executive profile** (if a named person) — public moves, podcast/panel appearances, stated priorities, motivations inferable from public commentary or writing.
4. **Agency relationships** — current AOR, recent reviews, last review cycle.
5. **Signals** — anything uncommon worth a cold-outreach hook.

If no prospect is specified above, ask the user for the company or executive name before invoking the skill.
