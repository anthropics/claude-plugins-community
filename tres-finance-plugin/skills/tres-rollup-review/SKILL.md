---
name: tres-rollup-review
description: >
  Compute the EXACT sub-transaction impact of a rollup rule in TRES Finance — every
  filter applied — and flag genuine problems (zero matches, overlap, config mistakes)
  before the rule is created. Two modes. Mode A: a pre-create quality gate invoked by
  the tres-rollup-rules skill to vet proposed candidate rules. Mode B: standalone review
  of a rule someone submitted or of existing PENDING rules. Trigger this skill when the
  user says "review this rollup rule", "what would this rollup rule actually match",
  "preview the rollup impact", "how many transactions would this rule catch", "is this
  rollup rule valid", "validate my rollup rule", "check my pending rollup rules", or
  "review the rollup requests". Do NOT use this to design or propose new rollups — that
  is tres-rollup-rules. This skill only measures impact and flags issues; it never
  executes mutations.
compatibility: "Requires TRES Finance MCP connector"
---

# TRES Finance — Rollup Review

Take a fully-specified rollup rule and compute **exactly** which sub-transactions it
will claim — with every one of its filters applied — then flag genuine problems. You
do NOT design new rollups and you do NOT execute mutations.

All GraphQL runs through the **TRES Finance MCP connector** (`execute` tool). All
variable keys and nested input fields MUST use **camelCase**, never snake_case.

---

## What this adds over tres-rollup-rules

The `tres-rollup-rules` discovery step groups sub-txs only at the
(wallet, asset, direction) level — it never applies a single candidate's *full* filter
combination (fees + method_ids + subtx_type + amount bounds + counterparty +
excludeRollups together). This skill does exactly that, per rule, via the
`subTransactionRollupRulePreview` query (which runs the engine's real
`query_sub_transactions`), giving:

- the **exact** match count → the **zero-match gate** (a rule that matches nothing must
  not be created), and
- pre-create **overlap awareness**, so the user only ever sees viable proposals.

It is also usable **standalone** to review a rule someone submitted (Mode B) — a case
the discovery skill doesn't cover.

---

## Two modes

### Mode A — pre-create gate (invoked by `tres-rollup-rules`)

When `tres-rollup-rules` invokes this skill (via the Skill tool), these instructions
load into the **same** context that already holds the candidate rule objects — they
are not passed as arguments, they are already in the conversation above. Iterate those
candidates **one at a time**; for each, run the checks below and emit exactly one
verdict:

- **PASS** — clean, ready to propose (include the exact sub-tx + parent-tx count).
- **DROP** — matches 0 sub-txs; must not be created.
- **FIX** — a config problem with the exact change (e.g. "minAmount > maxAmount",
  "recipientIdentifier on an INFLOW rule — should be senderIdentifier").

Overlaps are reported as **notes**, not DROP/FIX (see Check 2). Produce one verdict line
per candidate, then control returns to `tres-rollup-rules` Step 2.5.

### Mode B — standalone review (when asked to review submitted/pending rules)

Fetch pending rules and review each; produce a per-rule findings summary.

```graphql
query PendingRollupRules {
  subTransactionRollupRule(status: "Pending", limit: 50) {
    totalCount
    results { id name interval startDate endDate status rule createdBy createdAt }
  }
}
```

The status filter is title-case (`"Pending"`, `"Active"`, `"Disabled"`). If
`totalCount` is 0, say "No pending rollup requests in this org" and stop.

---

## Ground truth — how a rule selects sub-transactions

A rule claims sub-transactions matching ALL of (this mirrors the engine's
`query_sub_transactions`):

- `belongsTo_In: [internal_account_id]`, `asset_In: [asset_id]` (the asset KEY),
  `platform` matches, `balanceFactor` matches `balance_factor`
- already-rolled-up (`excludeRollups`) and derived/locked/synced sub-txs excluded
- `fees`: `EXCLUDE` drops GAS/FEE, `ONLY` keeps only GAS/FEE, `INCLUDE` keeps all
- optional narrowing: `method_ids`, `min_amount`/`max_amount`, `subtx_type`,
  `sender_identifier`/`recipient_identifier`,
  `original_sender_prefix`/`original_recipient_prefix`

The rule JSON (as stored / returned) uses snake_case. `balance_factor = -1` is
**OUTFLOW**, `+1` is **INFLOW** — get this right or every direction check is backwards.

### Verified subTransaction filter names

| Intent | Filter |
|---|---|
| Wallet | `belongsTo_In: [ID]` |
| Asset by key | `asset_In: [ID]` |
| Direction | `balanceFactor: Float` (-1 / 1) |
| Min / max amount | `amount_Gte` / `amount_Lte` |
| Sender / recipient | `sender_Identifier_In: [String]` / `recipient_Identifier_In: [String]` |
| Method id | `tx_MethodId: String` (single) / `tx_Classification_MethodId_In: [String]` |
| Sub-tx type | `type: String` / `type_In: [String]` (lowercase FinancialAction value) |
| Exclude already-rolled-up | `excludeRollups: true` |
| Exclude gas/fee | `excludeGasFees: true` |
| Dates | `timestamp_Gte` / `timestamp_Lte` (DateTime) |

`type` / `type_In` take the **lowercase** FinancialAction value (`"gas"`, `"fee"`,
`"reward"`, …) — opposite casing from the rule's UPPERCASE `subtxType` enum. So
`subtx_type` is countable exactly (`type: "<value>"`) and `fees: ONLY` ≈
`type_In: ["gas", "fee"]`.

> Gotcha: `fees: ONLY` already selects GAS+FEE, so a gas/fee rollup needs `fees: ONLY`
> alone — adding `subtxType: GAS` on top is redundant (and narrows to GAS, dropping FEE).

