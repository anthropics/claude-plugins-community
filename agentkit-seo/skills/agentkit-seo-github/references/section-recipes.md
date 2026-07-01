# GitHub section recipes

## Profile bio recipe

Use the 160-character bio as a compact role summary:

```text
Role | Stack | Location or Remote
```

Rules:

- lead with the clearest current or target role
- include only the most central technologies
- keep the website in the dedicated Website field, not in the bio
- avoid quotes, jokes, or vague lifestyle phrasing when discoverability matters

## Pinned repository recipe

Pin 4 to 6 repositories.

Choose repositories that are:

- finished or meaningfully usable
- documented
- representative of the target stack or domain
- varied enough to show range without diluting positioning

Avoid pinning:

- trivial exercises
- undocumented repos
- dead forks
- stale work that no longer represents the user's goals

## Profile README recipe

Recommended flow:

1. short heading or opener with role and focus
2. compact summary paragraph with primary keywords early
3. stack or capability section
4. featured projects or links
5. optional contact or collaboration section

Rules:

- keep the strongest keywords in the first paragraph
- use real Markdown headings rather than bold pseudo-headings
- keep dynamic cards secondary to plain Markdown content
- do not let visual badges replace actual explanation

## Repository README recipe

Put the following near the top:

1. what the project is
2. why it exists or who it is for
3. quickstart or installation
4. key architecture or design notes for showcase repos
5. proof of maintenance when relevant

Rules:

- make setup friction low
- explain evaluation paths, not just features
- include architecture and constraints when the project is non-trivial
- keep examples and claims grounded in the actual repository

## About text and topics recipe

About text:

- short, concrete, front-loaded with the core concept
- answer what it is, and when useful, who it is for
- avoid vague phrases like `personal project` when stronger description exists

Topic tags:

- include core language or framework
- include architectural pattern when accurate
- include industry, domain, or use-case tags when accurate
- prefer relevant tags over maxing the list for its own sake

## Rewrite posture

- preserve facts and sharpen packaging
- when evidence is weak, say what documentation or structure is missing
- keep the same repository positioning across name, About text, README, and topics
- write credible technical copy before writing promotional copy
- avoid adjectives like `elite`, `top-tier`, `world-class`, or `top-1%` unless the user provides verifiable evidence
- keep security, research, and vulnerability claims precise; do not amplify impact beyond the supplied evidence

## Audit copy pattern

When turning an audit into user-facing output, prefer:

```text
Evidence: <verified/context/inferred observation>
Why it matters: <reader, recruiter, maintainer, or search effect>
Change: <exact copy, metadata, README edit, or next action>
```

Use short ready-to-apply blocks for:

- profile bio
- repository About text
- topic tags
- pinned repository ordering
- README section snippets

Before recommending an `AGENTS.md`, ask whether the repository actually needs agent-facing instructions. If the repository is not agent-facing, suggest README and metadata improvements first.
