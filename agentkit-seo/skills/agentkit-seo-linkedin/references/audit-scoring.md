# LinkedIn audit score

## Purpose and limits

This rubric turns a LinkedIn audit into a single triage number so the user can see where to spend effort first. It is an internal prioritization heuristic, not a LinkedIn metric, a ranking prediction, or a guarantee. LinkedIn does not publish a profile score, and its ranking systems are partly disputed; categories and weights below reflect this skill's documented guidance, not any internal LinkedIn system.

Use it only when the user asks for a score, a scorecard, or a before/after comparison. Otherwise the standard audit output is enough.

Rules:

- Score only categories you actually inspected. Mark uninspected categories as `Needs inspection` and exclude them from the total, then rescale the remaining weights to 100.
- Keep every category score tied to observed evidence, using the same evidence and confidence labels as the rest of this skill.
- Never present the number as a LinkedIn ranking, reach, or visibility guarantee.

## Categories and weights

| Category | Weight | What it measures | Reference |
| --- | --- | --- | --- |
| Headline | 20 | role clarity, keywords, and positioning in the headline | [positioning-and-structure.md](positioning-and-structure.md) |
| About section | 20 | first-person narrative, proof, and readable structure | [positioning-and-structure.md](positioning-and-structure.md) |
| Experience, skills, and featured proof | 20 | aligned experience entries, relevant skills, and proof-of-work | [section-recipes.md](section-recipes.md) |
| Discoverability and activity | 15 | searchable terms and documented activity signals | [discoverability-and-activity.md](discoverability-and-activity.md) |
| Profile architecture and settings | 10 | custom URL, badges, location, and completeness | [profile-audit-and-maintenance.md](profile-audit-and-maintenance.md) |
| AI-readable structure and consistency | 15 | clean titles, skill names, and alignment with other surfaces | [profile-audit-and-maintenance.md](profile-audit-and-maintenance.md) |

If a category cannot be inspected (for example, login-gated sections), exclude it and rescale the remaining weights to 100.

## Scoring each category

Score each category from 0 to 100 percent of its weight using the linked reference checklist. Partial credit is expected: award proportional points for items present, and subtract for documented gaps. Round the weighted total to a whole number.

## Bands

- 85 to 100: `Excellent` - clear, evidence-backed, dual-audience profile.
- 70 to 84: `Good` - solid with a few targeted fixes.
- 50 to 69: `Foundation` - the basics exist but key sections are generic.
- Below 50: `Critical` - the profile does not yet communicate the user's value.

## Output

When a score is requested, return:

1. overall score and band
2. per-category breakdown: `score / weight` plus one evidence-backed reason
3. `Fix first`: the categories ranked by weight multiplied by the gap to full marks, so the highest-leverage fixes lead
4. `Informational`: diagnostic observations that did not affect the score, including any ranking-dependent advice labeled by confidence
5. a one-line confidence note and a `Depth note` listing any categories marked `Needs inspection`

Keep the breakdown compact. The score exists to rank actions, so always pair it with the specific rewrites from the rest of this skill.
