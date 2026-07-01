# Personal career context file specification and structure

## Required shape

The personal career context file is one Markdown document with a fixed, stable structure.

Recommended portable location when the user wants a reusable path:

```text
~/.agentkit-seo/<name-surname>-seo-context.md
```

This path is a convention, not a requirement. An explicit path supplied by the user always wins. A local workspace draft such as `./<name-surname>-seo-context.md` is also valid when the user wants to iterate inside the active project before moving the file to a private reusable location.

Required, recommended, and conditional sections, in order:

1. H1 with full name and positioning descriptor
2. `QUICK REFERENCE` section as YAML in a fenced block
3. goals and targeting if the user has not declined it
4. scope declaration
5. education
6. professional experience if any
7. research and publications if any
8. skills index
9. certifications and achievements if any
10. languages
11. extracurricular and leadership if any

Do not move required sections for style reasons. The stable order is part of the interface the agent relies on.

## Title rule

Use one H1 in this form:

```markdown
# Full Name - positioning descriptor
```

The descriptor should express current positioning, not merely the current job title.

## QUICK REFERENCE rules

- place it immediately after the title
- write it as YAML under an H2 heading labeled `QUICK REFERENCE`
- keep values flat
- omit empty fields instead of using `null`
- list target roles, top skills, tools, and public links
- treat it as the current positioning snapshot, not as full history
- keep it selective: highest-signal current roles, skills, tools, credentials, and links only

Recommended fields:

- `name`
- `current_location`
- `positioning_summary`
- `target_roles`
- `growth_direction`
- `emerging_interests`
- `evidence_boundaries`
- `positioning_constraints`
- `claims_to_avoid`
- `open_to_relocation`
- `target_locations`
- `work_mode`
- `ideal_role`
- `current_focus`
- `want_to_work_on_next`
- `interests`
- `education`
- `gpa_summary`
- `professional`
- `top_skills`
- `tools`
- `competitions`
- `certifications`
- `languages`
- public profile links such as `github`, `linkedin`, and `portfolio`

## Goals and targeting rules

Place `## Goals and targeting` immediately after the `QUICK REFERENCE` block unless the user explicitly declines future-direction capture.

This section records stated intent, not verified history:

- ideal role or dream job
- current focus
- what the user wants to work on next
- target roles
- target locations, relocation stance, and work mode
- growth direction
- professional and personal interests
- evidence boundaries
- positioning constraints
- claims to avoid

Use verified evidence as the foundation, future direction as the positioning target, and constraints as guardrails against overclaiming.

Keep this section outside the `VERIFIED FACTS` comment. If a direction has partial evidence, state the evidence level explicitly, such as "verified through project X", "current practical exposure", or "target development area".

Write `No restriction` where the user has no constraint rather than leaving an ambiguous blank.

## Scope declaration rules

The scope declaration is one short third-person paragraph stating:

- what the file is
- what it is not
- what it is for

Close it with a `VERIFIED FACTS` HTML comment for atomic facts that must not be guessed.

## Body rules

- use stable section tags like `[DEGREE]`, `[COURSE]`, `[PROJECT]`, `[THESIS]`, `[ROLE]`, `[PAPER]`, `[PREPRINT]`, `[CERT]`, `[COMPETITION]`, `[AWARD]`, and `[ORG]` when relevant
- include `TL;DR` lines where the structure requires them
- keep project technologies and outcomes explicit
- keep the skills index evidence-backed; each listed skill should be supported somewhere else in the file
- write role detail as concise quantified bullets rather than narrative blocks
- write the languages section as a table rather than prose
- add a short `Source:` or `Evidence:` line only for entries whose facts may be reused downstream and are not obvious from nearby hard anchors

## Minimal entry patterns

- Degrees: `## [DEGREE] ...` plus one sentence on focus and relevance
- Courses: `#### [COURSE] ...` plus a flat `Topics:` line
- Projects: `##### [PROJECT] ...` plus required `TL;DR`, `Description`, `Technologies`, `Key areas`, and `Results`
- Thesis: `### [THESIS] ...` plus `Full title`, `Supervisors`, `Research area`, and `TL;DR`
- Roles: `### [ROLE] ...` plus `TL;DR` and evidence-rich bullets
- Papers/preprints: `### [PAPER] ...` or `### [PREPRINT] ...` plus `TL;DR`

## Integrity rule

Keep a `VERIFIED FACTS` comment in the scope declaration for atomic facts that must not be guessed:

- dates
- grades
- scores
- IDs
- rankings
- other hard factual anchors

## Validation mindset

When validating an existing file, check structure first, then chronology, then evidence backing. A polished file with weak factual anchors is still invalid.
