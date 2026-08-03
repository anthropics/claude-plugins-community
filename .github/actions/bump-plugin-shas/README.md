# bump-plugin-shas

Nightly bot-free SHA refresh for external marketplace entries. Companion to
[`validate-plugins`](../validate-plugins/).

## What it does

1. For each external entry in `marketplace.json`, resolves the upstream tracking
   target — `git ls-remote <url> HEAD` by default, or the commit of the latest
   published GitHub release for entries flagged `releases-only` in
   `tracking-config` — and compares against the pinned `sha`.
2. For each stale entry (up to `max-bumps`): clones at the **new** SHA and runs
   `claude plugin validate` on it — the same check `validate-plugins` step 30
   would run.
3. Entries that pass are updated in `marketplace.json`; entries that fail
   validation are skipped and listed in the run summary.
4. Commits all passing bumps to `pr-branch`, pushes, and opens/updates a single
   PR. The PR body links back to this workflow run as the validation evidence.

## Why no bot

PRs opened by the default `GITHUB_TOKEN` do not trigger `on: pull_request`
workflows (GitHub's recursion guard). Rather than use a GitHub App to work
around that, this action **runs the validation inline before opening the PR**,
so the bump workflow run itself is the CI evidence. The consuming workflow
needs only `permissions: {contents: write, pull-requests: write}` — no app
install, no secrets beyond the default token.

## Usage

> **Always pin to a commit SHA, never `@main`.** See `../validate-plugins/RELEASING.md`.

```yaml
# .github/workflows/bump-plugin-shas.yml
name: Bump Plugin SHAs
on:
  schedule:
    - cron: '23 7 * * *'
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  bump:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-plugins-community/.github/actions/bump-plugin-shas@<PINNED-SHA>
        with:
          marketplace-path: .claude-plugin/marketplace.json
          max-bumps: 20
          # optional: entries that track release tags instead of HEAD
          tracking-config: .github/bump-tracking.json
```

With `tracking-config` set, the named file (committed in the caller repo) looks
like:

```json
{"releases-only": ["some-plugin", "another-plugin"]}
```

## Inputs

| Input | Default | |
|---|---|---|
| `marketplace-path` | `.claude-plugin/marketplace.json` | |
| `max-bumps` | `20` | cap per run |
| `allowed-hosts` | `github.com gitlab.com bitbucket.org` | same SSRF allowlist as validate-plugins |
| `sha-exempt` | `""` | deliberately-unpinned plugin names to skip (else nightly re-pins them); same list as validate-plugins |
| `freeze-shas` | `""` | PINNED plugin names to hold at their current `source.sha` (skip the bump) — e.g. a security freeze pending an upstream fix-forward. Distinct from `sha-exempt`: a frozen entry keeps its sha, an exempt one has none. Remove the name to resume bumping. A listed name that matches no pinned entry — or whose name is outside `[a-z0-9-]{2,64}` — is surfaced as a workflow `::warning` (the pin is **not** protected), so a typo'd freeze can't fail silently. |
| `tracking-config` | `""` | optional path to a JSON tracking-policy file in the caller's checkout (resolved from the workspace root, `$GITHUB_WORKSPACE`), `{"releases-only": ["name", ...]}`. Listed entries bump to the **commit the latest published GitHub release's tag currently points at** (`releases/latest` — non-draft/non-prerelease only; annotated tags dereferenced; the release is the *source repo's* latest, so for a `path:` subdir entry that is the whole repo's release). **github.com sources only** — a flagged gitlab/bitbucket entry is skipped with a warning and its pin never advances. No published release (HTTP 404) → the pin is held quietly (recorded in `skipped`); any other lookup failure (rate limit, transport — reads use `github-token`) → a loud per-entry skip naming the HTTP status. Note: a private/renamed upstream returns a *masked* 404, indistinguishable from no-releases, and is held quietly. Bumps are **forward-only**: a "latest" release not ahead of the current pin (chronological back-patch, deleted release) is refused. `freeze-shas` takes precedence — a name in both lists stays frozen. Distinct from `freeze-shas` (a hard hold): releases-only still auto-bumps, gated on the developer cutting a release. A listed name matching no pinned entry warns (typo — or the entry's add-PR hasn't merged yet, which is harmless). A path that is SET but missing/malformed **fails the whole run** (unlike `freeze-shas`, whose misconfigurations only warn) — wire the file and the input in the same PR. Empty (default) = every entry HEAD-tracks, exactly as if this input did not exist. |
| `claude-cli-version` | `latest` | **pin in your workflow** |
| `npm-registry` | `""` | optional internal mirror |
| `pr-branch` | `bump/plugin-shas` | |
| `base-branch` | repo default branch | |
| `github-token` | `${{ github.token }}` | |

## Outputs

| Output | |
|---|---|
| `bumped` | JSON array of `{name, old_sha, new_sha}` |
| `skipped` | JSON array of `{name, reason}` |
| `pr-url` | URL of the bump PR (empty if nothing to bump) |

## Security

Same posture as `validate-plugins` step 30: contributor-controlled `url`/`path`
are validated against the host allowlist and metachar blocklist before any
shell use, all interpolations are quoted with `--` markers, the clone target
path is index-derived (never name-derived), and only `claude plugin validate`
runs against cloned content — no code execution.
