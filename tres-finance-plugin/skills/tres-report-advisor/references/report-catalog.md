# TRES Finance Report Catalog

Complete reference for all 18 TRES Finance reports. Each entry includes the API type, Excel tabs, key columns, primary use cases, and cross-references to related reports.

---

## 1. Transaction Ledger
- **API Type**: `BASIC_RAW_TRANSACTIONS`
- **Category**: Transaction Reports
- **Tabs**: raw_data
- **Key Columns**: Timestamp, Sender Address, Receiver Address, Token Amount, Fiat Value, Classification, Chain, TX Hash, Wallet Name, Sub Type, Is Internal
- **Use Cases**: Daily transaction monitoring, sharing tx data with external parties, feeding downstream systems, filtered ledger exports
- **Related**: Realized Gains & Losses (adds cost basis), Cost Breakdown (adds lot detail), Rollup Breakdown (expands aggregated txs)
- **Notes**: Lightest and fastest transaction export. Respects UI filters applied before export.

## 2. Realized Gains & Losses
- **API Type**: `EXTENDED_RAW_TRANSACTIONS`
- **Category**: Transaction Reports
- **Tabs (4)**: Summary Per Asset, Summary Per Year, Summary per Tx Activity, raw_data
- **Key Columns**: Everything in Transaction Ledger + Cost Basis ($), Realized Gain ($), COGS ($), Running Balance (T), Running Balance ($), Inventory Method, ERP Account columns
- **Use Cases**: Tax filing (filter by Year tab), capital gains reconciliation (sum per asset per year), cost basis audit (verify COGS per method), ERP pre-check (review account columns), lot-level analysis
- **Related**: Transaction Ledger (baseline), Cost Breakdown (per-lot COGS), Rollup Breakdown
- **Notes**: The go-to report for tax and capital gains. Summary Per Year tab gives annual totals at a glance.

## 3. Cost Breakdown Raw Transactions
- **API Type**: `COST_BREAKDOWN_RAW_TRANSACTIONS`
- **Category**: Transaction Reports
- **Tabs (1)**: raw_data
- **Key Columns**: Everything in Realized Gains & Losses + COGS Lot Date, COGS Lot Price, COGS Lot Quantity, COGS Lot Wallet, COGS Lot TX Hash
- **Use Cases**: FIFO/LIFO verification (check lot purchase order), tax-lot tracing (see which acquisitions consumed), cross-wallet lot tracking, auditor requests for full acquisition-to-disposal chain
- **Related**: Realized Gains & Losses (same data minus lot detail), Cost Basis Stack Per Wallet (lot inventory)
- **Notes**: Deepest transaction export. Essential when auditors ask "which specific lot was sold".

## 4. Rollup Breakdown
- **API Type**: `ROLLUP_BREAKDOWN`
- **Category**: Transaction Reports
- **Tabs (1)**: raw_data (46 columns, same structure as Transaction Ledger)
- **Key Columns**: Same as Transaction Ledger, plus Rollup Parent TX Hash
- **Use Cases**: Rollup verification (compare individual tx sum against rollup entry), granular staking analysis (individual reward events), audit detail (individual tx hashes)
- **Related**: Transaction Ledger
- **Notes**: Only relevant for orgs using rollup/aggregation rules. Empty if no rollups configured.

## 5. Asset Balances
- **API Type**: `RAW_BALANCES`
- **Category**: Balance Reports
- **Tabs (6)**: By Asset, By Wallet, By Platform, By Position, Cost Basis, raw_data
- **Key Columns**: Asset Name/Symbol, Wallet Name/Address, Platform, Amount (T), Fiat Value ($), Unit Price ($), Cost Basis ($), Unrealized Gain ($), Balance State, Reconciliation Status, Is Verified
- **Use Cases**: Portfolio overview, wallet audit, cost basis review, staking position check (filter Balance State), unverified token cleanup, historical balance lookup (with Time Capsule)
- **Related**: Asset Balances V2 (cleaner layout), Archives (commit-based historical), Balance Trends (change detection)
- **Notes**: Source of truth for current balances. Matches the Assets UI. Five pivot tabs for different slicing angles. **Supports Time Capsule** -- when enabled, generates a Historical Balance Format report (`HISTORICAL_BALANCE`) that reconstructs balances at a past date without needing a prior commit.

## 6. Asset Balances V2
- **API Type**: `RAW_BALANCES_V2`
- **Category**: Balance Reports
- **Tabs (3)**: Asset Balances - PT, Cost Basis, raw_data
- **Key Columns**: Same underlying data as Asset Balances
- **Use Cases**: Board/executive reporting (clean summary), cost basis summary by asset class, sharing with external parties (cleaner layout)
- **Related**: Asset Balances (more pivot tabs), Archives (commit-based historical)
- **Notes**: Does NOT support Time Capsule. Use Asset Balances (with Time Capsule) or Archives for historical lookups.

