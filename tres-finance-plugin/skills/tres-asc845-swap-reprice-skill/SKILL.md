---
name: tres-asc845-swap-reprice-skill
description: >
  Reprice swap transaction legs under ASC 845 (Nonmonetary Transactions) to ensure clearing accounts
  net to zero. Use this skill whenever the user wants to: reprice swaps, fix clearing account residuals,
  apply equal-value exchange to swap legs, run setBatchUseCounterpartyFiatValue, zero out a clearing
  account, apply ASC 845, fix swap pricing mismatches, ensure no gain/loss on swaps, or close a month
  where a swaps/trade clearing account has a residual balance. Also trigger when the user mentions
  "counterparty fiat value", "swap repricing", "clearing account net to zero", or "equal value exchange".
compatibility: "Requires TRES Finance MCP connector"
---

# ASC 845 Swap Repricing Skill

## Purpose

Implements **equal-value exchange under ASC 845 (Nonmonetary Transactions)** for swap transactions
in TRES Finance. In a simultaneous swap, the fair value of the asset surrendered (outflow) is the
best evidence of the fair value of the asset received (inflow). This skill reprices inflow legs to
match outflow legs so that clearing accounts net to zero.

## When to Use

- A swaps/trade clearing account has a non-zero residual after month-end
- User wants to apply ASC 845 to a population of swap transactions
- User says "setBatchUseCounterpartyFiatValue" or similar

## MCP Server

All GraphQL calls use the **`user-tres-finance`** MCP server (`execute` tool).

Variable keys and nested input fields MUST use **camelCase** (e.g. `timestamp_Gte`, not `timestamp_gte`).

## Prerequisites

