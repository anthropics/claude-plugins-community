# Report Analysis Playbook

Detailed analysis checklist for each TRES Finance report type. When analyzing a report, follow the checklist for the identified report type.

---

## Ledger Reconciliation (RECONCILIATION_LEDGER)

This is the most complex report with 7 tabs and 57 columns. The analysis strategy is top-down: start from the Summary tab and drill down only where checks fail.

### Summary tab
- Read all 12 attribute rows. The key row is **Check** -- if Running and Historical checks are both zero, the org is fully reconciled.
- Report: total Running Fiat closing balance, total Historical Fiat closing balance, and whether the check passes.

### Inventory Reconciliation tab
- Count assets where Check (T) or Check ($) is non-zero. These are the assets with inventory discrepancies.
- Report: number of assets that pass vs. fail, and the top 3 failing assets by absolute check amount.

### Running Token Reconciliation tab
- Check (T) column: count non-zero entries. This means Opening + Inflows - Outflows - Fees != Closing for that asset.
- Report: number of passing vs. failing assets.

### Running Fiat Reconciliation tab
- Same as above but in fiat. Non-zero Check ($) means the fiat flow does not balance.
- Report: number of passing vs. failing, and total fiat gap.

### Historical Token Reconciliation tab
- Check Open (T) and Check Close (T): non-zero means on-chain balance differs from book balance.
- Report: how many assets have open drift vs. close drift, and the largest drift amounts.

### Historical Fiat Reconciliation tab
- Same in fiat terms.

### Roll Forward Reconciliation tab
- "Historical Close - Expected Close" column: non-zero means the roll-forward does not balance for that wallet+asset.
- Report: number of balance IDs that pass vs. fail, top 5 largest discrepancies, and whether they cluster on specific wallets or platforms.

### raw_data tab (if present)
- Slippage (T) and Slippage ($): filter for non-zero. Report count and total.
- Has Price?: count False entries. Missing pricing causes fiat check gaps.
- Look for patterns: same wallet, same platform, same asset recurring in failures.

---

## Asset Roll Forward (ASSET_ROLL_FORWARD)

### Overview tab
- Summarize total inflows, outflows, fees across the period.

### raw_data tab
- **Safety Check column**: count True vs. False. False means Opening + Inflows - Outflows - Fees != Closing.
- Report: total rows, pass rate, and list the failing rows (asset + wallet + gap amount).
- Top 5 assets by absolute inflow volume.
- Top 5 assets by absolute outflow volume.
- Any rows where Internal Transfers (T) is significant? Report the total internal transfer volume.

---

## Cost Basis Roll Forward (COST_BASIS_ROLL_FORWARD)

### Summary tab
- Opening vs. closing total cost basis.
- Total realized gains during the period.
- Check: does the roll-forward balance?

### Inventory Reconciliation tab
- Same structure as Ledger Reconciliation's Inventory tab. Count pass/fail by asset.

### raw_data tab
- Top 5 assets by realized gains (positive).
- Top 5 assets by realized losses (negative).
- Any rows where check columns are non-zero.
- Total unrealized gains change across the period.

---

## Realized Gains & Losses (EXTENDED_RAW_TRANSACTIONS)

### Summary Per Year tab
- Total realized gains/losses per year. Highlight the year being analyzed.

### Summary Per Asset tab
- Top 5 assets by realized gains and top 5 by realized losses.
- Total transaction count per asset.

### Summary per Tx Activity tab
- Breakdown by classification (trade, transfer, fee, etc.).

### raw_data tab
- Total transaction count and date range covered.
- Largest single transaction by fiat value.
- Total realized gains vs. losses.
- Count of transactions missing cost basis data.
- Count of unclassified transactions.

---

## Asset Balances (RAW_BALANCES) / Historical Balance Format (HISTORICAL_BALANCE) / Asset Balances V2 (RAW_BALANCES_V2)

### Pivot tabs (By Asset, By Wallet, By Platform, etc.)
- Total portfolio fiat value.
- Top 10 holdings by fiat value.
- Number of unique assets, wallets, platforms.

### raw_data tab
- Any negative balances? Report them.
- Any zero-balance entries with non-zero cost basis? These are fully disposed assets still showing in the ledger.
- Count unverified tokens (Is Verified = False).
- Count entries with missing prices (fiat value = 0 but token amount > 0).
- Reconciliation Status breakdown: how many Reconciled vs. Not Reconciled.
- Total unrealized gains/losses.

