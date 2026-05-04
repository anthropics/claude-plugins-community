# validate-plugins

Canonical CI validation for Claude plugin marketplace repositories. One composite
action that runs every check, designed to be dropped into any `*-plugins` repo
unchanged.

## Design: zero schema maintenance

The source of truth for the marketplace/plugin schema is the Zod definition
inside `@anthropic-ai/claude-code`. This action installs that package fresh on
every run and uses `claude plugin validate` as the canonical correctness check
(step 20). There is **no vendored or fetched JSON Schema** to keep in sync.

On top of canonical correctness, step 11 applies a static set of
**security/policy invariants** (I1–I9) that are intentionally stricter than the
canonical schema. These do not track upstream — they are this org's policy floor.

| Layer | Step | Tracks upstream? |
|---|---|---|
| Canonical schema | 20: `claude plugin validate` | Yes — fresh CLI install each run |
| Security/policy | 11: invariants I1–I9 | No — static by design |
| Per-plugin quality | 30/40/41: clone/validate/aux-parse | Yes — uses same CLI |

## What it checks

| Step | Scope | Check |
|---|---|---|
| **11 invariants** | full marketplace | I1–I9 hardening rules (sort, dups, desc bounds, https-only, SHA-pin required, filename match, no-direct-edit, vendored-path-exists, no shell metacharacters) |
| **20 cli-marketplace** | full marketplace | `claude plugin validate <marketplace.json>` — the canonical schema check |
| **30 cli-external** | changed entries (or all, if `validate-all-external`) | clone each external plugin at its pinned SHA, run `claude plugin validate` |
| **40 cli-local** | changed folders | `claude plugin validate` on each in-repo plugin folder the PR touched |
| **41 aux-files** | changed folders | JSON-parse `.mcp.json` / `.lsp.json` / `hooks/hooks.json` (runtime always-probes these; malformed = crash) |

Steps 11/20 always run on the full file. Steps 30/40/41 are diff-gated for fast
PR CI; step 30 has an `validate-all-external` mode for nightly drift detection.

## Usage

> **Always pin to a commit SHA, never `@main`.** See [RELEASING.md](RELEASING.md).

### PR validation

```yaml
# .github/workflows/validate-plugins.yml
name: Validate Plugins
on:
  pull_request:
    paths:
      - '.claude-plugin/**'
      - 'plugins/**'
      - '*/.claude-plugin/**'
      - '*/agents/**'
      - '*/skills/**'
      - '*/commands/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-plugins-community/.github/actions/validate-plugins@<PINNED-SHA>
        with:
          marketplace-path: .claude-plugin/marketplace.json
```

### Nightly drift detection

Catches external repos that were deleted or force-pushed past their pinned SHA.

```yaml
# .github/workflows/validate-plugins-nightly.yml
name: Validate Plugins (nightly drift check)
on:
  schedule:
    - cron: '23 7 * * *'
  workflow_dispatch:

jobs:
  drift:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-plugins-community/.github/actions/validate-plugins@<PINNED-SHA>
        with:
          validate-all-external: "true"
          skip-local-folders: "true"
```

### Per-file repos

Repos that store one entry per file (e.g. `.claude-plugin/plugins/<name>.json`):

```yaml
        with:
          marketplace-path: .claude-plugin/marketplace.json
          entries-dir: .claude-plugin/plugins
```

## Inputs

| Input | Default | Notes |
|---|---|---|
| `marketplace-path` | `.claude-plugin/marketplace.json` | |
| `entries-dir` | `""` | set for per-file repos; enables I6/I7 |
| `base-ref` | PR base / push `before` / `origin/main` | diff base for change detection |
| `warn-invariants` | `"I1 I3 I5 I8"` | invariant codes treated as WARN instead of ERROR |
| `skip-external` | `false` | disable step 30 |
| `skip-local-folders` | `false` | disable steps 40/41 |
| `fail-on-warnings` | `false` | treat warnings as failures (steps 11/20/40) |
| `validate-all-external` | `false` | step 30 scans all external entries (nightly drift) |
| `claude-cli-version` | `latest` | **Consumers MUST pin a version** and let renovate/dependabot bump it. `latest` is the fallback only. |
| `external-timeout-secs` | `120` | per-plugin clone+validate timeout |
| `allowed-hosts` | `github.com gitlab.com bitbucket.org` | SSRF allowlist for clone hosts |
| `npm-registry` | `""` | optional internal npm mirror |

## Outputs

| Output | |
|---|---|
| `changed-entries` | JSON array of entry names |
| `changed-external` | JSON array of `{name, source}` |
| `changed-folders` | JSON array of folder paths |
| `result` | `pass` / `fail` |
| `report-path` | markdown report path |

## Invariants reference

Shape-agnostic: applied to whichever fields are present on `source`, so new
source kinds added by the CLI are hardened automatically.

| # | Rule |
|---|---|
| I1 | `plugins[]` is alpha-sorted by `name` |
| I2 | No duplicate `name` values |
| I3 | `description` is 10–2000 chars, no leading/trailing whitespace |
| I4 | `source.url`/`source.repo` matches `^https://[A-Za-z0-9./_-]+$` or `owner/repo` |
| I5 | Every external source has a 40-char lowercase hex `sha` |
| I6 | (per-file) `plugins/<x>.json` has `.name == "x"` |
| I7 | (per-file) PR does not edit assembled `marketplace.json` directly |
| I8 | Vendored `source` path exists and contains `.claude-plugin/plugin.json` |
| I9 | All string fields under `source` contain no shell metacharacters |
| I10 | `name`/`description` contain no hidden-Unicode (zero-width, BOM, bidi controls) |
| I11 | `name` matches `^[a-z0-9][a-z0-9-]{1,63}$` |

## Security model

- External plugin validation (step 30) clones into an isolated temp directory,
  checks out the exact pinned SHA, and runs only `claude plugin validate`
  (a static manifest check). **No code from the cloned repo is executed.**
- **SSRF guard:** before any clone, the URL host is checked against
  `allowed-hosts`. Bare IP addresses are always rejected.
- All contributor-controlled values (`url`, `repo`, `sha`, `path`) are
  re-validated with `assert_safe_*` helpers immediately before shell use, in
  addition to invariant checks. Every interpolation is double-quoted and `--`
  end-of-options markers are used on all git invocations.
- The consuming workflow should set `permissions: contents: read`.

## Running locally

```bash
export ACTION_PATH=.github/actions/validate-plugins
export VALIDATE_TMP=/tmp/validate-plugins
export BASE_REF=origin/main
export MARKETPLACE_PATH=.claude-plugin/marketplace.json
export ALLOWED_HOSTS="github.com gitlab.com bitbucket.org"
mkdir -p "$VALIDATE_TMP"

bash $ACTION_PATH/scripts/00-detect-changes.sh
bash $ACTION_PATH/scripts/11-validate-invariants.sh
bash $ACTION_PATH/scripts/20-validate-cli-marketplace.sh
bash $ACTION_PATH/scripts/30-validate-cli-external.sh
bash $ACTION_PATH/scripts/40-validate-cli-local.sh
bash $ACTION_PATH/scripts/41-validate-aux-files.sh
bash $ACTION_PATH/scripts/90-report.sh
```
