---
name: tres-cost-basis
description: >
  Manage cost basis calculation in TRES Finance: check status, view/change strategy
  (FIFO, LIFO, AVG, MAX_GAINS, MAX_LOSSES, FIFO_IMPAIRMENT), trigger recalculation,
  review financial issues, manage reevaluations/impairments, set bulk fiat prices,
  configure spec-ID lot disposal rules, view per-asset cost basis results, and
  export cost basis reports. Trigger this skill whenever the user asks about cost basis,
  gains/losses, realized gains, unrealized gains, COGS, inventory lots, tax lots,
  cost basis strategy, reevaluation, impairment, fiat value override, spec-ID rules,
  financial issues (negative balance, missing fiat), or anything related to how
  their crypto assets are costed. Also trigger when the user says "calculate cost basis",
  "what is my cost basis strategy", "show me financial issues", "create a reevaluation",
  "run cost basis", "change strategy to LIFO", or similar.
compatibility: "Requires TRES Finance MCP connector"
---

# TRES Finance — Cost Basis Management

End-to-end skill for managing cost basis calculation, strategy configuration,
reevaluations, financial issue review, and related operations in TRES Finance.

---

## MCP Server

All calls use the `user-tres-finance` MCP server (the TRES Finance MCP connector).

All variable keys and nested input fields MUST use **camelCase** (e.g. `assetClassId`, not `asset_class_id`).

---

## Step 1 — Authenticate and confirm org

Call `get_viewer` with no arguments. Confirm the org name with the user if there
is any ambiguity.

---

## Step 2 — Ensure a cost basis strategy is defined (gate before calculation)

Before any cost basis calculation can run, the organization must have a strategy
defined. This step is a **prerequisite gate** — run it automatically whenever the
user wants to calculate cost basis (Section D), or when they first ask for help
with cost basis.

1. Fetch the current strategy using the query in Section B.
2. If `defaultStrategy` is returned (any valid value like FIFO, LIFO, etc.),
   the strategy is already set — **skip ahead** and inform the user:
   > "Your cost basis strategy is set to [STRATEGY]. Proceeding."
3. If no strategy is configured (the query returns null or an error), present
   the user with all available methods and ask them to choose:

   > "Before calculating cost basis, you need to choose a costing method.
   > Here are the available strategies:
   >
   > 1. **FIFO** — First-in, first-out. Earliest acquired lots are disposed first. The most common method.
   > 2. **LIFO** — Last-in, first-out. Most recently acquired lots are disposed first.
   > 3. **AVG** — Weighted average cost across all lots.
   > 4. **MAX_GAINS** — Disposes lowest-cost lots first, maximizing realized gains.
   > 5. **MAX_LOSSES** — Disposes highest-cost lots first, maximizing realized losses (useful for tax-loss harvesting).
   > 6. **FIFO_IMPAIRMENT** — FIFO with impairment accounting support (for orgs using impairment write-downs).
   >
   > Which method would you like to use?"

4. Once the user picks a strategy, set it using the mutation in Section C
   (with an empty `strategyPeriods` array if they just want a single default).
5. Then proceed to the requested operation (typically Section D — trigger calculation).

This gate ensures no calculation runs without an explicit strategy choice.

---

## Step 3 — Run cost basis calculation

After confirming strategy, check the current calculation status (Section A) and
offer to run or re-run the calculation:

1. Fetch status using the query in Section A.
2. If `status` is `IN_PROGRESS`, inform the user it's already running and offer
   to wait:
   > "Cost basis calculation is currently in progress (started at [time]). Would you like me to wait for it to finish?"
3. If `status` is `DONE`, show when it last ran and ask:
   > "Cost basis was last calculated on [lastFinishedAt]. Would you like to
   > recalculate now, or view the existing results?"
4. If `status` is `ITEM_NOT_FOUND`, this org has never calculated — proceed
   directly to trigger.
5. When the user confirms (or on first-time run), trigger the calculation
   using the mutation in Section D.