## 6a. Historical Balance Format
- **API Type**: `HISTORICAL_BALANCE`
- **Category**: Balance Reports
- **Not a standalone UI report** -- generated when Asset Balances is exported with Time Capsule enabled
- **Key Columns**: Same as Asset Balances but showing reconstructed balances at the selected past date
- **Use Cases**: Month-end close without a prior commit, auditor balance confirmation, ad-hoc historical lookups
- **Related**: Asset Balances (current), Archives (commit-based historical)
- **Notes**: Reconstructs balances at any past date. Does not depend on a commit existing at that date, unlike Archives. This is the default recommendation for most "historical balance" questions.

## 7. Asset Balances - Archives
- **API Type**: `ARCHIVED_BALANCES`
- **Category**: Balance Reports
- **Tabs (4)**: Fiat Value Summary, Amount Summary By Application, Amount Summary, raw_data (36 columns)
- **Key Columns**: Commit Time, Asset Name/Symbol, Wallet Name/Address, Platform, Historical Balance (T), Historical Balance ($), Running Balance (T), Running Balance ($), Balance State, Unit Price
- **Use Cases**: Historical balance verification from actual commit data, balance trend analysis across all commit dates, audit evidence when commit-based snapshots are required
- **Related**: Asset Balances (current), Historical Balance Format (reconstructed historical), Balance Trends (current vs. previous)
- **Notes**: Uses actual commit snapshots for historical data. Unlike Asset Balances + Time Capsule (which reconstructs balances), Archives requires a commit to have been completed at or near the target date. Best when you need the exact data that was collected, not a reconstruction.

## 8. Balance Trends
- **API Type**: `BALANCE_TRENDS`
- **Category**: Balance Reports
- **Tabs (6)**: By Asset, By Wallet, By Platform, By Position, Cost Basis, raw_data (40 columns)
- **Key Columns**: Everything in Asset Balances + Previous Amount (T), Previous Fiat Value ($), Amount Change (T), Fiat Value Change ($)
- **Use Cases**: Anomaly detection (spot unexpected changes), daily monitoring, price impact analysis (isolate price vs. quantity movement), board reporting with built-in comparison
- **Related**: Asset Balances (current only), Archives (historical)
- **Notes**: Compares current snapshot to the previous data collection cycle. Same pivot tabs as Asset Balances plus four trend columns.

## 9. Cost Basis Inventory
- **API Type**: `COST_BASIS_INVENTORY`
- **Category**: Cost Basis Reports
- **Tabs (1)**: raw_data (11 columns)
- **Key Columns**: Asset Name, Wallet, TX Hash, Sub TX Index, Acquisition Date, Quantity, Unit Cost, Total Cost, Is Taxable, Is Internal Transfer
- **Use Cases**: Inventory verification (all acquisitions tracked), internal transfer audit (verify paired correctly), non-taxable inflow tracking
- **Related**: Cost Basis Stack Per Wallet (lot-level view), Cost Basis Roll Forward (period movement)
- **Notes**: Sub-transaction level view of how each acquisition builds the cost basis stack.

## 10. Cost Basis Stack Per Wallet
- **API Type**: `COST_BASIS_STACK_PER_ACCOUNT`
- **Category**: Cost Basis Reports
- **Tabs (1)**: raw_data (22 columns)
- **Key Columns**: Asset Name/Symbol, Wallet Name, Purchase Date, Purchase Price ($), Remaining Quantity (T), Original Quantity (T), Unrealized Gain ($), Impairment ($), Fair Value ($), Cost Basis Method
- **Use Cases**: Tax-loss harvesting (find lots with negative unrealized gains), FIFO/LIFO verification, impairment testing (ASC 350), fair value reporting (ASU 2023-08), IFRS (IAS 38), lot-level audit
- **Related**: Cost Basis Inventory (acquisition detail), Cost Basis Roll Forward (period movement), Revaluation (mark-to-market)
- **Notes**: Shows individual tax lots, not current wallet balance. Qty may differ from Assets UI -- that is expected.

## 11. Cost Basis Roll Forward
- **API Type**: `COST_BASIS_ROLL_FORWARD`
- **Category**: Cost Basis Reports
- **Tabs (3)**: Summary, Inventory Reconciliation, raw_data (29 columns)
- **Key Columns**: Asset Name, Wallet Name, Open/Close Cost Basis ($), Open/Close Inventory (T), Acquisitions (T/$), Disposals (T/$), Fees (T/$), Realized Gains ($), Unrealized Gains ($), Check columns
- **Use Cases**: Period-end cost basis close, realized gains reconciliation to P&L, auditor deliverable (summary + breakdown), unrealized gains tracking
- **Related**: Asset Roll Forward (quantity-only version), Cost Basis Stack (lot detail), Realized Gains & Losses (transaction-level)
- **Notes**: Bridges opening to closing cost basis. The auditor-ready cost basis reconciliation report.

## 12. Asset Roll Forward
- **API Type**: `ASSET_ROLL_FORWARD`
- **Category**: Reconciliation Reports
- **Tabs (2)**: Overview, raw_data (19 columns)
- **Key Columns**: Asset Name/Symbol, Wallet Name/Address, Platform, Open Balance (T), Inflows (T), Outflows (T), Fees (T), Close Balance (T), Safety Check (boolean), Internal Transfers (T)
- **Use Cases**: Auditor deliverable (asset movement), month-end reconciliation, discrepancy investigation (filter Safety Check = False), treasury reporting
- **Related**: Cost Basis Roll Forward (adds cost basis), Ledger Reconciliation (full on-chain comparison)
- **Notes**: Summary-level only. Does NOT contain individual transaction dates. If the user needs tx detail, also export Transaction Ledger.

