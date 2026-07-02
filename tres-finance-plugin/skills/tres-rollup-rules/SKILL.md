---
name: tres-rollup-rules
description: >
  Analyze an organization's sub-transaction patterns in TRES Finance, identify groups of
  repetitive transactions, and propose data-driven rollup rules that consolidate them into
  one aggregated entry per interval (daily or monthly) for cleaner ERP integration. Also
  lists and deletes rollup rules. Trigger this skill whenever the user asks about rollup
  rules, transaction aggregation, consolidating transactions, reducing transaction noise,
  rolling up gas fees, rolling up staking rewards, rolling up micro-transactions, or
  collapsing many small ledger entries into fewer summary entries. Also trigger on "create
  a rollup rule", "suggest rollup rules", "what should I roll up", "show my rollup rules",
  "delete a rollup rule", "aggregate transactions", "too many transactions", "reduce
  transaction count", "roll up fees", "daily rollup", "monthly rollup". If a wallet has too
  many transactions, high-frequency activity, or noisy ledger entries, proactively suggest
  rollup rules. For computing the EXACT impact of a single already-specified rule or
  reviewing submitted/pending rules, use the tres-rollup-review skill instead.
compatibility: "Requires TRES Finance MCP connector"
---

# TRES Finance — Rollup Rules

Analyze an organization's sub-transaction patterns, identify groups of repetitive
transactions, and propose rollup rules that consolidate them into a single entry per
interval for cleaner ERP integration. This is a **data-driven discovery** flow — you find
the candidates from the data, validate each against real transactions, then present and
create them.

A rollup rule is keyed on FOUR dimensions that together define exactly which
sub-transactions it claims:
**internalAccount (wallet) + asset KEY + platform + balanceFactor (direction)**.
Optional discriminating filters (fees, methodIds, subtxType, amount bounds,
counterparties) narrow it further. Everything you discover and propose must map onto this
shape — see the Rule Field Reference at the bottom.

A rollup is **non-destructive**: the original raw sub-transactions are always preserved
and visible in the **Rollup Breakdown** report.

All GraphQL runs through the **TRES Finance MCP connector** (`execute` tool; validate with
`validate_query` first when unsure). All variable keys and nested input fields MUST use
**camelCase** (e.g. `internalAccountId`, `balanceFactor`), NEVER snake_case.

---

## Routing

- **"Suggest / create / propose rollup rules"**, **"too many transactions"**, **"roll up
  X"** → run the full discovery pipeline (Steps 0–6 below). This is the main flow.
- **"Show / list my rollup rules"** → Section A (List existing rules), then stop.
- **"Delete a rollup rule"** → Section C (Delete rules).
- **"Review this specific rule" / "what would this rule match"** → hand off to the
  **tres-rollup-review** skill.

---

## Step 0 — Confirm Scope

Establish scope with the user, but keep it light — only the analysis is scoped, the rules
themselves are usually open-ended.

### Analysis window (OPTIONAL)
A period only narrows the *discovery* queries so you look at recent, representative
activity. It is NOT required, and it is NOT the rule's date range.
- "Q1 2025" → start: `2025-01-01T00:00:00Z`, end: `2025-03-31T23:59:59Z`
- "last 3 months" → compute from today

If the user gives no period, analyze all history — that is fine and common.

### Rule date range (PREFER OPEN-ENDED)
The rules you create should normally have **no start/end date** — they default to "from the
beginning of time, indefinitely" so they keep catching matching transactions going
forward. Only set `startDate`/`endDate` when the user explicitly wants the rule bounded.

### Wallets (optional, default: all)
The user may scope to specific wallets.

### Asset classes (optional, default: all non-spam)
The user may scope to specific asset classes (e.g. "just stablecoins", "ETH"). Remember: a
class (e.g. USDC) can span many asset keys/chains, but each rule targets ONE key — see the
asset-class bridge in Step 2.

### Clustering guidance (optional)
Hints like "focus on gas fees", "ignore staking rewards under $10", "group ETH transfers
by methodId".

**Confirm scope briefly, then start:**
> "I'll look for rollup candidates across **all wallets** and **all assets** (analyzing
> **all history**). Rules I propose will be open-ended unless you want them date-bounded.
> Starting now."

