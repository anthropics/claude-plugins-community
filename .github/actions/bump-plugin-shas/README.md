# bump-plugin-shas

Nightly bot-free SHA refresh for external marketplace entries. Companion to
[`validate-plugins`](../validate-plugins/).

## What it does

1. For each external entry in `marketplace.json`, runs `git ls-remote <url> HEAD`
   and compares against the pinned `sha`.
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
```

## Inputs

| Input | Default | |
|---|---|---|
| `marketplace-path` | `.claude-plugin/marketplace.json` | |
| `max-bumps` | `20` | cap per run |
| `allowed-hosts` | `github.com gitlab.com bitbucket.org` | same SSRF allowlist as validate-plugins |
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