6. **Poll status** every ~10 seconds until `status = "DONE"`.
7. Once done, automatically proceed to show results per asset (Section E)
   and financial issues (Section F).

This step ensures the user always has fresh results and understands the
calculation state before viewing data.

---

## Available operations

Based on the user's request, follow the appropriate section below.
Many users will come in with a general question like "help me with cost basis" —
in that case, run Steps 1–3 (authenticate, check strategy, run calculation),
then show results.

---

## A. Check cost basis calculation status

Use this when the user asks whether cost basis is running, done, or when it last ran.

```graphql
query CostBasisGetStatus {
  costBasisGetStatus {
    status
    firstStartedAt
    lastFinishedAt
    updatedAt
  }
}
```

`status` values: `DONE`, `IN_PROGRESS`, `ITEM_NOT_FOUND` (never calculated).

Report the status clearly. If `IN_PROGRESS`, let the user know it's still running
and they should wait. If `DONE`, report when it last finished.

---

## B. View current cost basis strategy

Fetches the default strategy and any date-specific strategy overrides.

```graphql
query GetCostBasisStrategyByDate {
  getCostBasisStrategyByDate {
    response {
      strategyPeriods {
        startDate
        endDate
        strategy
      }
      defaultStrategy
    }
  }
}
```

Present the default strategy and any period overrides clearly. Strategies:
`FIFO`, `LIFO`, `AVG`, `MAX_GAINS`, `MAX_LOSSES`, `FIFO_IMPAIRMENT`.

Explain what each means if the user asks:
- **FIFO** — First-in, first-out. Earliest acquired lots are sold first.
- **LIFO** — Last-in, first-out. Most recently acquired lots are sold first.
- **AVG** — Weighted average cost across all lots.
- **MAX_GAINS** — Sells lowest-cost lots first, maximizing realized gains.
- **MAX_LOSSES** — Sells highest-cost lots first, maximizing realized losses (tax-loss harvesting).
- **FIFO_IMPAIRMENT** — FIFO with impairment accounting support.

---

## C. Update cost basis strategy

Use when the user wants to change the default strategy or set strategy periods.

**Always confirm with the user before executing** — changing strategy affects all
future cost basis calculations and requires a recalculation.

```graphql
mutation UpdateCostBasisStrategyByDate(
  $defaultStrategy: CostBasisStrategy!,
  $strategyPeriods: [CBStrategyPeriodInput]!
) {
  updateCostBasisStrategyByDate(
    defaultStrategy: $defaultStrategy,
    strategyPeriods: $strategyPeriods
  ) {
    success
    message
  }
}
```

Variables example:
```json
{
  "defaultStrategy": "FIFO",
  "strategyPeriods": [
    {
      "startDate": "2024-01-01T00:00:00Z",
      "endDate": "2024-12-31T23:59:59Z",
      "strategy": "LIFO"
    }
  ]
}
```

`CostBasisStrategy` enum values: `FIFO`, `FIFO_IMPAIRMENT`, `LIFO`, `AVG`, `MAX_GAINS`, `MAX_LOSSES`.

If updating to a period-based config, first fetch the existing periods (Section B)
so you don't accidentally overwrite them — the mutation replaces ALL periods.

After a successful strategy change, ask the user if they want to trigger a
cost basis recalculation (Section D).

---

## D. Trigger cost basis calculation

**Prerequisite**: Before triggering, run **Step 2** (strategy gate) to ensure a
strategy is defined. If none is set, the user must choose one first.

Starts (or restarts) the cost basis calculation. Can target specific assets or
recalculate everything.

```graphql
mutation TriggerCostBasis($assetClassIds: [Int]) {
  triggerCostBasis(assetClassIds: $assetClassIds) {
    success
  }
}
```

- To recalculate **everything**: pass `assetClassIds: null` (or omit it).
- To recalculate **specific assets**: pass an array of asset class IDs, e.g. `[42, 88]`.