---

## Step 1 — Inventory

Run these (in parallel where possible).

### 1a. Wallets
```graphql
query Wallets { internalAccount { totalCount results { id name identifier parentPlatform platforms balancesCount status } } }
```
Collect wallet `id` (integer) — this is the rule's `internalAccountId`. Use `platforms`
(plural list) and `parentPlatform` (string); there is no singular `platform` field on
wallets.

### 1b. Existing rollup rules (so you don't duplicate coverage)
```graphql
query ExistingRules { subTransactionRollupRule { totalCount results { id name interval status startDate endDate createdBy lastSuccessfulRunAt rule } } }
```
`rule` is the JSON config (`internal_account_id`, `asset_id`, `platform`, `balance_factor`,
`fees`, …). Note which (account, assetKey, direction) tuples are already covered by
**Active** or **Pending** rules — skip those. Ignore **Disabled** rules (they are
superseded versions, not live coverage). Also study the existing rule **names** here to
learn the org's naming convention (see Naming below).

### 1c. Total sub-transactions in scope
```graphql
query InScope($ts_Gte: DateTime, $ts_Lte: DateTime) {
  subTransaction(timestamp_Gte: $ts_Gte, timestamp_Lte: $ts_Lte) { totalCount }
}
```
(Omit the timestamp args entirely when analyzing all history.)

Report: "Found X wallets, Y existing rules (Z active), N sub-transactions in scope."

---

## Step 2 — Discovery (the core analysis)

Use aggregation queries to find which (wallet, asset, direction) groups have the most
repetitive volume, then drill into discriminating filters.

### Filter-name reference (verified — use these EXACT names)
- Wallet: `belongsTo_In: [ID]` (array, even for one id)
- Asset by key: `asset_In: [ID]` (array of asset KEYS, e.g. `["ethereum_native"]`)
- Asset class: `asset_AssetClass_In: [ID]`
- Direction: `balanceFactor: Float` (`-1` = OUTFLOW, `1` = INFLOW)
- Amount: `amount_Gte` / `amount_Lte`; fiat: `fiatValue_Gte` / `fiatValue_Lte`
- Counterparty: `sender_Identifier_In: [String]`, `recipient_Identifier_In: [String]`
- Method: `tx_MethodId: String` (single) or group by `tx__method_id`
- Sub-tx type: `type: String` / `type_In: [String]` (FinancialAction) — filter with the
  **lowercase** value (`"gas"`, `"reward"`, …); note this is the opposite casing from the
  mutation's UPPERCASE `subtxType` enum. `groupBy: ["type"]` works too.
- Dates: `timestamp_Gte` / `timestamp_Lte`
- Exclude already-rolled-up sub-txs: `excludeRollups: true`
- Exclude gas/fee sub-txs: `excludeGasFees: true`; exclude spam: `excludeSpam: true`
- Internal transfers only: `internalTransfer: true`

