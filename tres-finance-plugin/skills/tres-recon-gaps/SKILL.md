---
name: tres-recon-gaps
description: >
  Query, display, and resolve reconciliation gaps from the TRES Finance MCP connector.
  Trigger this skill ONLY when the user explicitly requests to view or close reconciliation
  gaps — for example: "show me the reconciliation gaps", "close the recon gaps", "view gaps
  for today", "plug the reconciliation gaps for ETH", "fix the gaps for USDC and BTC".
  Do NOT trigger for general balance queries, transaction history, or ledger browsing.
  Covers the full workflow: confirming the target date, optionally filtering by asset,
  fetching gap data, enriching with fiat and on-chain balances, rendering an HTML dashboard
  where each gap row has copy-prompt buttons (Plug / Auto-fill) — clicking copies a
  ready-to-paste Claude prompt for that gap. The user pastes it in the chat and Claude
  executes the action. Ends with a data collect once the user is done.
compatibility: "Requires TRES Finance MCP connector"
---

# TRES Reconciliation Gaps Skill

End-to-end workflow for surfacing, analyzing, and resolving reconciliation gaps in TRES Finance.

---

## Pre-flight: confirm date and asset scope

**Before fetching any data**, confirm two things with the user:

### 1. Target date

The reconciliation queries are scoped to a specific date (the `endDate` parameter).

- If the user **explicitly stated a date** — use it.
- If the user **did not mention a date** — assume today's date and inform them:
  > "I'll fetch reconciliation gaps for today (YYYY-MM-DD). Let me know if you want a different date."

Use ISO format `YYYY-MM-DD` throughout.

### 2. Asset filter (optional)

- If the user **named specific assets** (e.g. "for ETH and USDC", "just BTC") — note them. After fetching, filter the results to only those `asset.symbol` values before displaying.
- If the user **did not specify assets** — fetch and display all gaps.

---

## Step 1 — Fetch reconciliation gaps

Use the `reconciliation` query. Always pass the confirmed `endDate`. Fetch up to 200 at a time.

```graphql
query GetReconciliationGaps($limit: Int, $offset: Int, $endDate: Date) {
  reconciliation(limit: $limit, offset: $offset, endDate: $endDate) {
    totalCount
    results {
      id
      amount
      calculatedBalance
      state
      status
      gap
      belongsTo {
        id
        name
        identifier
      }
      asset {
        key
        identifier
        symbol
        platform
      }
      pendingTransactionsCount
      pendingTransactionsTotalAmount
    }
  }
}
```

Variables: `{"limit": 200, "offset": 0, "endDate": "<confirmed-date>"}`

> Note: `gap` = `calculatedBalance − historicalBalance`. Positive means the ledger has *more* than on-chain; negative means the ledger has *less*.

If the user requested specific assets, filter the results now: keep only rows where `asset.symbol` matches the requested symbols (case-insensitive).

---

## Step 2 — Enrich with fiat values and on-chain balances

Take all IDs from the (filtered) Step 1 results and query `assetBalance`:

```graphql
query GetAssetBalancesWithFiat($ids: [String], $limit: Int, $currency: String) {
  assetBalance(id_In: $ids, limit: $limit, currency: $currency, excludeUnderDelegation: true) {
    totalCount
    results {
      id
      calculatedBalance
      historicalBalance
      reconciliation
      fiatValue {
        value
        unitPrice
        fiatCurrency
      }
      belongsTo {
        id
        name
        identifier
      }
      asset {
        key
        symbol
        platform
        identifier
      }
    }
  }
}
```

Variables: `{"currency": "usd", "ids": ["<id1>", "<id2>", ...], "limit": 200}`

**Important**: `id_In` expects `[String]`, not `[ID]`.

Compute for each row:
```
fiatGap = reconciliation (token gap) × fiatValue.unitPrice
```

---

## Step 3 — Display: always render the HTML dashboard

**Always** generate a standalone `.html` file as the primary output — do not fall back to an inline widget.

Read `references/html-template-notes.md` for the full visual spec (fonts, colors, layout, column widths, modal behavior, API call mechanism).

Key requirements for the generated file:
- Dark financial dashboard aesthetic (spec in reference file)
- Sticky header showing the **target date** and a refresh timestamp badge
- 5 summary metric cards: net fiat gap, positive gap count, negative gap count, asset group count, pending tx count
- If an **asset filter** was applied, show a visible filter badge in the toolbar (e.g. `Filtered: ETH, USDC`)
- Search + direction filter + platform filter toolbar
- Asset-grouped collapsible sections, sorted by absolute net fiat gap descending
- Full column set per row — last column has two copy-prompt buttons: **↳ Plug** (blue) and **⟳ Auto-fill** (purple)
- Clicking either button copies a ready-to-paste prompt to clipboard and shows a toast: "Prompt copied — paste it in the Claude chat to resolve this gap."
- **No HTTP requests** — the HTML is a pure display interface; all mutations happen in Claude after the user pastes the prompt

After generating the file, present it to the user with `present_files`.

---

## Step 4 — Actions (plug-once and auto-fill)

The user triggers actions by copying a prompt from the HTML dashboard and pasting it into the Claude chat. When Claude receives one of these prompts, execute the corresponding mutation immediately — no further confirmation needed (the user already chose the action in the dashboard).

### One-time plug (`createPlug`)