To find asset class IDs, query `assetBalance` or `assetClass` first:
```graphql
query AssetClasses($limit: Int) {
  assetClass(limit: $limit) {
    results { id symbol name }
  }
}
```

### After triggering — poll until completion

After a successful trigger (`success: true`), **poll the status** using the
query from Section A. The calculation typically takes 10–60 seconds for small
orgs but can take minutes for large ones.

```
1. Trigger → success: true
2. Poll costBasisGetStatus every ~10 seconds
3. When status = "DONE" → proceed to show results (Section E)
```

Do NOT present results or offer report downloads until status is `DONE`.
While `IN_PROGRESS`, show a brief wait message to the user.

---

## E. View cost basis results per asset

Shows the cost basis breakdown per asset-wallet pair — total cost, realized
gains, COGS, running inventory, and more.

**Important**: Use the `assetBalance` query (NOT `organizationBalance`). The
`assetBalance` query returns per-wallet asset rows, each with a nested
`costBasis` field from `FifoCostBasisQuery`.

```graphql
query AssetBalanceWithCostBasis($limit: Int, $offset: Int) {
  assetBalance(limit: $limit, offset: $offset) {
    totalCount
    results {
      asset {
        symbol
        name
      }
      belongsTo {
        name
      }
      calculatedBalance
      assetFifoCostBasis
      totalProfitLoss
      costBasis {
        costBasis
        totalRealizedGains
        totalShortTermRealizedGains
        totalLongTermRealizedGains
        totalCost
        totalRunningInventoryQuantity
        cogs
        proceeds
        runningBalance
      }
    }
  }
}
```

Variables: `{"limit": 50, "offset": 0}`

Paginate if `totalCount` > 50 — increment `offset` by 50 and fetch again until
all results are retrieved.

### Key fields explained

- `assetFifoCostBasis` — The total cost basis for this asset-wallet pair (top-level shortcut).
- `totalProfitLoss` — Total realized P&L (top-level shortcut).
- `costBasis` — Nested object with full detail (null if not calculated):
  - `costBasis` / `totalCost` — Total cost of current inventory.
  - `totalRealizedGains` — Net realized gains/losses.
  - `totalShortTermRealizedGains` / `totalLongTermRealizedGains` — Split by holding period.
  - `cogs` — Cost of goods sold for disposals.
  - `proceeds` — Total proceeds from disposals.
  - `totalRunningInventoryQuantity` — Current inventory quantity.
  - `runningBalance` — Running token balance.

### Presenting results — the full picture

After fetching all pages, split the results into two groups:

**Group 1 — Assets with cost basis data** (`costBasis` is not null):
Present as a table sorted by absolute realized P&L descending, with columns:
Asset, Wallet, Holdings, Cost Basis ($), Realized P&L ($).
Use color coding: green/+ for gains, red/- for losses.

**Group 2 — Assets without cost basis** (`costBasis` is null AND `calculatedBalance` != 0):
These are assets where cost basis was NOT calculated — usually because of missing
fiat values, no transactions, or unverified/spam assets. Present them separately
under a clear heading like:

> **Assets without cost basis data:**
> The following assets have balances but no cost basis calculated. This typically
> means they have missing fiat prices that need to be resolved before cost basis
> can be computed.

Show: Asset, Wallet, Holdings, and a note about likely cause (spam token, NFT,
missing fiat, etc.).

**Always show both groups** so the user sees the complete picture. If Group 2
contains any non-trivial assets (not spam/virtual), also run the financial
issues query (Section F) filtered to HIGH severity to check for `missing_fiat`
issues, and report them alongside.

When missing fiat issues are found, **automatically look up historical prices**
using the pricing query (Section G.1) for each affected asset at the transaction
timestamp. Present the looked-up prices to the user and offer to apply them
using bulk fiat edit (Section G.2).

**Recommended**: Generate an HTML dashboard file with styled tables for both
groups plus a financial issues summary. Save it to the outputs folder and
share the link with the user.