### Always exclude already-rolled-up sub-txs
Add `excludeRollups: true` to every discovery/count query. It drops ROLLUP / ROLLUP_FEE
sub-txs so your counts reflect what a *new* rule would actually capture — matching the
rollup engine's own selection. Without it, groups a prior rule already rolled up would be
double-counted. (`onlyRollup: false` does NOT do this — it's a no-op.) To inspect what an
existing rule produced, query `type_In: ["rollup", "rollup_fee"], typeId: "<rule_id>"` —
`typeId` only means the rollup rule id when paired with a rollup `type`.

### 2a. Group by the rule's real key (wallet id + asset key + platform + direction)
```graphql
query GroupByKey($ts_Gte: DateTime, $ts_Lte: DateTime) {
  subTransaction(
    timestamp_Gte: $ts_Gte, timestamp_Lte: $ts_Lte,
    excludeRollups: true,
    groupBy: ["belongs_to", "asset", "platform", "balance_factor"],
    aggregations: [
      { field: id, function: COUNT, alias: "count" },
      { field: fiatValue, function: AVG, alias: "avgFiat" }
    ]
  ) {
    groupedAggregations { groupKey results { alias value } }
  }
}
```
`groupKey` gives you the wallet **id** (→ `internalAccountId`), the asset **key** (→
`assetId`), platform, and balanceFactor — exactly the four fields a rule needs, no
name/symbol guessing. Groups under ~50 sub-txs are rarely worth a rule.

### The asset-class bridge
Users think in asset *classes* ("roll up all our USDC"); a rule targets one asset *key*.
When the user scopes by class, you may first group by `asset__asset_class__symbol` to
prioritize, but you **must** then expand each promising class into its concrete asset keys
(Step 2a already returns keys) and propose **one rule per (wallet, assetKey, platform,
direction)**. In the report, surface the sibling keys on the same wallet so the user sees
which variants each rule does and does not cover.

### 2b. Drill down by methodId (per significant group)
```graphql
query DrillMethod($ts_Gte: DateTime, $ts_Lte: DateTime, $belongsTo_In: [ID], $asset_In: [ID], $balanceFactor: Float) {
  subTransaction(
    timestamp_Gte: $ts_Gte, timestamp_Lte: $ts_Lte,
    belongsTo_In: $belongsTo_In, asset_In: $asset_In, balanceFactor: $balanceFactor,
    excludeRollups: true,
    groupBy: ["tx__method_id"],
    aggregations: [
      { field: id, function: COUNT, alias: "count" },
      { field: amount, function: AVG, alias: "avgAmount" },
      { field: amount, function: MAX, alias: "maxAmount" }
    ]
  ) {
    groupedAggregations { groupKey results { alias value } }
  }
}
```

### 2c. Drill down by sub-tx type (optional)
Repeat the same query shape with `groupBy: ["type"]` to see whether a specific sub-tx type
dominates the group — useful only if you intend a `subtxType` rule.

### Analysis strategy
Reason about which combinations make the best rules:
1. **Coverage** — each rule should claim a meaningful share of its group.
2. **Discriminating filter (when useful, not required)** — the four key fields (wallet +
   assetKey + platform + direction) plus `fees` fully define most rules. Add an optional
   narrowing filter (methodIds, amount bounds, counterparty, or `subtxType`) only when it
   sharpens a heterogeneous group — many good rules use none. `subtxType` in particular is
   optional; don't add it reflexively.
3. **Interval** — DAY for high-frequency groups (>~500 sub-txs), MONTH otherwise.
4. **Existing rules** — skip (account, assetKey, direction) tuples already covered by an
   Active/Pending rule. **Never judge an existing rule by its current match count alone**:
   a rule that has been running has already rolled up its pool, so the live (non-rollup)
   sub-txs that remain are just the recent unprocessed few — a hard-working rule looks
   idle. To see what it actually did, count the rollups it produced:
   `subTransaction(type_In: ["rollup","rollup_fee"], typeId: "<rule_id>")`. Only treat a
   rule as ineffective if it has produced ~nothing **and** matches ~nothing now.
5. **Overlap (soft)** — two rules on the same wallet + assetKey + platform + direction with
   non-disjoint filters can claim the same sub-txs. This is not fatal: the engine processes
   rules deterministically by id (PK), so a shared sub-tx is always claimed by the same
   rule. Prefer non-overlapping rules, but overlap is a note, not a blocker.

For each candidate, note WHY this combination was chosen.

---

## Step 2.5 — Validate candidates (MANDATORY quality gate)

At this point you hold your N candidate rule objects (from Step 2) in context. **Invoke the
`tres-rollup-review` skill** (via the Skill tool) **once** — this loads the review checks
into your *own* context (it is not a separate agent and takes no arguments; the candidates
are already here, nothing is passed). Then, following those instructions, walk your
candidates **one at a time** — for each candidate run the review's Check 1 (one
`subTransactionRollupRulePreview` call), Check 2, and Check 3 — and record a per-candidate
verdict: PASS / DROP / FIX, with the exact sub-tx and parent-tx counts. So 10 candidates →
10 preview calls → 10 verdicts.

Act on the results:
- **DROP** any candidate that matches **0 sub-txs** (the rule would do nothing).
- **FIX** config problems (inverted dates, min>max, identifier-on-wrong-direction,
  mutually-exclusive prefixes, bad cutoffTime).