- TRES Finance MCP connection (`user-tres-finance`)
- The user must specify:
  1. **Target ERP account** — the clearing account to zero out (e.g. "Swaps Clearing Account", NS #818)
  2. **Transaction scope** — either a date range (timestamp_Gte / timestamp_Lte) or specific tx hashes
  3. **Confirmation** — user must approve before mutations are executed

## Workflow

### Step 1: Gather Parameters

Ask the user for:
- Target ERP account name or ID (the clearing account)
- Date range OR list of transaction hashes
- **Activity tags** (optional) — filter to only transactions with specific classification activities
  (e.g. "STAKING LOCKUP", "SWAP"). None, one, or many may be selected. If omitted, all activities
  are included. Use `tx_Classification_Activity_In` on the TRES query.
- Currency (default: USD)
- Whether to run in **dry-run** (preview only) or **execute** mode

### Step 2: Query Subtransactions

Use the TRES `subTransaction` query to fetch all subtransactions in scope. Include these fields:
```graphql
{
  id
  amount
  balanceFactor
  timestamp
  fiatValue
  isManualFiatValue
  belongsTo { id name }
  asset { assetClass { symbol } }
  tx { id identifier classification { activity } }
  flowRule {
    ruleName
    integrationAccount { name value }
  }
}
```

If activity tags were specified, pass them as `tx_Classification_Activity_In: ["STAKING LOCKUP", "SWAP"]`
on the query. Note: transactions with `classification: null` will be excluded when this filter is used,
so only apply it when the user explicitly requests it.

Paginate in batches of 50 (to avoid timeouts). Save the combined results to a JSON file for the orchestrator script.

### Step 3: Run the Orchestrator Script

From the skill `scripts/` directory, run `orchestrate_reprice.py` (handles MCP response shapes, account filter, preview, and mutation JSON):

```bash
cd "${CLAUDE_PLUGIN_ROOT}/skills/tres-asc845-swap-reprice-skill/scripts" && \
python3 orchestrate_reprice.py \
  --input /path/to/swap_reprice_input.json \
  --account-name "Swaps Clearing Account" \
  --output /path/to/reprice_plan.json \
  --mutations-output /path/to/reprice_mutations.json
```

Use `--account-value` instead of `--account-name` when filtering by ERP account number. Pass `--activity-tags SWAP "STAKING LOCKUP"` when the user requested activity filters.

The script prints a preview to stdout and writes:
- `reprice_plan.json` — full plan with per-transaction adjustments
- `reprice_mutations.json` — ready-to-execute `setManualFiatValue` variables

For lower-level repricing only (no orchestration), use `reprice_swaps.py` directly — see `scripts/reprice_swaps.py` for flags.

### Step 4: Repricing Logic (ASC 845)

The orchestrator implements the logic below. Read `scripts/reprice_swaps.py` for the canonical implementation.

The core principle: calculate the **difference** between total outflow fiat and total inflow fiat,
then distribute that difference across inflows **in proportion to their token amounts**. This
preserves the original pricing as a base and makes the minimum adjustment needed.

For each parent transaction:

**Case 1: One outflow, one inflow**
```
inflow.newFiatValue = outflow.fiatValue
```

**Case 2: One outflow, many inflows**
```
difference = outflow.fiatValue - sum(inflow.fiatValue for each inflow)
totalInflowTokens = sum(inflow.amount for each inflow)
for each inflow:
    tokenProportion = inflow.amount / totalInflowTokens
    inflow.newFiatValue = inflow.fiatValue + (difference * tokenProportion)
```

**Case 3: Many outflows, one inflow**
```
inflow.newFiatValue = sum(outflow.fiatValue for each outflow)
```

**Case 4: Many outflows, many inflows**
```
totalOutflowFiat = sum(outflow.fiatValue for each outflow)
totalInflowFiat = sum(inflow.fiatValue for each inflow)
difference = totalOutflowFiat - totalInflowFiat
totalInflowTokens = sum(inflow.amount for each inflow)
for each inflow:
    tokenProportion = inflow.amount / totalInflowTokens
    inflow.newFiatValue = inflow.fiatValue + (difference * tokenProportion)
```

**Worked example (Case 2):**
```
Before:  Outflow = 100 tokens @ $100 | Inflows = 25 tokens @ $25, 25 @ $25, 35 @ $35 (total $85)
         Difference = $100 - $85 = $15 | Total inflow tokens = 85

After:   Inflow 1: $25 + ($15 × 25/85) = $25 + $4.41 = $29.41
         Inflow 2: $25 + ($15 × 25/85) = $25 + $4.41 = $29.41
         Inflow 3: $35 + ($15 × 35/85) = $35 + $6.18 = $41.18
         Total inflows after = $100.00 ✓  (clearing account nets to zero)
```

**Edge cases:**
- If `totalInflowTokens == 0`, distribute the difference equally across inflows
- If a subtransaction already has `isManualFiatValue == true`, flag it for user review (it was already manually repriced)
- Skip transactions with only outflows or only inflows (not a complete swap)
- Last inflow in the group receives the remainder to absorb rounding (ensures exact match)

### Step 5: Preview the Reprice Plan

Present the orchestrator stdout summary and/or the plan JSON to the user:

```
TX Identifier | Outflow Total | Inflow Before | Inflow After | Adjustment
------------- | ------------- | ------------- | ------------ | ----------
0xabc...      | $1,234.56     | $1,230.00     | $1,234.56    | +$4.56
0xdef...      | $5,678.90     | $5,670.00     | $5,678.90    | +$8.90
```

Also show aggregate stats:
- Total transactions affected
- Total outflow fiat
- Total inflow fiat (before)
- Total inflow fiat (after)
- Net clearing account residual (before → after, should go to $0)
- Count of already-manually-priced subtxs being overwritten

### Step 6: Execute (with user confirmation)

**Never run mutations without explicit user confirmation.**

Only after the user confirms, execute `setManualFiatValue` for each inflow subtransaction (use variables from `reprice_mutations.json`):

```graphql
mutation SetManualFiatValue($id: ID!, $newFiatValue: String!, $currency: String) {
  setManualFiatValue(id: $id, newFiatValue: $newFiatValue, currency: $currency) {
    subTransaction {
      id
      fiatValue
      isManualFiatValue
    }
  }
}
```

Execute one at a time (not batch) to handle locked-period errors gracefully.
If `setBatchManualFiatValue` is preferred for speed, group inflows by asset
where a uniform per-unit price applies.

**Important**: `setManualFiatValue` takes `newFiatValue` as a string.
`setBatchManualFiatValue` takes `ids` (list) and `newUnitValue` (Float) and computes
`newUnitValue * amount` — only use this if all subtxs in the batch should have the same unit price.

### Step 7: Verify

Re-query the subtransactions and re-aggregate to confirm the clearing account now nets to zero.

## Error Handling

- **Locked period**: If a subtransaction is in a locked period, warn the user. They must unlock
  via `deleteLockedPeriod`, apply changes, then re-lock via `createLockedPeriod`.
- **Missing fiat values**: If outflow fiatValue is null, skip the transaction and flag it.
- **Zero-value legs**: If outflow total is $0, skip (nothing to propagate).
- **Already manual**: Flag but still overwrite — only after the user confirmed the batch.

## Script Reference

| Script | Role |
|--------|------|
| `scripts/orchestrate_reprice.py` | Primary entry — parse MCP JSON, filter, preview, write plan + mutations |
| `scripts/reprice_swaps.py` | Core ASC 845 repricing engine (imported by orchestrator; usable standalone) |
