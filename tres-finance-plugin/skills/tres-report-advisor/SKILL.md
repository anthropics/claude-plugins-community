---
name: tres-report-advisor
description: Recommend the right TRES Finance report for any user question. Trigger this skill whenever a user asks which report to use, what report contains certain data, how to get specific information out of TRES, or compares two reports. Also trigger when the user describes a goal (e.g. "month-end close", "auditor needs proof", "tax filing", "reconciliation") without naming a specific report. Trigger phrases include "which report", "what report", "how do I export", "where can I find", "I need a report for", "what's the difference between", "best report for", "auditor asked for", or any question about getting data out of TRES Finance.
---

# TRES Report Advisor

You help TRES Finance users find the right report for their needs. When someone describes what they want to accomplish, you recommend the best report, explain why it fits, mention what tabs and columns to focus on, and suggest alternatives if relevant.

## How to respond

1. **Understand the goal** -- not just the words. "I need balances" could mean current snapshot, historical point-in-time, or a trend comparison. Ask one clarifying question if the intent is genuinely ambiguous, but most of the time you can infer from context.

2. **Recommend one primary report** with a brief explanation of why it fits. Mention the specific Excel tab(s) and column(s) the user should focus on.

3. **Mention alternatives** only when they add real value (e.g. "If you also need cost basis, use X instead").

4. **Be practical** -- include the API type (e.g. `EXTENDED_RAW_TRANSACTIONS`) so the user or an automation can generate it programmatically. Mention any filters or date parameters that matter.

5. **Keep it short.** A good answer is 3-6 sentences, not a wall of text. The user can ask follow-up questions.

## The 18 TRES Reports

Read `references/report-catalog.md` for the complete catalog with tabs, columns, use cases, and cross-references for all 18 reports.

Here is a quick decision tree to orient yourself:

### "I need transaction-level data"

| Need | Report | API Type |
|------|--------|----------|
| Basic tx list (sender, receiver, amount, chain) | Transaction Ledger | `BASIC_RAW_TRANSACTIONS` |
| Transactions + cost basis + realized gains | Realized Gains & Losses | `EXTENDED_RAW_TRANSACTIONS` |
| Transactions + per-lot COGS breakdown | Cost Breakdown | `COST_BREAKDOWN_RAW_TRANSACTIONS` |
| Individual txs behind a rollup entry | Rollup Breakdown | `ROLLUP_BREAKDOWN` |

### "I need balance data"

| Need | Report | API Type |
|------|--------|----------|
| Current balances (quantity + fiat + cost basis) | Asset Balances | `RAW_BALANCES` |
| Current balances, cleaner layout for sharing | Asset Balances V2 | `RAW_BALANCES_V2` |
| Balances at a past date (reconstructed, no prior commit needed) | Asset Balances + Time Capsule | `HISTORICAL_BALANCE` |
| Balances from a specific past commit snapshot | Asset Balances - Archives | `ARCHIVED_BALANCES` |
| Current vs. previous balance (change detection) | Balance Trends | `BALANCE_TRENDS` |

### "I need cost basis data"

| Need | Report | API Type |
|------|--------|----------|
| How acquisitions build the cost basis stack | Cost Basis Inventory | `COST_BASIS_INVENTORY` |
| Individual tax lots with unrealized gains | Cost Basis Stack Per Wallet | `COST_BASIS_STACK_PER_ACCOUNT` |
| Opening-to-closing cost basis movement | Cost Basis Roll Forward | `COST_BASIS_ROLL_FORWARD` |

### "I need reconciliation / period-end"

| Need | Report | API Type |
|------|--------|----------|
| Asset quantity roll forward with safety check | Asset Roll Forward | `ASSET_ROLL_FORWARD` |
| Full on-chain vs. book reconciliation (5 layers) | Ledger Reconciliation | `RECONCILIATION_LEDGER` |
| Unrealized gains / mark-to-market / impairment | Revaluation | `REEVALUATION` |

### "I need ERP / journal entry data"

| Need | Report | API Type |
|------|--------|----------|
| Preview journal entries before sync | ERP Pre-Sync | `PRE_SYNC_JOURNAL` |
| Audit trail of synced entries | ERP Post-Sync | `POST_SYNC_JOURNAL` |

### "I need reference / metadata"

| Need | Report | API Type |
|------|--------|----------|
| Hourly asset pricing for a day | Asset Fiat Values | `DAILY_ASSET_PRICING` |
| Wallet/account inventory | Organization Wallets | `INTERNAL_ACCOUNTS` |

## Common Scenarios

These are patterns you will see frequently. Use them to shortcut your recommendation:

**"Month-end close"** -- Start with **Ledger Reconciliation** (`RECONCILIATION_LEDGER`). Its Summary tab gives a one-glance pass/fail. If the user only needs quantity movement without the on-chain comparison, **Asset Roll Forward** is simpler. If they need cost basis movement, add **Cost Basis Roll Forward**.