Use standard number formatting:
- Fiat values >= $1M: "$X.XXXM", >= $1K: "$X.XXK", else "$X.XX"
- Positive gains: "+" prefix, negative: "-" prefix

---

## F. View financial issues

Financial issues are problems detected during cost basis calculation — negative
balances, missing fiat values, circular transfers, etc.

```graphql
query FinancialIssues($limit: Int, $offset: Int, $severity: String) {
  financialIssue(limit: $limit, offset: $offset, severity: $severity) {
    totalCount
    results {
      id
      type
      severity
      message
      balanceImpact
      assetClass {
        id
        symbol
        name
      }
      assetClassId
      internalAccount {
        name
      }
      internalAccountId
      tx {
        identifier
        timestamp
      }
      subTx {
        id
        amount
      }
    }
  }
}
```

### Filter options

**Important**: Filter values must be **lowercase** — the API uses DB-stored values.

- `severity`: `"high"`, `"medium"`, `"low"`
- Do **NOT** filter by `type` directly in the query — instead, fetch all issues
  and filter/group in the presentation. The `type` filter uses internal DB values
  that may not match the display names.

### Actual issue types returned

The `type` field returns lowercase strings like:
- `missing_fiat` — Sub-transaction has no fiat price. Affects cost basis accuracy.
  Can be resolved with bulk fiat edit (Section G).
- `negative_balance` — Inventory went below zero (more sold than acquired). Usually
  means missing inflow transactions.
- `result_was_rounded` — Minor rounding occurred during calculation. Low severity.
- `ignored` — Sub-transaction was skipped (e.g. internal transfer to same account).
- `no_opposite_tx` — Internal transfer has no matching counterpart.
- `circular_internal_sbxs` — Circular dependency in internal transfer matching.

Group results by severity and present HIGH issues first. The most common pattern
is a handful of HIGH severity `missing_fiat` issues plus many LOW severity
`result_was_rounded` issues — summarize the LOW ones as a count rather than
listing each individually.

---

## G. Fix missing fiat values

This is a two-part flow: first look up historical prices, then apply them.

### G.1 — Look up historical token prices

Use the TRES MCP pricing queries to fetch historical prices for tokens with
missing fiat values. This uses the platform's pricing engine which aggregates
from CoinGecko, CoinMarketCap, exchanges, and other sources.

**For a single asset at a specific timestamp:**

```graphql
query GetStatelessPricing(
  $platform: Platform!,
  $assetIdentifier: String!,
  $currencies: [Currency]!,
  $timestamp: DateTime
) {
  getStatelessPricing(
    platform: $platform,
    assetIdentifier: $assetIdentifier,
    currencies: $currencies,
    timestamp: $timestamp
  ) {
    prices
    assetClassId
    symbol
  }
}
```

Variables example:
```json
{
  "platform": "ETHEREUM",
  "assetIdentifier": "0x...contractAddress",
  "currencies": ["USD"],
  "timestamp": "2020-11-24T09:01:26Z"
}
```

**For multiple assets at once (by asset class ID):**

```graphql
query GetBatchPricing($requests: [GetBatchPricesByAssetClassRequest]!) {
  getBatchStatelessPricingByAssetClass(requests: $requests) {
    prices
    assetClassId
    symbol
  }
}
```

Variables example:
```json
{
  "requests": [
    {
      "assetClass": "4272",
      "currencies": ["USD"],
      "timestamp": "2018-06-18T19:13:45Z"
    },
    {
      "assetClass": "4272",
      "currencies": ["USD"],
      "timestamp": "2020-11-24T09:01:26Z"
    },
    {
      "assetClass": "9082",
      "currencies": ["USD"],
      "timestamp": "2020-11-27T20:06:54Z"
    }
  ]
}
```

The `prices` field returns a JSON object like `{"usd": 0.015}`.

**How to use this in the missing fiat flow:**

1. From the financial issues (Section F), collect each `missing_fiat` issue's
   `assetClass.id` and `tx.timestamp`.
