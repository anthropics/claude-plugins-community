# scan-plugins

Claude-based policy/safety scan of changed external marketplace entries.
Companion to [`validate-plugins`](../validate-plugins/) and
[`bump-plugin-shas`](../bump-plugin-shas/).

**Non-blocking by default.** Findings surface as `::warning` annotations and a
step-summary table. Set `fail-on-findings: true` to make policy failures, and
entries that could not be reviewed, fail the job.

**Bot-free.** Needs only Anthropic API auth — either an `ANTHROPIC_API_KEY`
secret, or [Workload Identity Federation](https://github.com/anthropics/claude-code-action/blob/main/docs/setup.md)
inputs (`anthropic-federation-rule-id` etc.) which exchange the calling job's
GitHub OIDC token for a short-lived access token (no static key). If neither
is set, the AI review skips gracefully — so you can add the workflow
everywhere and roll auth out incrementally.

## Static pin check (deterministic, auth-free)

Independent of the AI review — and it runs even when Anthropic auth is absent
— the action statically classifies every MCP server declared in each target's
`.mcp.json` (and `plugin.json` `mcpServers`). A server whose `command` is a
package-manager runner (`npx`/`bunx`/`uvx`/`pipx`) with a **floating** spec —
a dist-tag like `@latest`, a version range, or a bare unversioned name that
isn't locally vendored — launches registry-resolved code at session start,
which the entry's pinned source SHA does not fix.

- Detection is **always on**: `::warning` per floating server, an
  `Unpinned auto-exec` column in the summary, and
  `unpinned_autoexec_runtime`/`unpinned_autoexec_specs` fields on the
  `scanned`/`pin-scanned` outputs.
- **Severity is per-consumer**: `fail-on-unpinned-autoexec: true` makes any
  non-waived floating launcher fail the job; the default only annotates.
- **Exceptions** are package-grained waivers in a repo-local file passed via
  `launch-shape-waivers` (see `action.yml` for the line format). Every
  floating spec of an entry must match an adjudicated prefix or the finding
  stands.

Package invocations inside `skills/`, `commands/`, or `agents/` markdown are
deliberately out of scope: those run agent-invoked and permission-gated, a
different trust shape from a session-start auto-launch.

The pin check checks each entry out with symlinks as plain files and no LFS
smudge, so it reads only file content of
the pinned commit. If an entry's `.mcp.json`, `plugin.json` or `.claude-plugin`
folder is committed as a symlink, or a manifest is stored through git LFS, the
check does not follow or fetch it: the entry gets a `pin-state not assessed`
warning and `assessed: false` in `pin-scanned`. The job does not fail on this,
even with `fail-on-unpinned-autoexec: true`; gate on `assessed` to block it.
A bare package name under a symlinked `node_modules` counts as floating.

Classifier logic lives in [`lib/pin-check.sh`](lib/pin-check.sh) (see its
provenance header) with golden vectors in
[`test-pin-check.sh`](test-pin-check.sh).

## The policy prompt

The bundled [`policy/prompt.md`](policy/prompt.md) is **intentionally
minimal** — it cites the public Software Directory Policy and Acceptable Use
Policy and asks for a pass/fail verdict, without enumerating specific
detection heuristics.

Organizations running this action should maintain a more detailed prompt in a
**private** location (so detection logic and regression fixtures aren't
published alongside the deployed scanner) and pass it via the `policy-prompt`
input:

```yaml
      - uses: anthropics/claude-plugins-community/.github/actions/scan-plugins@<PINNED-SHA>
        with:
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          policy-prompt: .github/policy/prompt.md   # repo-local, synced from private source
```

The output shape is in [`policy/schema.json`](policy/schema.json). The model
answers with its five required fields only: what a private prompt asks for beyond
them goes into `violations`.

## What it does

1. Determines targets: external entries that changed vs `base-ref` (or all
   external entries if `scan-all-external: true`).
2. For each target: fetch the pinned SHA into an isolated temp dir (same
   SSRF allowlist, quoting, and `--` discipline as `validate-plugins`).
   Nothing is checked out for the review: the files are read from git objects.
3. Send the policy prompt and all the plugin's files to Claude in **one request
   with no tools** ([`scripts/review.py`](scripts/review.py)). The model sees
   only that request: it can't read the runner, run anything or use the network.
   Images, fonts and documents are listed without their content. A plugin is not
   reviewed (see 4) if it has any other file that isn't text, a submodule, a Git
   LFS file or other git filter, a symlink that doesn't lead straight to one of
   its own files, names that differ only in case, over 1.5 MB of text or over
   5,000 files. The consumer's
   `policy-prompt` should come from a trusted ref, not from the change under
   review.
4. Parse the JSON verdict, redact credential-shaped strings from it, and emit
   `::warning` (or `::error` if `fail-on-findings`) annotations with line
   numbers into `marketplace.json`. An entry that cannot be reviewed at all
   (clone failure, too large, error, timeout, an answer that isn't exactly a
   verdict) is listed as "not
   assessed" and, with `fail-on-findings`, fails the step instead of passing
   unreviewed; the log carries a short redacted diagnostic, never the raw
   model output.
5. Write a step-summary table with passes/violations and the
   network-calls/software-install flags.

## Usage

> **Always pin to a commit SHA, never `@main`.** See `../validate-plugins/RELEASING.md`.

```yaml
# .github/workflows/scan-plugins.yml
name: Scan Plugins
on:
  pull_request:
    paths:
      - '.claude-plugin/**'

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write   # only needed for the WIF auth path
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-plugins-community/.github/actions/scan-plugins@<PINNED-SHA>
        with:
          # Auth: EITHER a static key …
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          # … OR Workload Identity Federation (no static key; needs
          # id-token: write above). Set one or the other, not both.
          # anthropic-federation-rule-id: fdrl_...
          # anthropic-organization-id: <org-uuid>
          # anthropic-service-account-id: svac_...
          # fail-on-findings: "true"   # uncomment to hard-block
```

## Inputs

| Input | Default | |
|---|---|---|
| `anthropic-api-key` | `""` | static key. If neither this nor `anthropic-federation-rule-id` is set, the scan is skipped (graceful no-op) |
| `anthropic-federation-rule-id` | `""` | WIF rule ID (`fdrl_...`). When set, the action mints a GitHub OIDC token and exchanges it. Requires `permissions: id-token: write` on the calling job |
| `anthropic-organization-id` | `""` | required when `anthropic-federation-rule-id` is set |
| `anthropic-service-account-id` | `""` | required when `anthropic-federation-rule-id` is set |
| `marketplace-path` | `.claude-plugin/marketplace.json` | |
| `base-ref` | PR base / push `before` / `origin/main` | |
| `fail-on-findings` | `false` | if true, `passes:false` fails the job, and so does an entry that could not be reviewed ("not assessed") |
| `scan-all-external` | `false` | nightly full-sweep mode |
| `policy-prompt` | bundled `policy/prompt.md` | override with a repo-local file |
| `allowed-hosts` | `github.com gitlab.com bitbucket.org` | SSRF allowlist |
| `model` | `claude-opus-4-8` | model that reviews each plugin |
| `scan-timeout-secs` | `300` | per-plugin timeout |

## Outputs

| Output | |
|---|---|
| `scanned` | JSON array of full verdicts `{name, passes, summary, violations, may_make_external_network_calls, may_download_additional_software}` |
| `failed` | JSON array of plugin names with `passes:false` |
| `result` | `pass` / `fail` / `skipped` |

## Isolation note

This runs as a step inside the calling job, so it shares that job's
`GITHUB_TOKEN`. The model has no tools, so text in a plugin can at most change
its own verdict; the policy prompt, a strict check of the answer's shape and
human review are the limits on that. For repos accepting fully untrusted
submissions, run this action in a separate job with `permissions: {}` for
stronger isolation — see the consuming-workflow example above (already
`contents: read` only).
