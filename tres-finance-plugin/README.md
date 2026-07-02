# TRES Finance plugin

The official [TRES Finance](https://tres.finance) plugin for [Claude Code](https://claude.ai/claude-code) — blockchain accounting workflows, ledger management, and transaction analysis.

## Structure

```
tres-finance-plugin/
├── .claude-plugin/
│   ├── plugin.json        # Plugin metadata & userConfig
│   └── marketplace.json   # Marketplace listing
├── skills/
│   ├── tres-asc845-swap-reprice-skill/ # ASC 845 swap repricing (clearing account zero-out)
│   ├── tres-explorer-tx-to-ledger/    # Explorer TX -> ledger entry
│   ├── tres-tx-story/                 # TX flow diagram & explanation
│   ├── tres-recon-gaps/               # Reconciliation gap resolution
│   ├── tres-asset-balance-validation/ # Balance validation vs DeBank (+ DeFi positions)
│   ├── tres-report-analyzer/       # Analyze TRES report XLSX exports
│   ├── tres-report-advisor/        # Recommend the right TRES report
│   ├── tres-invoice-bill-matching/    # Match txs to ERP invoices/bills + sync
│   ├── tres-erp-rule-suggestions/     # ERP rule mapping for accounting entries
│   ├── tres-export-3rd-party-contacts/ # Export unidentified counterparties to XLSX
│   ├── tres-import-contacts/          # Import contacts from CSV/XLSX
│   ├── tres-rollup-rules/             # Discover & propose sub-transaction rollup rules
│   ├── tres-rollup-review/            # Exact-impact gate / review for rollup rules
│   ├── tres-onboarding/               # Full entity onboarding (orchestrates sub-skills)
│   ├── tres-wallets-upload/           # Upload & onboard on-chain wallets / exchange accounts
│   ├── tres-data-collection-commit/   # Trigger on-chain data collection (Commit)
│   ├── tres-cost-basis/               # Cost basis strategy, calculation, issues, exports
│   ├── tres-settings-management/      # Manage org & platform settings via MCP
│   ├── tres-upload-tx-header-validation/ # Bulk TX CSV header validation
│   └── tres-request-skill-update/     # Submit plugin feedback via MCP
├── .mcp.json              # TRES Finance MCP connector
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Skills

### `tres-asc845-swap-reprice-skill`
Reprice swap inflow legs under ASC 845 (Nonmonetary Transactions) so a swaps/trade clearing account nets to zero. Queries subtransactions via MCP, runs bundled Python scripts for preview and mutation planning, then applies `setManualFiatValue` after user confirmation.

### `tres-explorer-tx-to-ledger`
Add a blockchain explorer transaction to the TRES Finance ledger. Provide an explorer URL or transaction hash, and this skill parses the on-chain data into a structured ledger entry.

### `tres-tx-story`
Analyze a blockchain transaction by hash — generates an animated SVG flow diagram showing all asset movements, plus a plain-language explanation of what happened.

### `tres-recon-gaps`
Query, display, and resolve reconciliation gaps between the TRES ledger and on-chain balances. Renders an interactive HTML dashboard with plug-once and auto-fill actions.

### `tres-asset-balance-validation`
Validate wallet balances in TRES Finance against DeBank (token balances and DeFi protocol positions). Generates an interactive HTML report and a PDF with match/minor/major/missing/untracked/position status badges.

### `tres-report-analyzer`
Analyze uploaded TRES Finance report exports (XLSX): identifies the report type from sheet structure, runs targeted checks via `scripts/analyze_report.py`, and summarizes anomalies and action items.

### `tres-report-advisor`
Recommend the right TRES Finance report for a goal (month-end, audit, tax, reconciliation). Points users to the right tabs, columns, and export API types.

### `tres-invoice-bill-matching`
Match a TRES ledger transaction to an open ERP invoice or bill (AP/AR), pick the payment account from the COA, optionally align fiat values, and sync the transaction to the connected ERP (Xero, QuickBooks Online, NetSuite).

### `tres-erp-rule-suggestions`
Guide users through creating ERP accounting rules for crypto organizations. Fetches wallets, chart of accounts, existing rules, and transaction profiles via the TRES MCP, then proposes a layered rule set (inventory, behavioral, fee/gain-loss) aligned to the org's cost basis mode — and applies it via `upsertRule` after approval.

### `tres-export-3rd-party-contacts`
Pull unidentified external addresses from `accountTxsSummary`, deduplicate and sort by activity, and build a two-tab XLSX (import-ready Contacts + Address details) for labeling and re-import into TRES.

### `tres-import-contacts`
Import labeled contacts into TRES from a CSV or XLSX file (headers: Contact Name, Contact Address, Contact Tag). Parses the file, validates rows, previews imports, and applies `setCustomAccountName` / `setCustomAccountNameLabelTags` in batches with progress and failure reporting.

### `tres-rollup-rules`
Data-driven discovery of rollup rules: aggregates sub-transactions by (wallet, asset, platform, direction), drills into discriminating filters, validates each candidate against real transactions through the `tres-rollup-review` gate, then presents an HTML report + numbered proposal table and creates the approved rules (open-ended by default). Also lists and deletes rollup rules via the TRES MCP GraphQL API.

### `tres-rollup-review`
Computes the exact sub-transaction impact of a rollup rule (every filter applied, via `subTransactionRollupRulePreview`) and flags zero-match, overlap, and config problems. Runs as a pre-create quality gate invoked by `tres-rollup-rules`, and standalone to review submitted or existing PENDING rollup rules.

### `tres-onboarding`
Run the full new-entity pipeline in order: wallets upload, data collection commit, balance validation, reconciliation gaps, cost basis (`tres-cost-basis`), export/import contacts for counterparties, and rollup rules — only when the user explicitly asks for full onboarding.

### `tres-wallets-upload`
Upload and onboard multiple on-chain wallets or exchange accounts into TRES — from a CSV/Excel file or typed manually. Guides through wallet type selection, input collection, validation, an editable HTML preview, exchange credential collection, and batched creation via the TRES MCP API.

### `tres-data-collection-commit`
Trigger on-chain data collection (a "Commit") in TRES for wallets that are already onboarded. Sits between `tres-wallets-upload` and `tres-asset-balance-validation` in the onboarding flow — pulls balances, syncs wallets, and refreshes on-chain data.

### `tres-cost-basis`
Manage cost basis end-to-end via the TRES MCP: strategy (FIFO, LIFO, AVG, etc.), trigger recalculation, per-asset results, financial issues, missing fiat fixes, reevaluations/impairments, spec-ID rules, and cost basis report exports.

### `tres-settings-management`
View and modify Organization Settings and Platform Settings via the TRES MCP GraphQL API — feature flags, balance diff, commit strategy, cost basis strategy, ERP, pricing, sync boundaries, enable/disable platforms, and other config.

### `tres-upload-tx-header-validation`
Validate or fix the header row for TRES bulk manual transaction / sub-transaction CSV uploads. Documents the exact display-name columns (e.g. `Organizational Wallet`, not `wallet_address`) and column order — use when uploads fail with missing required column errors.

### Legacy alias: `wallets-upload-v3` → `tres-wallets-upload`
Older docs may refer to `wallets-upload-v3`. The current skill ID is `tres-wallets-upload`.

### `tres-data-collection-commit`
Trigger on-chain data collection (a "Commit") in TRES for wallets that are already onboarded. Sits between `tres-wallets-upload` and `tres-asset-balance-validation` in the onboarding flow — pulls balances, syncs wallets, and refreshes on-chain data.

### `tres-settings-management`
View and modify Organization Settings and Platform Settings via the TRES MCP GraphQL API — feature flags, balance diff, commit strategy, cost basis strategy, ERP, pricing, sync boundaries, enable/disable platforms, and other config.

### `tres-request-skill-update`
Submit feedback about any part of the plugin — bug reports, feature requests, skill improvements, new skill ideas, MCP issues, or positive feedback. Guides you through articulating clear, actionable feedback and saves it via the TRES MCP.

## Submit Feedback

Have feedback about the plugin? Use the `tres-request-skill-update` skill directly in Claude Code — it guides you through describing your feedback clearly and submits it for the team to review.

## Analytics

This plugin collects **no usage telemetry**. It does not track which skills you invoke, which MCP tools you call, or your identity, and it sends no analytics events.

Usage analytics may be reintroduced in a future release as an explicit opt-in. If that happens, it will be disclosed here and in the plugin description before it ships.

## Privacy

Data you exchange with the bundled TRES Finance MCP connector (see below) is handled under the TRES Finance privacy policy: <https://tres.finance/privacy-policy/>

## MCP Connector

This plugin bundles the TRES Finance MCP server (`https://ai.tres.finance/mcp`), which provides GraphQL tools for querying and mutating TRES data: `build_query`, `execute`, `get_schema_summary`, `get_viewer`, `validate_query`, and `introspect`.

On first enable, a browser window opens for you to log in to your TRES Finance account. Authentication is handled automatically via OAuth — no API token required.

## Installation

Install via the Claude Code plugin system:

```bash
/plugin marketplace add tres-finance/tres-finance-plugin
```

Or for local development:

```bash
claude --plugin-dir ./tres-finance-plugin
```

## License

MIT
