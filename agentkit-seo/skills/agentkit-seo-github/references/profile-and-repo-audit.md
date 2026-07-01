# GitHub profile and repository audit

## Audit workflow

1. confirm the user's target role, stack, or public positioning
2. create a source ledger before making claims
3. review native profile fields first
4. review pinned repositories and profile README
5. review showcase repositories for metadata, README quality, and trust signals
6. review searchability and language-stat integrity
7. separate blocking issues from optional improvements

Default scope:

- Profile audit: inspect the profile, profile README, pinned repositories, and up to 3 highest-signal repositories unless the user requests a full audit.
- Repository audit: inspect that repository only unless cross-profile positioning is requested.
- Full audit: expand beyond the default scope only when the user explicitly asks for every repository or a complete inventory.
- If a finding would require broader inspection, label it as `Needs inspection` and keep the current answer bounded.

## Source ledger

Track where each important claim comes from:

- `Verified`: visible on the public GitHub profile, repository page, README, topics, language bar, or fetched file.
- `From context`: supplied by the user's local context file, resume, notes, screenshots, or pasted text.
- `Inference`: a recommendation or judgment based on the inspected material.
- `Inaccessible`: private repositories, account settings, contribution details, social preview settings, analytics, or organization-only material that tools cannot inspect.

Rules:

- Do not convert `From context` claims into `Verified` claims unless they were observed in public GitHub material.
- Do not present missing data as a defect when it may be inaccessible. Say what could not be checked.
- If a recommendation depends on unverified context, name the dependency before giving copy.
- Avoid vague confidence labels. Explain the reason for confidence in one short sentence.
- Keep the ledger short. Use grouped entries such as `profile page`, `profile README`, `pinned repositories`, `top 3 repository pages`, and `local context file`.

## Profile checklist

Check the following:

- username consistency with other public surfaces when relevant
- bio clarity and keyword usefulness
- website field populated
- pinned repositories curated intentionally
- contribution visibility settings match the user's public goals
- profile README adds real context instead of filler

## Repository checklist

For each showcase repository, check:

- public visibility if public discovery is the goal
- default branch health
- descriptive repository name
- About text filled
- useful topic tags
- real README with quickstart and evaluation path
- social preview image for showcase repos when worthwhile
- trust files such as LICENSE, SECURITY.md, or CI signals when appropriate

## Search and stats checklist

- the repository is not archived if search visibility matters
- large generated, vendored, documentation, or data files are not skewing language stats
- `.gitattributes` overrides are semantically correct
- forks are not being treated as strong portfolio anchors without considering GitHub's fork-search limits

Do not recommend a broad `.gitattributes` patch from the profile page alone. Inspect repository files first, or present the patch as a candidate that the user must verify against the real file roles.

## Agent and Copilot readiness checklist

- `.github/copilot-instructions.md` exists when repo-wide guidance is needed
- path-specific instruction files exist only where they add real value
- `AGENTS.md` files are concise and non-conflicting
- architecture, setup, and validation docs are easy to find

Recommend agent-readiness files only when they fit the repository. Strong reasons include an AI-facing tool, complex setup, multi-agent workflows, reusable development conventions, or the user's explicit request. For normal portfolio repositories, prioritize README, About text, topics, pinned repos, and social preview before suggesting agent files.

## Maintenance rules

- keep pinned repositories aligned with current positioning
- refresh README copy when the project scope or maturity changes
- rotate stale showcase repos out when stronger work exists
- avoid duplicating conflicting source-of-truth docs

## Output format for audits

When auditing GitHub presence, organize findings into:

1. source ledger
2. factual or structural issues
3. discoverability improvements
4. trust and proof-of-work improvements
5. agent-readiness improvements, only when relevant

For each high-priority issue, include:

- `Evidence`: what was observed and where it came from
- `Why it matters`: the practical effect on readers or discovery
- `Change`: the exact edit, copy, metadata, or file action

Keep audits short by default:

- 3 to 7 priority issues
- only the copy blocks the user can apply now
- one-line confidence notes
- next actions limited to the next 3 to 5 moves
- one `Depth note` when the audit did not inspect every relevant repository or file

## Claim discipline

Avoid unsupported statements such as:

- exact ranking or Explore-feed mechanics unless they come from documented GitHub behavior
- achievement percentiles unless the user provides the competition size or official ranking context
- vulnerability severity, exploitability, or confirmation status unless visible in public material or supplied by trusted context
- claims that something is pinned, missing, archived, licensed, or CI-backed unless inspected

When strong context exists but GitHub does not show it clearly, frame the issue as a packaging gap: the user's strongest proof is not visible enough on GitHub.