2. Call `getBatchStatelessPricingByAssetClass` with one request per issue.
3. Present the results to the user:
   > "I found historical prices for the missing fiat transactions:
   > - CHSB on 2018-06-18: $0.015 per token
   > - CHSB on 2020-11-24: $0.085 per token
   > - vBUSD on 2020-11-27: $0.021 per token
   >
   > Would you like me to apply these prices?"
4. If the user confirms, apply them using Section G.2 (bulk fiat edit).

**Pricing sources to try**: If the default source returns empty, try these
`apiSource` values in order: `COINMARKETCAP`, `CRYPTO_COMPARE`, `REGULAR_FLOW`,
`COINBASE`, `BINANCE`, `KRAKEN`. Pass the `apiSource` field in the request:

```json
{
  "requests": [
    { "assetClass": "4272", "currencies": ["USD"], "timestamp": "2020-11-24T09:01:26Z", "apiSource": "COINMARKETCAP" }
  ]
}
```

**Important**: The pricing query returns `prices: {}` (empty object) when no
price data is available — this is common for obscure, delisted, or DeFi-wrapped
tokens. Try multiple sources before giving up.

If ALL pricing sources return empty for a token, inform the user and ask them
to provide a manual price. Suggest approximate values if you know the token
(e.g. BUSD-pegged tokens ≈ $1.00).

### G.2 — Bulk fiat value edit

Override fiat unit prices for an asset across a date range. Useful for fixing
MISSING_FIAT issues or correcting OTC prices.

**Always confirm parameters with the user before executing** — this writes
fiat values to potentially many sub-transactions.

```graphql
mutation BulkFiatEdit(
  $assetClassId: Int!,
  $currency: Currency!,
  $startDate: Date!,
  $endDate: Date!,
  $unitPrice: Float!,
  $updateExistingFiat: Boolean
) {
  bulkFiatEdit(
    assetClassId: $assetClassId,
    currency: $currency,
    startDate: $startDate,
    endDate: $endDate,
    unitPrice: $unitPrice,
    updateExistingFiat: $updateExistingFiat
  ) {
    success
    message
  }
}
```

Variables example:
```json
{
  "assetClassId": 42,
  "currency": "USD",
  "startDate": "2024-01-01",
  "endDate": "2024-01-31",
  "unitPrice": 1.0,
  "updateExistingFiat": false
}
```

- `updateExistingFiat: false` (default) — only fills in missing fiat values.
- `updateExistingFiat: true` — overwrites all fiat values in the range.

To find the `assetClassId`, query `assetClass` by symbol first.

When applying prices from G.1, use the looked-up unit price and set the date
range tightly around the transaction date (same day for `startDate` and `endDate`)
to avoid overwriting prices on other transactions.

After bulk fiat edits, suggest the user trigger a cost basis recalculation (Section D).

---

## H. Reevaluations and impairments

Reevaluations adjust the fair market value (FMV) of inventory lots at a specific
point in time. Impairments are a special case where the FMV drops below cost.

### H.1 — List reevaluations

```graphql
query GetReevaluations($limit: Int, $offset: Int, $assetClassId_In: [ID]) {
  reevaluation(
    limit: $limit,
    offset: $offset,
    assetClassId_In: $assetClassId_In,
    ordering: "-timestamp"
  ) {
    totalCount
    results {
      id
      timestamp
      unitPrice
      currency
      isImpairment
      assetClass {
        id
        symbol
      }
      appliedCostBasis {
        id
        totalCost
        revaluedCostAdjustment
        internalAccount {
          id
          name
        }
      }
    }
  }
}
```

### H.2 — Create reevaluation

**Always confirm with the user before executing.**

```graphql
mutation CreateReevaluation($reevaluations: [ReevaluationObjectType]!) {
  createReevaluation(reevaluations: $reevaluations) {
    reevaluationIds
  }
}
```