```graphql
mutation CreatePlug(
  $hash: String!
  $platform: Platform!
  $timestamp: DateTime!
  $belongsToId: ID!
  $assetId: ID!
  $assetIdentifier: String!
  $amount: Float!
  $direction: Direction!
  $thirdPartyIdentifier: String!
) {
  createPlug(
    hash: $hash
    platform: $platform
    timestamp: $timestamp
    belongsToId: $belongsToId
    assetId: $assetId
    assetIdentifier: $assetIdentifier
    amount: $amount
    direction: $direction
    thirdPartyIdentifier: $thirdPartyIdentifier
  ) {
    transaction { id identifier platform timestamp }
  }
}
```

**Variable mapping:**
| Field | Value |
|---|---|
| `hash` | `plug_<assetId>_<walletId>_<timestamp_ms>` |
| `platform` | `asset.platform` |
| `timestamp` | `new Date().toISOString()` |
| `belongsToId` | `belongsTo.id` |
| `assetId` | `asset.key` |
| `assetIdentifier` | `asset.identifier` (use `"native"` for native assets like ETH/AVAX) |
| `amount` | `Math.abs(gap)` |
| `direction` | `gap > 0 ? "INFLOW" : "OUTFLOW"` |
| `thirdPartyIdentifier` | `belongsTo.identifier` (wallet address) |

### Auto gap-fill rule (`createReconciliationGapFillRule`)

```graphql
mutation CreateGapFillRule(
  $name: String!
  $assetId: String!
  $internalAccountId: Int!
  $interval: Interval!
  $startDate: Date!
  $endDate: Date!
) {
  createReconciliationGapFillRule(
    name: $name
    assetId: $assetId
    internalAccountId: $internalAccountId
    interval: $interval
    startDate: $startDate
    endDate: $endDate
  ) {
    success
    message
    ruleId
  }
}
```

**Variable mapping:**
| Field | Value |
|---|---|
| `name` | User-editable rule name (pre-filled: `Auto gap-fill · <asset> · <wallet>`) |
| `assetId` | `asset.key` |
| `internalAccountId` | `parseInt(belongsTo.id)` — must be `Int!` |
| `interval` | `DAILY` / `WEEKLY` / `MONTHLY` |
| `startDate` | ISO date string, e.g. `"2026-04-07"` |
| `endDate` | ISO date string (default: 2 years from today) |

---

## Step 5 — Run data collect after plugs are done

Once the user indicates they are **finished adding plugs** (e.g. "done", "that's all", "looks good"), run a data collect to sync the updated state.

Use the `triggerDataCollect` mutation (or equivalent — introspect with `get_schema_summary` if needed):

```graphql
mutation TriggerDataCollect {
  triggerDataCollect {
    success
    message
  }
}
```

After it completes, inform the user:
> "Data collect triggered — TRES will now sync the latest on-chain balances. The reconciliation gaps should update shortly."

---

## Grouping and sorting logic

**Default grouping: by asset symbol**
- Group all rows sharing the same `asset.symbol` into one group
- Net fiat gap shown per group header
- Sort groups by absolute net fiat gap descending
- Sort rows within each group by absolute fiat gap descending

**Alternative: group by wallet** (if user requests it)
- Group by `belongsTo.identifier`
- Same sorting logic

Always order by **fiat gap**, not token gap.

---

## Number formatting conventions

```js
// Fiat values
≥ $1M  → "$X.XXXM"
≥ $1K  → "$X.XXK"
< $1K  → "$X.XX"

// Token quantities
≥ 1B   → "X.XXXB"
≥ 1M   → "X.XXXM"
≥ 1K   → "X.XXXK"
< 1K   → up to 6 significant figures, trim trailing zeros

// Signs
Positive gaps: "+" prefix
Negative gaps: "−" (minus sign, not hyphen)
No sign:       absolute values (on-chain bal, calculated bal)
```

---

## Common edge cases

| Situation | Handling |
|---|---|
| `unitPrice = 0` | Show "—" for fiat gap; token gap still displays |
| `historicalBalance` is negative | Display as-is; flag visually if extreme |
| `pendingTransactionsCount > 0` | Show amber warning badge — pending txs may reduce the gap once confirmed |
| Very large token gaps with tiny fiat value | Still show; sort by fiat means they appear near bottom |
| `gap` field timeouts on large datasets | Use `assetBalance.reconciliation` field instead (same value, more reliable) |
| Asset filter yields zero rows | Inform the user: "No gaps found for [assets] on [date]" |

---

## Key schema facts (verified)

- `reconciliation` query — has `endDate` parameter; returns `gap` and basic balance fields
- `assetBalance` query — returns `historicalBalance`, `reconciliation` (= gap), and `fiatValue { value, unitPrice }`; **prefer for enriched data**
- `assetBalance(id_In: [String])` — note `[String]` not `[ID]`
- `createPlug` — `belongsToId` is `ID!`, `assetId` is `ID!` (pass the asset key string)
- `createReconciliationGapFillRule` — `internalAccountId` is `Int!`; `assetId` is `String!`; `interval` is `Interval!` enum
- Platform enum values: `ETHEREUM`, `BASE`, `ARBITRUM`, `OPTIMISM`, `POLYGON`, `AVAX`, `AVALANCHE_P_CHAIN`, `MANTRA`, etc.
