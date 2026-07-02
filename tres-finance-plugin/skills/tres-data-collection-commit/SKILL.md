---
name: tres-data-collection-commit
description: >
  Trigger on-chain data collection (a "Commit") in Tres Finance for wallets that
  have already been onboarded. Use this skill whenever the user wants to collect
  data, pull balances, sync wallets, refresh on-chain data, run a commit, trigger
  a commit, or "collect" anything in Tres. This is the second step of the Tres
  onboarding flow — it sits between wallet upload (tres-wallets-upload) and balance
  validation (tres-asset-balance-validation). Always trigger this skill for any
  request that mentions "commit", "collect", "data collection", "pull data",
  "fetch on-chain data", "sync wallets", "refresh balances", or anytime the user
  just finished uploading wallets and is ready to bring in their on-chain data.
compatibility: "Requires TRES Finance MCP connected (https://ai.tres.finance/mcp)"
---

# Tres Finance — Data Collection (Commit)

## Overview

Commit is the step that pulls on-chain data into Tres Finance for the wallets
already onboarded to the org. It runs the platform's data-collection pipeline for
each wallet and either:

- **Full data collection** — collects the full transaction history *and* current
  balances. Used for a complete onboarding or historical backfill.
- **Balances only** — collects only the current asset balances (no transactions).
  Much faster; useful when the user just wants an up-to-date snapshot or is
  preparing for a quick balance validation.

This skill is the **second step** of the customer onboarding flow:

1. **Upload wallets** (`tres-wallets-upload`) — register the wallets in Tres.
2. **Collect data (this skill)** — run the commit so Tres actually fetches the
   on-chain state.
3. **Validate balances** (`tres-asset-balance-validation`) — cross-check the
   collected balances against DeBank.

## When to Use

Trigger this skill whenever the user wants to:

- Run a commit / trigger a commit / kick off data collection
- Collect on-chain data into Tres
- Pull balances or transactions for their wallets
- Sync wallets that were just added
- Refresh Tres data after adding new wallets

**Example phrases that must trigger this skill:**

- *"Run the commit"* / *"Trigger the commit"*
- *"Collect the data for my wallets"*
- *"Pull balances for everything"*
- *"I just added wallets — now collect the data"*
- *"Sync my wallets"*
- *"Start the data collection"*

---

## Prerequisites

| Requirement | Details |
|---|---|
| TRES Finance MCP connected | The TRES MCP tools (`get_viewer`, `execute`, `build_query`, `introspect`) must be available |
| Authenticated org | `get_viewer` must succeed and return an `orgName` |
| At least one wallet onboarded | If there are no wallets, commit has nothing to collect — point the user to `tres-wallets-upload` first |

---

## Process Overview

Follow these steps in order. Do **not** skip the user-selection steps — the
whole point of this skill is to capture the user's collection intent before
firing the mutation.

### Step 1 — Confirm authentication

Call `get_viewer` to verify the user is authenticated to Tres and note the
`orgName`. Mention it in the confirmation summary later so the user knows which
org the commit will run against.

If `get_viewer` fails: tell the user the TRES MCP is not connected and ask them
to connect it before continuing.

### Step 2 — Ask: full data or balances only?

This is the core choice of the skill. Ask the user **exactly** this (using the
`AskUserQuestion` tool if available, otherwise plain text):

> **What do you want to collect?**
>
> 1. **Full data collection** — collects all transactions and current balances.
>    Slower, but produces a complete ledger. Use this for first-time onboarding
>    or historical backfill.
> 2. **Balances only** — collects only current balances, no transactions. Fast.
>    Use this when you just want an up-to-date balance snapshot (for example,
>    before running balance validation).

Map the answer to the GraphQL parameter `balancesOnly`:

| User choice | `balancesOnly` |
|---|---|
| Full data collection | `false` |
| Balances only | `true` |

If the user is unsure, recommend **Full data collection** as the default for
first-time onboarding (because skipping transactions means the ledger will be
empty even after commit succeeds).

### Step 3 — Ask: all wallets, or specific wallets?

Ask the user whether the commit should run on every wallet or a subset:

> **Which wallets should I collect data for?**
>
> 1. **All wallets** — run the commit across every wallet in the org.
> 2. **Specific wallets** — only collect data for wallets I pick.

If the user chooses **All wallets**: set `internalAccountIds = null` (omit the
field in the mutation variables, or pass `null`).

If the user chooses **Specific wallets**:

1. Fetch the list of wallets from Tres so the user can pick from real options:
   ```graphql
   query ListWalletsForCommit {
     internalAccount {
       totalCount
       results {
         id
         name
         identifier
         parentPlatform
       }
     }
   }
   ```
2. Present the wallets as a numbered plain-text list (name + short address +
   platform). If there are more than ~25 wallets, show the first 25 and tell
   the user they can reply with wallet names, addresses, or IDs to narrow down.
3. Let the user respond conversationally ("the three Ethereum ones", "Treasury
   Hot and Cold Storage", "IDs 123, 456, 789", etc.). Resolve their response to
   a list of internal account `id` values. Never call the mutation with an
   unresolved name — always resolve to IDs first.
4. If you cannot confidently resolve a wallet the user named, ask them to
   clarify instead of guessing.

### Step 4 — Confirm before firing the mutation

Show a short plain-text summary of exactly what is about to happen and ask for
explicit confirmation. Example:

```
About to trigger a Commit in Tres Finance:

  Org:       Acme Labs
  Mode:      Full data collection (transactions + balances)
  Wallets:   All wallets in the org

Shall I run it now?
```

Or, for a scoped run:

```
About to trigger a Commit in Tres Finance:

  Org:       Acme Labs
  Mode:      Balances only
  Wallets:   3 selected
             - Treasury Hot (0x1887...3Cdd, ETHEREUM)
             - Cold Storage (bc1q...xyz, BITCOIN)
             - Ops Main (0x89Ba...92a8, POLYGON)

Shall I run it now?
```

Wait for an affirmative reply (`yes`, `confirm`, `go ahead`). Anything else:
treat as "not yet" and ask what to change.

### Step 5 — Trigger the commit

Run the `triggerCommit` mutation via the TRES MCP `execute` tool:

```graphql
mutation TriggerCommit(
  $balancesOnly: Boolean
  $internalAccountIds: [ID]
) {
  triggerCommit(
    balancesOnly: $balancesOnly
    internalAccountIds: $internalAccountIds
  ) {
    status
    message
    commitId
  }
}
```

Variable mapping:

| Variable | Value |
|---|---|
| `balancesOnly` | `true` (balances only) or `false` (full data) from Step 2 |
| `internalAccountIds` | `null` for all wallets, or an array of wallet IDs from Step 3 |

Do not pass `fromDate`, `toDate`, or `commitId` unless the user specifically
asked for a date range or a retry of a specific commit — the onboarding flow
should just let Tres pick the defaults.

> All variable keys must be **camelCase** (e.g. `balancesOnly`,
> `internalAccountIds`). The TRES GraphQL API rejects snake_case.

### Step 6 — Report the result

The mutation returns three fields:

- `status` — a **Boolean**. `true` = the commit was accepted and enqueued;
  `false` = the trigger itself failed.
- `message` — a short human-readable string (e.g., `"Commit triggered"`).
  Show it verbatim.
- `commitId` — a UUID for this run; show it so the user can reference the job
  later (and so you can pass it to a future status-check tool).

Example response to the user when `status == true`:

```
✅ Commit triggered successfully.

  Status:    true
  Message:   Commit triggered
  Commit ID: c93a6d31-2f98-4eae-859f-80b010048fbd

Data collection is now running in the background. You will typically see
balances appear within a few minutes; full data collection can take longer
depending on history length and the number of wallets.
```

If `status == false`, treat it as a failure: show the `message` verbatim and
offer the user next steps: re-run the commit, check wallet configuration, or
contact support if the error is opaque.

### Step 7 — Point to the next onboarding step

As the final part of the response (after the success/error report), remind the
user that Commit is step 2 of the onboarding flow and the next step is balance
validation. Word it so it is clearly a suggestion, not an automatic action:

> **Next step in onboarding:** once the commit has finished collecting your
> current balances, the next thing to do is validate them against DeBank. Just
> say *"validate my balances"* and I'll run the Balance Validation skill for
> you.

Do **not** auto-trigger the validation skill — the user must opt in, because
the commit runs asynchronously and the data may not be ready immediately.

---

## Important Notes

- **Async execution.** `triggerCommit` enqueues the job; it does not block on
  completion. The returned `commitId` lets the user (or another skill) check
  status later.
- **Balances only ≠ no writes.** Even in balances-only mode, Tres updates the
  per-wallet balance snapshots. It only skips transaction ingestion.
- **No wallets uploaded yet?** If the user triggers this skill before onboarding
  any wallets, `internalAccount` will return `totalCount: 0`. Tell the user
  they need to add wallets first (point to `tres-wallets-upload`) and stop.
- **Partial failures.** It is possible for the commit to succeed for some
  wallets and fail for others. The top-level `status` and `message` give the
  summary; deeper diagnostics live in the TRES UI under Data Collection logs.
- **Idempotency.** Re-running a commit on the same wallet is safe — Tres
  deduplicates transactions by on-chain identifier.

---

## Error Handling

| Situation | Response |
|---|---|
| `get_viewer` fails | Tell the user the TRES MCP is not connected; stop. |
| `internalAccount.totalCount == 0` | Tell the user there are no wallets to commit; point to the `tres-wallets-upload` skill; stop. |
| Mutation returns non-success `status` | Show the raw `status` and `message`; offer to retry or investigate. |
| User provides wallet names that can't be resolved | Ask for clarification instead of guessing; never send unresolved names to the mutation. |
| User asks for a date range | Accept `fromDate` / `toDate` as ISO 8601 UTC and pass them through; confirm the range in the summary before firing. |
| User asks to cancel a running commit | Out of scope for this skill. Mention that `killCommits` exists and offer to hand off to another skill or the TRES UI. |

---

## Examples

**Example 1 — First-time onboarding, all wallets, full data:**

```
User: I just uploaded my wallets. Collect the data.

Claude: [runs get_viewer → "Acme Labs"]
        What do you want to collect?
          1. Full data collection (transactions + balances)
          2. Balances only

User: Full.

Claude: Which wallets?
          1. All wallets
          2. Specific wallets

User: All.

Claude: About to trigger a Commit in Tres Finance:
          Org:     Acme Labs
          Mode:    Full data collection
          Wallets: All wallets in the org
        Shall I run it now?

User: Yes.

Claude: [runs triggerCommit(balancesOnly: false)]
        ✅ Commit triggered successfully.
          Status:    SUCCESS
          Message:   Commit enqueued for 12 wallets.
          Commit ID: 9f2e5c4a-...
        Next step: once collection finishes, run balance validation.
```

**Future enhancement (not implemented in v1):**

A natural follow-up is to optionally **wait** inside this skill until the
commit completes (poll `internalAccount.status` until every targeted wallet is
back to `READY` and `lastSyncedAt` is newer than the trigger time), then notify
the user that they can safely run the balance validation skill. The current
v1 design intentionally exits after triggering — full-data commits can take a
long time, and polling synchronously inside chat is painful at the long end.
A companion guard inside `tres-asset-balance-validation` (refusing to run, or
warning, while a commit is in progress) is the other half of that story.

---

**Example 2 — Quick balance refresh for two wallets:**

```
User: Can you just pull balances for my Ethereum treasury wallets?

Claude: [runs get_viewer]
        What do you want to collect?
          1. Full data collection
          2. Balances only  ← fits "just pull balances"

User: Balances only.

Claude: Which wallets?
          1. All wallets
          2. Specific wallets

User: Specific — Treasury Hot and Treasury Cold.

Claude: [queries internalAccount, resolves the two wallets by name]
        About to trigger a Commit in Tres Finance:
          Mode:    Balances only
          Wallets: 2 selected
                   - Treasury Hot (0x1887...3Cdd, ETHEREUM)
                   - Treasury Cold (0x89Ba...92a8, ETHEREUM)
        Shall I run it now?

User: Go.

Claude: [runs triggerCommit(balancesOnly: true, internalAccountIds: [...])]
        ✅ Commit triggered. Commit ID: ...
```