Variables example:
```json
{
  "reevaluations": [
    {
      "unitPrice": "45000.00",
      "timestamp": "2024-12-31T23:59:59Z",
      "assetClassId": 1,
      "currency": "USD",
      "isImpairment": false
    }
  ]
}
```

- `isImpairment: false` — standard reevaluation (mark-to-market).
- `isImpairment: true` — impairment write-down.

Creating a reevaluation also creates a manual transaction to represent the
adjustment in the ledger. Inform the user of this side effect.

After creating, suggest triggering cost basis recalculation (Section D).

### H.3 — Update reevaluation

```graphql
mutation UpdateReevaluation(
  $reevaluationId: Int!,
  $unitPrice: Decimal!,
  $timestamp: DateTime!,
  $assetClassId: Int!,
  $currency: Currency!
) {
  updateReevaluation(
    reevaluationId: $reevaluationId,
    unitPrice: $unitPrice,
    timestamp: $timestamp,
    assetClassId: $assetClassId,
    currency: $currency
  ) {
    status
  }
}
```

### H.4 — Delete reevaluation

```graphql
mutation DeleteReevaluation($reevaluationId: Int!) {
  deleteReevaluation(reevaluationId: $reevaluationId) {
    status
  }
}
```

Deleting also removes the associated manual transaction from the ledger.

---

## I. Spec-ID rules (specific lot disposal)

Spec-ID rules let the user specify exactly which acquisition lot to use when
disposing of an asset — overriding the default strategy (e.g. FIFO) for
specific transactions.

### I.1 — View spec-ID rules

```graphql
query CostBasisSpecIdRules(
  $limit: Int,
  $offset: Int,
  $outflowSubTransaction_In: [String]
) {
  costBasisSpecIdRule(
    limit: $limit,
    offset: $offset,
    outflowSubTransaction_In: $outflowSubTransaction_In
  ) {
    totalCount
    results {
      id
      outflowSubTransaction {
        id
        amount
        timestamp
        asset { symbol }
        belongsTo { name }
      }
      disposedLotSubTransaction {
        id
        amount
        timestamp
      }
      amountToDispose
      priority
    }
  }
}
```

### I.2 — Set spec-ID rules

**Always confirm with the user before executing.** This replaces all existing
rules for the given outflow sub-transaction.

```graphql
mutation SetSpecIdRules(
  $subTransactionId: ID!,
  $specIdRules: [SpecIdRuleInput]!
) {
  setSpecIdRules(
    subTransactionId: $subTransactionId,
    specIdRules: $specIdRules
  ) {
    success
  }
}
```

Variables example:
```json
{
  "subTransactionId": "12345",
  "specIdRules": [
    {
      "disposedLotSubTransactionId": "67890",
      "amount": 1.5,
      "priority": 1
    },
    {
      "disposedLotSubTransactionId": "67891",
      "amount": 0.5,
      "priority": 2
    }
  ]
}
```

- `subTransactionId` — the outflow (disposal) sub-transaction
- `disposedLotSubTransactionId` — the inflow (acquisition) sub-transaction to use as the cost lot
- `amount` — how much of that lot to dispose
- `priority` — processing order (1 = first)

After setting rules, suggest triggering cost basis recalculation (Section D).

### I.3 — Delete spec-ID rules

```graphql
mutation DeleteSpecIdRules($subTransactionId: ID!) {
  deleteSpecIdRules(subTransactionId: $subTransactionId) {
    success
  }
}
```

---

## J. Full inventory configuration

By default, TRES trims old inventory lots to reduce storage. For specific
transactions where the user needs the complete inventory queue visible, toggle
full inventory saving.

```graphql
mutation SetFullCostBasisInventoryConfiguration(
  $subTransactionId: ID,
  $enableFullInventory: Boolean
) {
  setFullCostBasisInventoryConfiguration(
    subTransactionId: $subTransactionId,
    enableFullInventory: $enableFullInventory
  ) {
    success
  }
}
```

This deletes existing cost basis records for the affected asset and triggers
a recalculation automatically.