## 13. Revaluation
- **API Type**: `REEVALUATION`
- **Category**: Reconciliation Reports
- **Tabs (1)**: raw_data
- **Key Columns**: Asset Name/Symbol, Wallet Name, Cost Basis ($), Fair Market Value ($), Unrealized Gain/Loss ($), Impairment ($), Impairment Recovery ($), Accounting Standard
- **Use Cases**: Period-end mark-to-market, impairment testing (ASC 350), fair value reporting (ASU 2023-08), IFRS revaluation model (IAS 38)
- **Related**: Cost Basis Stack Per Wallet (lot-level detail), Asset Balances (current fair values)
- **Notes**: Supports US GAAP and IFRS standards. Generate at period-end for mark-to-market journal entries.

## 14. Ledger Reconciliation
- **API Type**: `RECONCILIATION_LEDGER`
- **Category**: Reconciliation Reports
- **Tabs (7)**: Summary, Inventory Reconciliation, Running Token Reconciliation, Running Fiat Reconciliation, Historical Token Reconciliation, Historical Fiat Reconciliation, Roll Forward Reconciliation
- **Key Columns (57 in raw_data)**: Balance ID, Wallet Name/Address, Asset Name/Symbol, Platform, Open/Close Running Balance (T/$), Open/Close Historical Balance (T/$), Open/Close Reversed Balance (T/$), Inflow/Outflow/Fees (T/$), Realized Gains ($), Unrealized Gains ($), Slippage (T/$), Check columns, Has Price?, Unit Prices
- **Use Cases**: Month-end close sign-off (Summary tab pass/fail), on-chain vs. book discrepancy (Historical tabs), roll-forward validation, auditor deliverable (full package), slippage investigation
- **Related**: Asset Roll Forward (simpler quantity check), Cost Basis Roll Forward (cost basis version), Asset Balances Archives (point-in-time snapshots)
- **Notes**: Most comprehensive reconciliation. 5 check layers. Start from Summary tab and drill down only if checks fail. If user only needs simple roll-forward, Asset Roll Forward is lighter.

## 15. ERP Pre-Sync
- **API Type**: `PRE_SYNC_JOURNAL`
- **Category**: ERP Reports
- **Tabs (2)**: Chart of Accounts Summary, raw_data (58 columns)
- **Key Columns**: TX Hash, Date, Classification, Debit Account, Credit Account, Debit Amount, Credit Amount, Configuration Status, Missing Account Flag, Fiat Value, ERP Document Type
- **Use Cases**: Pre-sync review (find misconfigured txs), missing account mapping (locate txs without COA rules), debit/credit verification, rule testing before sync
- **Related**: ERP Post-Sync (what was actually sent), Realized Gains & Losses (transaction detail)
- **Notes**: Always review this before syncing to catch missing accounts and wrong mappings.

## 16. ERP Post-Sync
- **API Type**: `POST_SYNC_JOURNAL`
- **Category**: ERP Reports
- **Tabs (1)**: raw_data (8 columns)
- **Key Columns**: TX Hash, Date, Debit/Credit Account, Amount, Sync Status, ERP Document Number, Error Message
- **Use Cases**: Sync reconciliation (compare against ERP), failed sync investigation (filter status = "failed"), ERP audit trail
- **Related**: ERP Pre-Sync (preview before sync)
- **Notes**: Use this to verify what TRES actually sent to the ERP.

## 17. Asset Fiat Values
- **API Type**: `DAILY_ASSET_PRICING`
- **Category**: Reference Reports
- **Tabs (1)**: raw_data (9 columns)
- **Key Columns**: Asset Class, Asset Name, Asset Symbol, Asset Address, Platform, Price, Currency, Price Source, Datetime
- **Use Cases**: Pricing verification (compare against external sources), fiat value discrepancy investigation, audit evidence (exact pricing used), cross-platform price comparison
- **Related**: Asset Balances (current pricing per holding), Revaluation (fair value pricing)
- **Notes**: Covers a single 24-hour period with hourly granularity. For multi-day pricing, generate multiple exports. If Price Source = "manual", price was user-overridden.

## 18. Organization Wallets
- **API Type**: `INTERNAL_ACCOUNTS`
- **Category**: Reference Reports
- **Tabs (1)**: raw_data (11 columns)
- **Key Columns**: Wallet Name, Wallet Address, Platform(s), Status, Type, Total Fiat Value ($), Added Date, Tags, Is Active
- **Use Cases**: Audit preparation (evidence of monitored addresses), wallet registry review, compliance documentation, onboarding verification
- **Related**: Asset Balances (balances per wallet)
- **Notes**: Single source of truth for the wallet inventory. Also shows when each wallet was added to TRES.