- **Note** any overlap with another candidate or an Active/Pending rule in the report —
  overlap is informational (the engine resolves it deterministically by id), so only adjust
  if the user prefers cleaner separation; do not drop on overlap alone.

Candidates that DROP or have unresolved FIXes don't proceed to Step 3. This gate is what
keeps suggestion quality high — do not skip it.

---

## Naming rollup rules

Every proposed rule needs a clear, consistent `name`. Decide it like this:

1. **Match the org's existing convention first.** From the Active/Pending rule names you
   fetched in Step 1b, infer the org's pattern — separator, field order, casing, how they
   denote direction/fees/interval — and name new rules the same way so they sit naturally
   alongside the existing ones.
2. **If there's no clear existing pattern, default to:**
   `<wallet name> - <asset symbol> - <direction> <fees label>` and append ` (<interval>)`,
   where the fees label maps:
   - `fees: ONLY` → `fees` (e.g. "gas fees")
   - `fees: INCLUDE` → `include fees`
   - `fees: EXCLUDE` → `exclude fees`
   Example: `EVM Exec Wallet 1 - ETH - outflow fees (monthly)`. When a single
   discriminating filter defines the rule (e.g. a known method), fold it into the name
   (e.g. `… - LP exits (daily)`).

Keep names human-readable and unique within the proposal set. Use the same name in the HTML
report, the proposal table, and the `name` field of the create mutation.

---

## Step 3 — Present Results

### 3a. HTML proposal report
Write a standalone `.html` file to the working directory (e.g.
`rollup-rules-proposal.html`) and tell the user the path so they can open it. Use the
template and patterns in `references/proposal-html-template.html` **verbatim** — copy the
CSS and skeleton as-is, only replacing the `<!-- PLACEHOLDER -->` comments with actual data
rows. Do NOT regenerate the CSS or layout. That reference file documents the summary cards,
the proposed-rules table, the skipped table, the per-candidate **"Preview matched txs"**
ledger link, the impact badges, and the hash/address display rule. **Keep the HTML compact**
(target under 4000 tokens of body).

Key content rules from that reference, called out here because they matter:
- The Volume column is **always** `Volume (sub-tx / tx)` and values are **always** prefixed
  with `~` (e.g. `~1,240 / ~310`) — the values are the rollup_review-validated sub-tx and
  distinct parent-tx counts, and `~` sets the expectation that the Preview link's ledger
  filters can't express every rule filter exactly.
- Impact badges: **high volume is a GOOD result, never an alarm** — green HIGH / indigo
  MEDIUM / grey LOW. Red is reserved for actual problems (the 🟢/🟡/🔴 validation status),
  never for impact.