**`typeId` is NOT a rule filter here.** `type_id` is only the rollup rule's id **when
paired with** `type_In: ["rollup", "rollup_fee"]`. On other types it means something
else entirely. To inspect what an existing rollup rule produced, query
`type_In: ["rollup","rollup_fee"], typeId: "<rule_id>"` — never `typeId` alone.

**Sentinel dates (operational note):** if `startDate == "0001-01-01"` or
`endDate == "9999-12-31"`, omit that bound (don't pass the sentinel — it may not parse).
Unbounded dates are normal and preferred; they are NOT a finding.

**Evidence:** the on-chain hash is `tx.identifier` (sub-select `tx { identifier }`),
never `typeId`. For examples also pull `amount`, `sender { identifier }`,
`recipient { identifier }`, `asset { symbol key }`.

---

## Scope — DISABLED rules are out of scope

Only **Active** and **Pending** rules are live. Never query, compare against, or flag
DISABLED rules (they're superseded versions).

---

## The checks

### Check 1 — Exact impact (the core; always run)

Get the ground-truth count straight from the engine via the
`subTransactionRollupRulePreview` query — it runs the real `query_sub_transactions`
with **all** of the rule's filters applied server-side, so you never reconstruct
filters by hand:

```graphql
query RollupPreview($rule: RollupRuleInputType!, $startDate: Date, $endDate: Date, $interval: Interval) {
  subTransactionRollupRulePreview(rule: $rule, startDate: $startDate, endDate: $endDate, interval: $interval) {
    subTransactionCount
    transactionCount
  }
}
```

Pass the candidate's rule object verbatim as `$rule` — the **same camelCase shape as the
create mutation** (`internalAccountId`, `assetId`, `platform` + `balanceFactor` + `fees`
as enum NAMES like `OUTFLOW`/`ONLY`, plus any
`methodIds`/`subtxType`/`minAmount`/`maxAmount`/identifiers). **Always pass `$interval`**
= the candidate's interval (`DAY` or `MONTH`); it governs how the eligibility-window
boundary is normalized, so a MONTH rule and a DAY rule over the same data can return
different counts. `startDate`/`endDate` are optional `YYYY-MM-DD` — omit for the rule's
full unbounded range.

The count is **what the rule would actually roll up on its next run**, not raw all-time
matches: the engine funnels the window through its own eligibility logic, so the
**current incomplete period and the unsynced/buffer tail are excluded**.
`transactionCount` is the distinct parent-tx count. (Already-rolled-up sub-txs are also
excluded — for what an *existing* rule has already produced, see the existing-rule
section below.)

- **subTransactionCount == 0 → DROP (Mode A) / blocking flag (Mode B):** "matches 0
  sub-txs as configured" — name the filters that zero it out (common culprits:
  `minAmount > maxAmount`, an identifier on the wrong direction, or an inverted date
  range). The reason is the useful part.

> **If `subTransactionRollupRulePreview` is not in this org's MCP schema** (confirm with
> `validate_query` or `introspect`), fall back to a fully-filtered count query: a single
> `subTransaction(... excludeRollups: true ...)` that applies every one of the rule's
> filters using the verified filter-name table above, selecting only `totalCount`. This
> is slightly less precise than the engine preview (it does not exclude the incomplete
> period / buffer tail) — say so when you report the number, and keep the `~` prefix.

### Check 2 — Overlap (informational, NOT a hard limit)

Another **Active/Pending** rule (or another candidate) on the same `internalAccountId` +
`assetId` + `platform` + `balanceFactor` with intersecting dates and non-disjoint
filters can claim some of the same sub-txs. This is **not** blocking: the engine
processes rules one-by-one ordered by id (PK), so a sub-tx matching multiple rules is
always claimed by the same rule consistently. Surface it as a note (other rule name + id,
up to 3 example tx hashes) so the user is aware — never DROP or force a split for overlap
alone.

**No separate config-validation check.** Date-order, identifier-on-wrong-direction,
mutually-exclusive prefixes, and bad `cutoffTime` are enforced by the create mutation
(returned as blocking `validationIssues`) — don't re-validate them here. A start date set
to clear a locked period is a **good** use, not a flag (leave the end date open).

### Existing-rule impact (Mode B — reviewing an Active/Pending rule)

Do NOT call an existing rule useless because Check 1 returns a low count. A running rule
has already rolled up its pool, and those rollups are excluded from Check 1 — so a rule
that has been doing its job shows only the few recent un-rolled sub-txs. Also count what
it **produced**:
`subTransaction(type_In: ["rollup","rollup_fee"], typeId: "<rule_id>") { totalCount }`.
Report both — "currently matches N new sub-txs; has already produced M rollups". A rule
is only ineffective if it has produced ~nothing **and** matches ~nothing now. (If its
filter looks stale — e.g. a `methodId` that no longer matches new txs — say *that*, with
the produced-vs-current numbers, rather than "useless".)

---

## Output

**Mode A:** one line per candidate back to `tres-rollup-rules`:
`<#> <name>: PASS (<subtx>/<tx> sub-txs)` / `DROP — <reason>` / `FIX — <change>`, plus any
overlap notes.

**Mode B:** one findings block per rule. Flat bullet list, each bullet with concrete
evidence; omit a check that found nothing. Always include the impact line. If clean:
"Reviewed *<name>* (id <id>) — matches ~<count> sub-txs across ~<tx count> txs. No
issues."

---

## Rules

- Never query, compare against, or flag DISABLED rules.
- Never propose new rollups or optimizations — that's `tres-rollup-rules`. You only
  compute impact and flag problems.
- Never execute mutations.
- Every flag carries evidence (a count, a date, a config value, or a tx hash).
