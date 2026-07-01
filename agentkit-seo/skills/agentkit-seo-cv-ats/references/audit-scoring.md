# CV and ATS audit score

## Purpose and limits

This rubric turns a CV audit into a single triage number so the user can see where to spend effort first. It is an internal prioritization heuristic, not a vendor ATS score, a parser-pass guarantee, or a hiring prediction. Applicant tracking systems differ and do not share scoring formulas; categories and weights below reflect this skill's documented parser-safety and readability guidance, not any specific vendor's algorithm.

Use it only when the user asks for a score, a scorecard, or a before/after comparison. Otherwise the standard audit output is enough.

Rules:

- Score only categories you actually inspected. Mark uninspected categories as `Needs inspection` and exclude them from the total, then rescale the remaining weights to 100.
- Keep every category score tied to observed evidence and never invent vendor-specific scoring.
- Never present the number as a guaranteed ATS pass or interview outcome.

## Categories and weights

| Category | Weight | What it measures | Reference |
| --- | --- | --- | --- |
| Parser safety and formatting | 25 | machine-readable layout, fonts, columns, headers, and file form | [parser-risks-and-agent-workflow.md](parser-risks-and-agent-workflow.md) |
| Core sections and order | 20 | expected sections present and ordered for the target role | [structure-and-formatting.md](structure-and-formatting.md) |
| Keyword and job-description alignment | 20 | relevant, truthful keyword coverage against the target role | [keywords-and-bullets.md](keywords-and-bullets.md) |
| Achievement bullets and evidence | 20 | outcome-focused, quantified, verifiable bullets | [keywords-and-bullets.md](keywords-and-bullets.md) |
| Consistency and pitfalls avoided | 15 | dates, tense, naming, and common parser pitfalls | [cv-audit-and-maintenance.md](cv-audit-and-maintenance.md) |

## Scoring each category

Score each category from 0 to 100 percent of its weight using the linked reference checklist. Partial credit is expected: award proportional points for items present, and subtract for documented gaps. Round the weighted total to a whole number.

## Bands

- 85 to 100: `Excellent` - parser-safe, targeted, and evidence-backed.
- 70 to 84: `Good` - solid with a few targeted fixes.
- 50 to 69: `Foundation` - readable but under-targeted or thin on proof.
- Below 50: `Critical` - parser or evidence problems likely block the CV.

## Output

When a score is requested, return:

1. overall score and band
2. per-category breakdown: `score / weight` plus one evidence-backed reason
3. `Fix first`: the categories ranked by weight multiplied by the gap to full marks, so the highest-leverage fixes lead
4. `Informational`: diagnostic observations that did not affect the score
5. a one-line confidence note and a `Depth note` listing any categories marked `Needs inspection`, for example when only extracted text was available

Keep the breakdown compact. The score exists to rank actions, so always pair it with the specific edits from the rest of this skill.