- Skipped table: include candidates the rollup_review gate dropped (e.g. "0 matching
  sub-txs", "overlaps rule #38211").

### 3b. Proposal task table
Present a **numbered markdown table** in chat — one row per proposed rule — so the user can
approve by number. Columns: `#`, Rule Name, Wallet (id), Asset / Platform, Direction,
Filter, Volume (sub-tx / tx), Interval, Validated Impact. Priority hint: HIGH for >1000
sub-txs, MEDIUM for 200–1000, LOW for <200.

---

## Step 4 — User Review

Ask the user:
> "I've proposed X rollup rules (all validated against real transactions). Review the
> report and table above. You can:"
> - **Approve all** — I'll create all proposed rules
> - **Approve specific rules** — tell me which numbers
> - **Provide feedback** — tell me what to adjust and I'll re-analyze
> - **Cancel** — no rules will be created

Wait for the user's response before proceeding. **Never create a rule without explicit
confirmation.**

---

## Step 5 — Create Rules

For approved rules, run the `createSubTransactionRollupRules` mutation via the MCP `execute`
tool (it accepts a batch and returns per-rule results with validation issues):

```graphql
mutation CreateRollupRules($rules: [RollupRuleCreationRequest]!) {
  createSubTransactionRollupRules(rules: $rules) {
    results {
      rollupRuleId
      validationIssues { blocking type message }
    }
  }
}
```

Each entry in `$rules` (all camelCase):
```json
{
  "name": "ETH outflow gas — wallet-1 (daily)",
  "interval": "DAY",
  "createdBy": "AI",
  "rule": {
    "internalAccountId": 123,
    "assetId": "ethereum_native",
    "platform": "ETHEREUM",
    "balanceFactor": "OUTFLOW",
    "fees": "ONLY",
    "methodIds": ["0x573ade81"]
  }
}
```

- **Always set `createdBy: "AI"`** so the rule is attributed to AI in the audit trail.
- **Omit `startDate` / `endDate`** unless the user wants the rule bounded — omitting them
  makes the rule open-ended.
- **Only include optional filter fields the user/analysis actually set** — do NOT send
  `null` for unused optional fields, just omit them from the `rule` object.
- Prefer **creating new rules**. Editing an existing PENDING rule (via top-level
  `ruleId: <id>`) is supported, but pending rules may be auto-approved after a delay, so an
  in-place edit can race with activation — only edit pending when the user explicitly asks.

**Enum values (GraphQL enums, NOT quoted strings, in the query):**
- `interval`: `DAY` or `MONTH`
- `platform`: UPPERCASE — `ETHEREUM`, `BASE`, `SOLANA`, `BITCOIN`, …
- `balanceFactor`: `INFLOW` (incoming, +1) or `OUTFLOW` (outgoing, -1)
- `fees`: `INCLUDE` (txs + their fees), `EXCLUDE` (txs without fees), `ONLY` (only the fee
  sub-txs — selects GAS **and** FEE). For a gas/fee rollup use `fees: ONLY` **by itself**;
  do NOT also set `subtxType: GAS/FEE` — `ONLY` already covers them, and adding
  `subtxType: GAS` is redundant and wrongly drops the FEE sub-txs.
- `subtxType`: a `FinancialAction` enum or null — e.g. `REWARD`, `NATIVE_TRANSFER`,
  `TOKEN_TRANSFER`. Leave null for gas/fee rollups (use `fees: ONLY` instead).
- `createdBy`: `AI`

**Platform casing:** lowercase in query *filters* (`subTransaction(asset_In: [...])`,
`asset(platform: "ethereum")`); UPPERCASE enum in *mutation* inputs (`rule.platform:
ETHEREUM`). Query return values are UPPERCASE too.

**Validation rules the server enforces (never propose a rule that breaks these):**
- `senderIdentifier` is only valid on **INFLOW** rules; `recipientIdentifier` only on
  **OUTFLOW** rules (on an outflow the sender is always your wallet, and vice versa).
- `senderIdentifier` ⊥ `originalSenderPrefix`; `recipientIdentifier` ⊥
  `originalRecipientPrefix` (mutually exclusive).
- `startDate` must be before `endDate`.
- An identical rule (same `rule` JSON) cannot already exist for the org.

The mutation also re-checks matching transactions and overlaps and returns those as
`validationIssues` — the rollup_review gate should have caught them already, but the server
is the final authority.

### Resolving `assetId` and `internalAccountId`
- `internalAccountId` (integer): from the Step 1 wallet inventory.
- `assetId` is the asset **key** = `"<platform_lowercase>_<identifier>"`. Native tokens:
  `ethereum_native`, `base_native`, `solana_native`. ERC-20:
  `ethereum_0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48` (USDC). Step 2a already returns keys
  in the groupKey; otherwise look them up:
```graphql
query AssetKeys { asset(key_In: ["ethereum_native"]) { results { key identifier platform symbol name parentPlatform } } }
```

---

## Step 6 — Report Outcomes

For each per-rule result in the batch response, color-code the outcome so the user sees
status at a glance — **🟢 green** = created with no issues, **🟡 yellow** = created with
non-blocking validation issues, **🔴 red** = blocked / not created:
- `rollupRuleId` present, no `validationIssues` → 🟢 created
- `rollupRuleId` present with only non-blocking `validationIssues` → 🟡 created, issue noted
- any `validationIssues` with `blocking: true` (no `rollupRuleId`) → 🔴 FAILED, quote the
  `message`

Created rules start in `PENDING` status and activate on the next processing cycle. Use the
same 🟢/🟡/🔴 coding in the Step 3 report when surfacing the rollup_review validation
outcome per proposed rule.

---

## A. List existing rollup rules

When the user just wants to see current rules:

```graphql
query ListRollupRules($limit: Int, $offset: Int, $status_In: [String]) {
  subTransactionRollupRule(limit: $limit, offset: $offset, status_In: $status_In) {
    totalCount
    results { id name interval startDate endDate nextActivationDate status rule }
  }
}
```
Variables: `{"limit": 50, "offset": 0}` (add `status_In: ["Active"]` etc. to filter;
status is title-case). Present as a numbered markdown table: Name, ID, Status, Interval,
Date range (or "indefinite"), and the key rule filters (wallet, asset, direction, fees, any
optional filter). Paginate if `totalCount > 50`.

---

## C. Delete rollup rules

Only **PENDING** rules can be deleted via the API. Active rules require TRES support.

First list the rules (Section A) so the user can identify which to delete, then confirm the
rule ID(s) before deleting.

```graphql
mutation DeleteRollupRules($ruleIds: [Int]!) {
  deleteSubTransactionRollupRules(ruleIds: $ruleIds) {
    results { deletedIds failures { ruleId reason } }
  }
}
```
Report `deletedIds` (succeeded) and `failures` (with reasons — typically the rule is
already active).

---

## Rule Field Reference (RollupRule)

**Required:** `internalAccountId` (int), `assetId` (asset key), `platform` (enum),
`balanceFactor` (INFLOW/OUTFLOW), `fees` (INCLUDE/EXCLUDE/ONLY).

**Optional (have safe defaults — only set when needed):** `senderIdentifier`,
`recipientIdentifier`, `originalSenderPrefix`, `originalRecipientPrefix`, `methodIds`
(list), `maxAmount`, `minAmount`, `excludeFiat` (default false), `excludeInternal` (default
false), `subtxType` (FinancialAction), `bufferInDays` (default 0; days to wait for
late-arriving txs), `cutoffTime` ("HH:MM"), `rollupInternalTransfersOnly` (default false;
when true, only internal transfers are rolled up and the rollup is paired with its inflow —
the system also sets `mergeWithInflowTx` and `runInternalTransferClassificationOnRollups`).

**Top-level request fields:** `name` (required), `interval` (required), `rule` (required),
`startDate` (optional), `endDate` (optional), `ruleId` (optional — edit a pending rule),
`createdBy` (set `AI`).

**FinancialAction enum values (for `subtxType`):** TRACE_TRANSFER, TOKEN_TRANSFER,
NATIVE_TRANSFER, DELEGATION, UNDELEGATION, VEST, UNVEST, VALIDATOR_CREATION, REWARD,
COMMISSION, GAS, FEE, EXCHANGE_WITHDRAWAL, EXCHANGE_DEPOSIT, EXCHANGE_TRANSFER,
EXCHANGE_BUY, EXCHANGE_SELL, EXCHANGE_LOAN, EXCHANGE_SETTLEMENT, REBATE, FIAT_TRANSFER,
BURNED, ROLLUP, ROLLUP_FEE, PLUG, GROUP, FUNDING, INTEREST, TRANSFER_DELEGATION_REWARD,
REEVALUATION, PAYMENT, BANK_DEPOSIT, BANK_WITHDRAWAL, MINING_REWARD.

---

## Rules

- **KEEP CONTEXT SMALL** — use aggregations, never fetch full result sets.
- **Run discovery queries in parallel** where possible.
- **ALWAYS run the Step 2.5 rollup_review gate** before presenting.
- **ALWAYS produce both the HTML report AND the proposal table** after analysis.
- **Explain your reasoning** for each proposed rule.
- **Always confirm before creating** — present the full proposal and wait for explicit
  approval before calling the create mutation.
- **Provide a brief conversational summary** after presenting the report.
- **Incorporate user clustering guidance** when choosing dimensions.

---

## Limitations — not available via MCP

1. **Editing active rules** — there is no edit for an active rule; recreate (PENDING rules
   can be edited via `ruleId`, or deleted and recreated).
2. **Activating/deactivating rules** — managed by the backend processing pipeline, not
   directly controllable via API.
3. **Viewing rollup breakdown** — the detailed breakdown of which raw transactions were
   aggregated is in the Rollup Breakdown report in the TRES dashboard.
4. **Active rule deletion** — only PENDING rules can be deleted via the API; direct the
   user to TRES support for active rules.