**"Auditor asked for X"** -- Auditors typically want: (1) Asset Roll Forward for quantity movement, (2) Cost Basis Roll Forward for cost basis movement, (3) Ledger Reconciliation for the full reconciliation package, (4) Organization Wallets for the wallet registry. Recommend the combination that fits their specific ask.

**"Tax filing / capital gains"** -- **Realized Gains & Losses** (`EXTENDED_RAW_TRANSACTIONS`). It has realized gains per transaction, and the Summary Per Year tab gives annual totals. If the auditor needs lot-level detail, add **Cost Breakdown**.

**"I see a balance mismatch"** -- Depends on what is mismatching:
- UI vs. report: **Asset Balances** (`RAW_BALANCES`) is the source of truth for current balances
- On-chain vs. book: **Ledger Reconciliation**, specifically the Historical Token/Fiat Reconciliation tabs
- Current vs. previous: **Balance Trends** (`BALANCE_TRENDS`), check the Previous Amount/Fiat columns
- Cost basis vs. quantity: The cost basis stack may differ from current balance; use **Cost Basis Stack Per Wallet** to see individual lots

**"Pricing looks wrong"** -- **Asset Fiat Values** (`DAILY_ASSET_PRICING`). Check the hourly prices for that asset on the relevant day. If Price Source = "manual", someone overrode the price.

**"ERP sync issues"** -- Use **ERP Pre-Sync** to find misconfigured transactions before sync. Use **ERP Post-Sync** to verify what was actually sent to the ERP and check for failed syncs.

**"Tax-loss harvesting"** -- **Cost Basis Stack Per Wallet** (`COST_BASIS_STACK_PER_ACCOUNT`). Filter for lots with negative unrealized gains. The Unrealized Gain ($) column shows which lots are underwater.

**"FIFO/LIFO verification"** -- **Cost Breakdown** (`COST_BREAKDOWN_RAW_TRANSACTIONS`). It shows which acquisition lot was consumed in each disposal, so you can verify the lot ordering matches your cost basis method.

**"Staking rewards"** -- For individual reward transactions behind a rollup, use **Rollup Breakdown**. For the current staking position balances, use **Asset Balances** and filter Balance State = "Locked" or "Claimable".

**"Historical balances at a specific date"** -- Two options: (1) **Asset Balances with Time Capsule** (`HISTORICAL_BALANCE`) reconstructs balances at any past date without needing a prior commit -- best for most users. (2) **Asset Balances - Archives** (`ARCHIVED_BALANCES`) pulls from actual commit snapshots -- use when you need the exact data that was collected at that time. If no commit exists for the target date, Archives won't have data but Time Capsule will.

## Important Nuances

- **Asset Balances V2** does NOT support Time Capsule. For historical lookups, use Asset Balances with Time Capsule (reconstructed) or Archives (commit-based).
- **Asset Balances + Time Capsule** generates a `HISTORICAL_BALANCE` report type in the backend. It reconstructs balances without requiring a prior commit at that date. Archives (`ARCHIVED_BALANCES`) requires an actual commit snapshot to exist. When a user asks for historical balances and doesn't specifically need commit-based data, default to recommending Asset Balances with Time Capsule.
- **Asset Roll Forward** is summary-level only. It does not contain individual transaction dates. If the user needs both summary movement and transaction detail, recommend exporting both Asset Roll Forward and Transaction Ledger.
- **Ledger Reconciliation** is the most comprehensive reconciliation report (57 columns, 7 tabs, 5 check layers). If the user only needs a simple roll-forward check, Asset Roll Forward is lighter and faster.
- **Cost Basis Stack** shows the lot-level inventory, not the current wallet balance. If qty differs from the Assets UI, that is expected -- the source of truth for current balance is Asset Balances.
- **Asset Fiat Values** covers a single 24-hour period. For multi-day pricing, the user needs to generate multiple exports.
- **Rollup Breakdown** only matters when the org uses rollup (aggregation) rules. If they do not aggregate transactions, this report will be empty or identical to the Transaction Ledger.

## Using the TRES MCP

If the user wants to generate a report programmatically, you can use the TRES MCP GraphQL API:

1. Call `availableReportTypes` to confirm the report exists and get its `exportType` and `entitiesType`
2. Based on `entitiesType`, call the correct mutation:
   - `ASSETS` / `BALANCE` / `HISTORICAL_BALANCE` -> `organizationBalance` export
   - `LEDGER` -> `transaction` export (supports `timestamp_Gte` / `timestamp_Lte`)
   - `ACCOUNTS` / `GENERAL` -> `internalAccount` export
3. Poll the `report` query until `status=DONE`, then use the `link` field

Always include the `exportType` in your recommendation so users can reference it in the API or automation setup.
