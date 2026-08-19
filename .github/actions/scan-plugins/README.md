# scan-plugins

Claude-based policy/safety scan of changed external marketplace entries.
Companion to [`validate-plugins`](../validate-plugins/) and
[`bump-plugin-shas`](../bump-plugin-shas/).

**Non-blocking by default.** Findings surface as `::warning` annotations and a
step-summary table. Set `fail-on-findings: true` to make policy failures fail
the job.

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

The verdict shape is in [`policy/schema.json`](policy/schema.json)
(`additionalProperties: true`, so a private prompt can add fields without
forking the action).

## What it does

1. Determines targets: external entries that changed vs `base-ref` (or all
   external entries if `scan-all-external: true`).
2. For each target: clone at the pinned SHA into an isolated temp dir (same
   SSRF allowlist, quoting, and `--` discipline as `validate-plugins`).
3. Run `claude -p` headless with the policy prompt and read-only file tools,
   scoped to the cloned directory.
4. Parse the JSON verdict; emit `::warning` (or `::error` if
   `fail-on-findings`) annotations with line numbers into `marketplace.json`.
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
| `anthropic-federation-rule-id` | `""` | WIF rule ID (`fdrl_...`). When set, the action mints a GitHub OIDC token; the CLI exchanges it. Requires `permissions: id-token: write` on the calling job |
| `anthropic-organization-id` | `""` | required when `anthropic-federation-rule-id` is set |
| `anthropic-service-account-id` | `""` | required when `anthropic-federation-rule-id` is set |
| `marketplace-path` | `.claude-plugin/marketplace.json` | |
| `base-ref` | PR base / push `before` / `origin/main` | |
| `fail-on-findings` | `false` | if true, `passes:false` fails the job |
| `scan-all-external` | `false` | nightly full-sweep mode |
| `policy-prompt` | bundled `policy/prompt.md` | override with a repo-local file |
| `allowed-hosts` | `github.com gitlab.com bitbucket.org` | SSRF allowlist |
| `claude-cli-version` | `latest` | **pin in your workflow** |
| `npm-registry` | `""` | optional internal mirror |
| `scan-timeout-secs` | `300` | per-plugin timeout |

## Outputs

| Output | |
|---|---|
| `scanned` | JSON array of full verdicts `{name, passes, summary, violations, may_make_external_network_calls, may_download_additional_software}` |
| `failed` | JSON array of plugin names with `passes:false` |
| `result` | `pass` / `fail` / `skipped` |

## Isolation note

This runs as a step inside the calling job, so it shares that job's
`GITHUB_TOKEN`. The `claude -p` invocation is restricted to read-only file
tools (`Read Glob Grep LS`) scoped to the cloned plugin directory; the prompt
is constructed by this action, not by the plugin. For repos accepting fully
untrusted submissions, run this action in a separate job with
`permissions: {}` for stronger isolation — see the consuming-workflow example
above (already `contents: read` only).
