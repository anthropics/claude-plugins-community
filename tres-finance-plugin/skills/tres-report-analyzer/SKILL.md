---
name: tres-report-analyzer
description: Analyze any TRES Finance report XLSX and produce an automatic findings summary. Trigger this skill whenever a user uploads a .xlsx file that came from TRES Finance and asks to "analyze", "summarize", "review", "check", "audit", "look at", "what does this show", "any issues", "anything interesting", or "walk me through" the report. Also trigger when the user uploads an Excel file and mentions TRES, reconciliation, balances, transactions, cost basis, roll forward, or ERP sync. The skill identifies the report type from the file structure, runs targeted analysis based on report-specific logic, and produces a clear findings summary highlighting anomalies, key metrics, and action items.
---

# TRES Report Analyzer

You analyze TRES Finance report exports (XLSX files) and produce clear, actionable findings summaries. The goal is to save users hours of manual spreadsheet review by automatically surfacing the most important information: anomalies, failed checks, large movements, and key metrics.

## How it works

1. **Identify the report type** from the uploaded file's tab names and column headers
2. **Run the analysis script** which performs report-specific checks
3. **Present findings** in a structured summary with the most important items first

## Step 1: Identify the report type

When the user uploads an XLSX file, first identify which TRES report it is. Use the tab names as the primary signal:

| Tab signature | Report type |
|---|---|
| `Summary`, `Inventory Reconciliation`, `Running Token Reconciliation`, `Running Fiat Reconciliation`, `Historical Token Reconciliation`, `Historical Fiat Reconciliation`, `Roll Forward Reconciliation` | Ledger Reconciliation |
| `Summary Per Asset`, `Summary Per Year`, `Summary per Tx Activity`, `raw_data` (with Realized Gain column) | Realized Gains & Losses |
| `By Asset`, `By Wallet`, `By Platform`, `By Position`, `Cost Basis`, `raw_data` (with Previous Amount column) | Balance Trends |
| `By Asset`, `By Wallet`, `By Platform`, `By Position`, `Cost Basis`, `raw_data` (without Previous Amount) | Asset Balances |
| `By Asset`, `By Wallet`, `By Platform`, `By Position`, `Cost Basis`, `raw_data` (with Historical Balance columns, Time Capsule enabled) | Historical Balance Format |
| `Asset Balances - PT`, `Cost Basis`, `raw_data` | Asset Balances V2 |
| `Fiat Value Summary`, `Amount Summary By Application`, `Amount Summary`, `raw_data` | Asset Balances - Archives |
| `Overview`, `raw_data` (with Safety Check column) | Asset Roll Forward |
| `Summary`, `Inventory Reconciliation`, `raw_data` (with Cost Basis columns, ~29 cols) | Cost Basis Roll Forward |
| `Chart of Accounts Summary`, `raw_data` (with Configuration Status) | ERP Pre-Sync |
| Single `raw_data` tab with COGS Lot columns | Cost Breakdown |
| Single `raw_data` tab with Rollup Parent TX Hash | Rollup Breakdown |
| Single `raw_data` tab with ~8 columns including Sync Status | ERP Post-Sync |
| Single `raw_data` tab with Price Source column | Asset Fiat Values |
| Single `raw_data` tab with Purchase Date, Remaining Quantity | Cost Basis Stack |
| Single `raw_data` tab with Sub TX Index, Is Taxable | Cost Basis Inventory |
| Single `raw_data` tab with wallet registry columns | Organization Wallets |
| Single `raw_data` tab with basic tx columns | Transaction Ledger |

If you cannot identify the report type, tell the user and ask them to confirm which report it is.

## Step 2: Run the analysis

Use the Python script at `scripts/analyze_report.py` to extract data from the XLSX file. Run it like this:

```bash
python /path/to/skill/scripts/analyze_report.py "/path/to/uploaded/file.xlsx" --output /path/to/output.json
```

The script outputs a JSON file with extracted metrics. If the script fails or the report type is not yet supported by the script, fall back to reading the file with openpyxl directly and performing the analysis inline.

### What to analyze per report type

Read `references/analysis-playbook.md` for the detailed analysis checklist for each report type. The general pattern is:

**For reconciliation reports** (Ledger Reconciliation, Asset Roll Forward, Cost Basis Roll Forward):
- Check columns: how many pass vs. fail?
- Which assets/wallets have the largest discrepancies?
- What is the total slippage or gap amount?
- Are there patterns (same wallet, same asset, same platform)?

**For balance reports** (Asset Balances, Historical Balance Format, V2, Archives, Balance Trends):
- Total portfolio value
- Top holdings by fiat value
- Any zero-balance or negative-balance entries?
- For Balance Trends: largest movers (biggest absolute change)
- Unverified tokens or missing prices

**For transaction reports** (Transaction Ledger, Realized Gains & Losses, Cost Breakdown):
- Total transaction count and date range
- Largest transactions by fiat value
- Total realized gains/losses (if applicable)
- Classification breakdown (how many of each type)
- Any unclassified transactions?

**For cost basis reports** (Cost Basis Stack, Cost Basis Inventory, Cost Basis Roll Forward):
- Total cost basis and unrealized gains
- Lots with largest unrealized losses (tax-loss harvesting candidates)
- Age of lots (any very old lots?)
- Impairment amounts if applicable

**For ERP reports** (Pre-Sync, Post-Sync):
- Configuration status breakdown (how many ready vs. misconfigured)
- Missing account mappings
- Failed syncs and error patterns
- Debit/credit balance check

## Step 3: Present findings

Structure your response as follows. Keep it concise -- the user wants insights, not a data dump.

### Format

Start with a one-line identification of what the report is and the period it covers.

Then present findings in order of importance:

1. **Red flags** (if any): failed checks, large discrepancies, missing data, failed syncs
2. **Key metrics**: total value, count, gains/losses -- the headline numbers
3. **Notable items**: largest transactions, top holdings, biggest movers -- things worth knowing
4. **Action items** (if any): specific things the user should investigate or fix

End with a brief note about what the user can ask as a follow-up (e.g. "I can drill into any specific asset or wallet if you want a closer look").

### Style rules

- Use actual numbers from the data, not vague descriptions
- Round large numbers sensibly ($1,234,567.89 -> $1.23M)
- No em-dashes or en-dashes (use -- instead)
- Keep the total response under 500 words unless the user asks for more detail
- If there are many findings, prioritize the top 5 and mention "N more items" the user can ask about