---

## K. Export cost basis reports

TRES offers several cost basis report types. Use the `availableReportTypes` query
to find available exports, then trigger via `organizationBalance`:

```graphql
query AvailableReports {
  availableReportTypes {
    name
    exportType
    entitiesType
    llmDescription
  }
}
```

Cost-basis-related report types include:
- `COST_BASIS_STACK_PER_ACCOUNT` — Inventory lots grouped by wallet
- `COST_BASIS_STACK_PER_ASSET` — Inventory lots grouped by asset
- `COST_BASIS_INVENTORY` — Full inventory detail
- `COST_BASIS_ROLL_FORWARD` — Period-over-period roll forward
- `REEVALUATION` — Reevaluation records

To export, use `organizationBalance` with export parameters:
```graphql
query ExportCostBasisReport(
  $exportName: String,
  $exportFormat: String,
  $currency: String,
  $outputFormat: ReportOutputFormat
) {
  organizationBalance(
    exportName: $exportName,
    exportFormat: $exportFormat,
    currency: $currency,
    outputFormat: $outputFormat
  ) {
    totalCount
  }
}
```

Variables example:
```json
{
  "exportName": "Cost Basis Stack Per Asset - April 2024",
  "exportFormat": "COST_BASIS_STACK_PER_ASSET",
  "currency": "usd",
  "outputFormat": "XLSX"
}
```

Then poll the `report` query until `status = "DONE"` and provide the download link:

```graphql
query Reports($limit: Int, $offset: Int) {
  report(limit: $limit, offset: $offset, ordering: "-created_at") {
    totalCount
    results {
      id
      name
      status
      downloadUrl
      createdAt
    }
  }
}
```

**Critical**: Do NOT present the download link while status is `IN_PROGRESS` —
the file has not been written to S3 yet and the link will return a NoSuchKey
error. Poll every ~10 seconds until status = `"DONE"`, then present the
`downloadUrl` to the user.

---

## Guardrails

- **Confirm before writes**: Always confirm with the user before executing any
  mutation (strategy change, reevaluation, spec-ID rules, bulk fiat edit, trigger calc).
- **Recalculation reminder**: After any configuration change (strategy, reevaluation,
  spec-ID, fiat edit), remind the user that cost basis needs to be recalculated for
  changes to take effect.
- **Locked periods**: If a mutation fails with a "locked period" error, inform the
  user that the timestamp falls within a locked accounting period and they may need
  to unlock it first.
- **Status check before trigger**: Before triggering a recalculation, check the
  current status — if already `IN_PROGRESS`, let the user know it's still running.

---

## Limitations — not available via MCP

The following cost basis features exist in the backend but are NOT exposed through
the MCP GraphQL API, so this skill cannot perform them:

1. **Per-wallet reallocation flow** — The two-phase reallocation process
   (unified inventory -> per-wallet split) is an internal backend operation
   triggered by org settings, not directly callable via API.

2. **Viewing raw inventory queue details** — The `assetRunningQueueFifo` field
   is available on `FifoCostBasisQuery` but returns large JSON blobs. The queue
   data is best viewed through the TRES dashboard or via exported reports
   (COST_BASIS_STACK_PER_ACCOUNT / COST_BASIS_STACK_PER_ASSET).

3. **Short position / loan queue management** — Short position tracking (loan
   queue) is configured at the org-settings level and computed automatically.
   There is no direct API to view or manipulate the loan queue.

4. **Cost basis calculation internals** — The actual calculation engine
   (CostBasisCalculator, CostBasisManager) runs server-side. We can trigger it
   and read results, but cannot control the internal calculation flow, caching,
   or S3 queue persistence.

5. **Internal transfer cost basis mapping** — How cost basis is carried over
   between wallets in internal transfers is automatic and not configurable
   per-transaction via the API.

For any of these, direct the user to the TRES Finance dashboard or suggest
exporting the relevant cost basis report for offline analysis.
