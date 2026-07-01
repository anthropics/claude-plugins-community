# Maintenance and validation

## When to update

Update verified record sections only when a real-world fact is verifiable, such as:

- a confirmed grade
- a completed project with a deliverable
- a role that has actually started
- a certification with a real score or ID
- a published result, paper, ranking, or award

Do not add speculative future entries to the verified record. Store aspirations, target roles, growth direction, emerging interests, and claims to avoid in `Goals and targeting` as stated intent.

## Safe integration workflow

1. Identify the target section using the canonical tags and section order.
2. Draft only the new or revised entry in the required format.
3. Update the `VERIFIED FACTS` comment if the material adds dates, grades, scores, IDs, rankings, or other hard anchors.
4. Check whether the material evidences a new skill that belongs in the Skills index.
5. If the material changes future direction, update `Goals and targeting` and keep evidence boundaries explicit.
6. Apply the smallest edit that preserves the rest of the file untouched.

## Validation checklist

A valid context file should satisfy all of the following:

- exactly one H1 title with full name and positioning descriptor
- `QUICK REFERENCE` appears immediately after the title
- the QUICK REFERENCE block is YAML and uses only flat values or flat arrays
- `Goals and targeting` appears after QUICK REFERENCE unless intentionally declined
- career-direction fields are stated intent and remain outside the `VERIFIED FACTS` comment
- growth direction, emerging interests, evidence boundaries, positioning constraints, and claims to avoid are present when the user is repositioning across domains
- required sections are present: scope declaration, education, skills index, languages
- conditional sections appear only when the user has relevant content
- semantic tags are used consistently: `[DEGREE]`, `[COURSE]`, `[PROJECT]`, `[THESIS]`, `[ROLE]`, `[PAPER]`, `[PREPRINT]`, `[CERT]`, `[COMPETITION]`, `[AWARD]`, `[ORG]`
- every `[PROJECT]`, `[THESIS]`, `[COMPETITION]`, and `[ROLE]` entry has a meaningful `TL;DR` when the format requires one
- the Skills index contains only skills supported elsewhere in the file
- the `VERIFIED FACTS` comment exists and covers the hard facts in the body
- dates, titles, metrics, and chronology are internally consistent

## Token-growth rules

- Keep the QUICK REFERENCE block current and selective.
- Preserve the historical record in the body.
- Compress peripheral detail instead of deleting important evidence.
- Remove stale items from `top_skills` or the QUICK REFERENCE `professional` snapshot when they are no longer central to current positioning.
- Keep source ledgers grouped by input type or file. Expand provenance only for conflicts, hard factual anchors, or claims likely to be reused in public copy.

## Editing posture for agents

- Prefer targeted diffs over whole-file rewrites.
- Do not silently normalize conflicting facts; surface the conflict.
- Do not add unsupported skills just because they would sound useful.
- If the file is structurally broken, repair structure first, then improve wording.
