# owner-liveness-sweep

Corpus-wide source-availability / owner-verification sweep over the
marketplace's external github.com entries. Report-only: findings go to the
step summary + a findings JSON; the sweep never edits the marketplace and
never removes an entry.

## What it detects

| Class | Meaning | Severity |
|---|---|---|
| `identity_changed` | A recorded owner login now resolves to a **different GitHub account id** than the committed baseline records. Account ids are stable for the life of an account, so this means the login was released and re-registered — every entry under it needs review before any further bumps. | Fails the run |
| `owner_missing` | An owner login that no longer resolves (deleted or renamed away). Split by disposition: `verify-successor` when the owner's repos still resolve at a canonical successor location (typically a publisher rebrand/transfer — verify the successor and refresh/re-pin the listing), `review` when no repo resolves either (review the entries themselves). | Reported |
| `repo_moved` | A repository whose canonical `nameWithOwner` no longer matches the listed owner (rename/transfer redirect). The listed URL should be reviewed/refreshed. | Reported |
| `repo_missing` | A repository that no longer resolves (deleted or made private). | Reported |
| `unbaselined` | A live owner not yet in the baseline (normal after new entries merge) — fold in via `refresh`. | Info |
| `baseline_orphans` | Baseline owners whose entries have left the corpus — pruned by `refresh`. | Info |

The per-bump companion to this sweep lives in the bump action itself
(`bump-plugin-shas` verifies each entry it is about to bump); this sweep
covers the whole corpus, including everything that is *not* being bumped —
drift a per-bump gate never sees.

## Baseline

`.github/owner-baseline.json` maps each owner login (lowercased) to the
account id it resolved to when first recorded. Maintenance:

- **seed** — initial adoption: writes a fresh baseline from live results.
  Owners that don't resolve are reported, never baselined.
- **refresh** — additive-only update: adds unbaselined live owners, prunes
  orphans, and **never rewrites an existing recorded id**. It refuses to run
  while any `identity_changed` finding is present — resolve those by
  reviewing the affected entries first.

Local run (repo root):

```bash
MARKETPLACE_PATH=.claude-plugin/marketplace.json \
BASELINE_PATH=.github/owner-baseline.json \
MODE=refresh \
bash .github/actions/owner-liveness-sweep/scripts/sweep.sh
# then open a PR with the updated baseline
```

## Tests

`test-sweep.sh` — hermetic (PATH-shimmed `gh`, fixture GraphQL responses; no
network). Wired into validate-plugins.yml alongside the bump action's suites.
