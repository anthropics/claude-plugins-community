# GitHub audit score

## Purpose and limits

This rubric turns a GitHub audit into a single triage number so the user can see where to spend effort first. It is an internal prioritization heuristic, not a platform metric, a ranking prediction, or a guarantee. GitHub does not publish a profile score; categories and weights below reflect this skill's documented guidance, not any internal GitHub system.

Use it only when the user asks for a score, a scorecard, or a before/after comparison. Otherwise the standard audit output is enough.

Rules:

- Score only categories you actually inspected. Mark uninspected categories as `Needs inspection` and exclude them from the total, then rescale the remaining weights to 100.
- Keep every category score tied to observed evidence, using the same `Verified`, `From context`, `Inference`, and `Inaccessible` labels as the rest of this skill.
- Never present the number as a GitHub ranking or visibility guarantee.

## Categories and weights

| Category | Weight | What it measures | Reference |
| --- | --- | --- | --- |
| Profile identity and bio | 20 | bio clarity, keyword usefulness, website field, name consistency | [profile-and-repo-structure.md](profile-and-repo-structure.md) |
| Pinned repositories and proof selection | 20 | whether pins show the strongest, most relevant work | [profile-and-repo-audit.md](profile-and-repo-audit.md) |
| Repository README and About quality | 20 | descriptions, README openings, quickstart and evaluation paths | [section-recipes.md](section-recipes.md) |
| Discoverability: topics, naming, language signals | 20 | topic tags, repo names, Linguist and `.gitattributes` accuracy | [search-indexing-and-linguist.md](search-indexing-and-linguist.md) |
| Agent-readiness | 10 | `AGENTS.md` and Copilot instructions, only when the repo is agent-facing | [copilot-and-agent-readiness.md](copilot-and-agent-readiness.md) |
| Cross-surface consistency | 10 | alignment with the context file and other public surfaces | [profile-and-repo-audit.md](profile-and-repo-audit.md) |

If a category does not apply (for example, agent-readiness for a simple portfolio repository), exclude it and rescale the remaining weights to 100.

## Scoring each category

Score each category from 0 to 100 percent of its weight using the linked reference checklist. Partial credit is expected: award proportional points for items present, and subtract for documented gaps. Round the weighted total to a whole number.

## Bands

- 85 to 100: `Excellent` - strong, consistent, discoverable presence.
- 70 to 84: `Good` - solid with a few targeted fixes.
- 50 to 69: `Foundation` - the basics exist but key signals are missing.
- Below 50: `Critical` - the presence does not yet communicate the user's value.

## Output

When a score is requested, return:

1. overall score and band
2. per-category breakdown: `score / weight` plus one evidence-backed reason
3. `Fix first`: the categories ranked by weight multiplied by the gap to full marks, so the highest-leverage fixes lead
4. `Informational`: diagnostic observations that did not affect the score
5. a one-line confidence note and a `Depth note` listing any categories marked `Needs inspection`

Keep the breakdown compact. The score exists to rank actions, so always pair it with the specific next changes from the rest of this skill.