---

## Asset Balances - Archives (ARCHIVED_BALANCES)

### Summary tabs
- Total fiat value at the snapshot date.
- Top holdings.

### raw_data tab
- Date range of snapshots present.
- Compare earliest vs. latest snapshot: which assets grew most? Which declined?
- Any assets that appeared or disappeared between snapshots.
- Historical vs. Running balance comparison: count discrepancies.

---

## Balance Trends (BALANCE_TRENDS)

### raw_data tab
- Same as Asset Balances analysis, PLUS:
- Largest positive movers: top 5 by Amount Change (T) or Fiat Value Change ($).
- Largest negative movers: top 5 by decline.
- Any assets that went from positive to zero (fully withdrawn/sold).
- Any new assets that appeared (previous = 0, current > 0).
- Price impact: compare Previous Fiat Value to current, isolating price change from quantity change.

---

## Cost Basis Stack Per Wallet (COST_BASIS_STACK_PER_ACCOUNT)

### raw_data tab
- Total lots count.
- Total cost basis and total unrealized gains.
- Top 5 lots by unrealized loss (tax-loss harvesting candidates).
- Top 5 lots by unrealized gain.
- Oldest lots (by Purchase Date).
- Any lots with impairment? Total impairment amount.
- Breakdown by Cost Basis Method (FIFO, LIFO, etc.).

---

## Cost Basis Inventory (COST_BASIS_INVENTORY)

### raw_data tab
- Total inventory entries.
- Breakdown by Is Taxable (taxable vs. non-taxable acquisitions).
- Breakdown by Is Internal Transfer.
- Any duplicate-looking entries (same TX Hash, same asset, very close timestamps)?
- Total quantity and cost across all inventory.

---

## Transaction Ledger (BASIC_RAW_TRANSACTIONS)

### raw_data tab
- Total transaction count and date range.
- Classification breakdown (trade, transfer, fee, deposit, withdrawal, etc.).
- Top 5 transactions by fiat value.
- Count of internal vs. external transactions.
- Transaction volume by day/week (spot unusual spikes).
- Any unclassified transactions? Count and list.

---

## Cost Breakdown (COST_BREAKDOWN_RAW_TRANSACTIONS)

### raw_data tab
- Everything from Transaction Ledger analysis, PLUS:
- Count of disposal transactions with lot detail.
- Verify lot ordering matches declared method (FIFO = oldest lots consumed first).
- Any disposals with missing lot data?
- Cross-wallet lot consumption: how many disposals used lots acquired in a different wallet?

---

## Rollup Breakdown (ROLLUP_BREAKDOWN)

### raw_data tab
- Count of original transactions vs. rollup parents.
- Verify that individual tx amounts sum to the rollup total.
- Date range of the underlying transactions.
- Largest rollup group (most individual txs behind one rollup).

---

## ERP Pre-Sync (PRE_SYNC_JOURNAL)

### Chart of Accounts Summary tab
- List all accounts and their debit/credit totals.
- Verify debits = credits (balanced books).

### raw_data tab
- Configuration Status breakdown: count Ready vs. Missing Account vs. Missing Fiat Value vs. other statuses.
- List all transactions with "Missing Account" status.
- Count transactions without fiat values.
- Any duplicate journal entries (same TX Hash appearing multiple times with same account)?

---

## ERP Post-Sync (POST_SYNC_JOURNAL)

### raw_data tab
- Sync Status breakdown: count Synced vs. Failed vs. Pending.
- List all failed syncs with their error messages.
- Date range of synced entries.
- Verify total debits = total credits across all synced entries.

---

## Asset Fiat Values (DAILY_ASSET_PRICING)

### raw_data tab
- Date covered by the export.
- Number of unique assets with pricing.
- Any assets with Price Source = "manual"? List them (manually overridden prices).
- Largest price swings within the 24-hour period (max vs. min for same asset).
- Any missing hours (gaps in hourly data)?
- Cross-platform price comparison: same asset on different platforms should have similar prices.

---

## Organization Wallets (INTERNAL_ACCOUNTS)

### raw_data tab
- Total wallet count and breakdown by type.
- Total fiat value across all wallets.
- Active vs. inactive wallets.
- Platform distribution (how many wallets per chain).
- Any wallets with zero balance? Any wallets missing a name?
- Recently added wallets (by Added Date).
