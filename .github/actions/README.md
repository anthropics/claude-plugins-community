# Plugin marketplace CI actions

Three composite actions that work as a system. All bot-free; all reuse
`validate-plugins/lib/common.sh` for safety predicates (host allowlist,
metachar blocklist, quoting/`--` discipline).

| Action | Role | Permissions | Secret |
|---|---|---|---|
| [`validate-plugins`](validate-plugins/) | **Gate** — invariants I1–I11 + `claude plugin validate` on the marketplace and changed plugins | `contents: read` | — |
| [`bump-plugin-shas`](bump-plugin-shas/) | **Maintenance loop** — discover stale external SHAs, validate at new HEAD inline, open one PR | `contents: write`, `pull-requests: write` | — |
| [`scan-plugins`](scan-plugins/) | **Policy layer** — Claude-based safety review of changed external plugins; non-blocking by default | `contents: read` | `ANTHROPIC_API_KEY` (graceful no-op if unset) |

See each action's README for inputs/outputs and `validate-plugins/RELEASING.md`
for SHA-pinning guidance. Consumers MUST pin `uses:` to a commit SHA.
