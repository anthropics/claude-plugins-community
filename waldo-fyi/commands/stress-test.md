---
name: stress-test
description: Adversarial evidence search — given a hypothesis or positioning, find the strongest reasons it could fail. Returns supporting evidence, contradicting evidence, and a defensibility verdict for pitch prep.
argument-hint: <hypothesis or positioning to stress-test>
allowed-tools: ["Skill"]
---

Load the waldo-fyi:web-research skill using the Skill tool.

**Hypothesis or positioning to stress-test:** $ARGUMENTS

Run an adversarial evidence search. Find:

1. **Top 3 supporting evidence** — strongest cited evidence FOR the hypothesis (research, surveys, expert positions, recent data).
2. **Top 3 contradicting evidence** — strongest cited evidence AGAINST. Actively hunt for counter-positions, opposing studies, recent reversals, dissenting expert voices, or trend lines that suggest the hypothesis is weakening or wrong. Use the Angle Diversity techniques (opposite direction, named experts, adjacent topics) to surface contradicting evidence that surface-level searches miss.
3. **Verdict** — one of: **DEFENSIBLE** (supporting evidence materially outweighs contradicting), **CONTESTED** (roughly balanced, frame as a live debate), or **WEAK** (contradicting evidence materially outweighs supporting).
4. **Pitch-prep notes** — the 1–2 sharpest objections a skeptical client would raise, and how to acknowledge them.

This is for pitch prep, positioning decisions, and trend-bet stress tests. Strategists use this to anticipate "but what if you're wrong?" before a client meeting. Be ruthless on the contradicting side — finding nothing means searching wrong, not that no counter-evidence exists. Cite every claim.

If no hypothesis is specified above, ask the user for the thesis or positioning to stress-test before invoking the skill.
