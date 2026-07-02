---
name: tres-report-create
description: Create (generate) any TRES Finance report end-to-end via the tres-mcp MCP server and GraphQL — trigger the export, verify a report row was actually created (guarding against silent failures), poll until done, and return the download link. Trigger this skill on ANY report creation request, including phrases like "create a report", "generate a report", "export", "run a report", "I need a Transaction Ledger / Balances / Reconciliation / Cost Basis / Roll Forward / Staking / Audit report", "pull the data for", "download a report for", "give me a CSV/XLSX of", or whenever the user wants TRES to produce a report file. Use together with tres-report-advisor when the user is unsure which report they need.
---

# TRES Report Create

You create TRES Finance reports programmatically through the **tres-mcp** MCP server (GraphQL against the BFF). The flow is always: pick the report → trigger the export → poll until `DONE` → return the presigned `link`. Optionally download and analyze the file afterwards.

If you are unsure *which* report the user needs, use the `tres-report-advisor` skill first, then come back here to generate it.

## Workflow

```
- [ ] Step 0: Clarify report type + date range + currency
- [ ] Step 1: Trigger the export (GraphQL via MCP `execute`)
- [ ] Step 1b: If the report isn't in the tables below, derive it from the schema
- [ ] Step 1c: VERIFY a report row was actually created (poll by exact name) — catches silent failures
- [ ] Step 2: Poll the report query until status == DONE
- [ ] Step 3 (optional): Download + analyze the file
```

### Step 0 — Clarify scope (mandatory before triggering)

Confirm before doing anything:

- **Report type (required).** Match the user's wording to the tables below. If unsure, discover what's available:
  ```graphql
  query { availableReportTypes { name exportType entitiesType llmDescription } }
  ```
- **Date range (if applicable).** LEDGER / AUDIT_LOG reports take `timestamp_Gte` / `timestamp_Lte` in ISO 8601:
  - "Q1 2025" → Gte `2025-01-01T00:00:00Z`, Lte `2025-03-31T23:59:59Z`
  - "2025" → Gte `2025-01-01T00:00:00Z`, Lte `2025-12-31T23:59:59Z`
  - If a date range is required and not given, **ask**.
- **Currency.** Default `"usd"` unless the user says otherwise.
- **Analysis goal (only if they want the data analyzed, not just the file).** What should the data answer? Default to a general summary (totals, top items, trends). Drives Step 3.

Confirm briefly, e.g. *"I'll generate a Transaction Ledger for Q1 2025 as CSV. Starting now."*

### Step 1 — Trigger the export

Call the GraphQL query that matches the report's `entitiesType`, passing the export parameters. Run it with the MCP `execute` tool (validate first with `validate_query` if unsure).

**`entitiesType` → query to call**

| entitiesType | Query |
|---|---|
| LEDGER | `transaction` |
| ASSETS | `organizationBalance` |
| BALANCE | `organizationBalance` |
| HISTORICAL_BALANCE | `organizationBalance` |
| ACCOUNTS | `internalAccount` |
| GENERAL | `internalAccount` |
| STAKING_DATA | `stakingYieldRecord` |
| AUDIT_LOG | `auditLog` |
| LOGIN_HISTORY | `loginHistoryExport` |

**Report catalog (`exportFormat` values — verified against prod)**

| Report name | exportFormat | entitiesType |
|---|---|---|
| Transaction Ledger | BASIC_RAW_TRANSACTIONS | LEDGER |
| Realized Gains & Losses | EXTENDED_RAW_TRANSACTIONS | LEDGER |
| Cost Breakdown Raw Transactions | COST_BREAKDOWN_RAW_TRANSACTIONS | LEDGER |
| Rollup Breakdown † | ROLLUP_BREAKDOWN | LEDGER |
| Ledger Reconciliation | RECONCILIATION | LEDGER |
| Cost Basis Roll Forward | COST_BASIS_ROLL_FORWARD | LEDGER |
| Asset Roll Forward | ASSET_ROLL_FORWARD | LEDGER |
| ERP Pre-Sync | PRE_SYNC_JOURNAL | LEDGER |
| ERP Post-Sync | POST_SYNC_JOURNAL | LEDGER |
| MT940 Statement | MT940 | LEDGER |
| Asset Balances | RAW_BALANCES | ASSETS |
| Asset Balances V2 | RAW_BALANCES_V2 | ASSETS |
| Asset Balances - Archives † | ARCHIVED_BALANCES | ASSETS |
| Balance Trends | BALANCE_TRENDS | ASSETS |
| Wallet Balances | INTERNAL_ACCOUNTS_BALANCES | ASSETS |
| Cost Basis Stack Per Asset | COST_BASIS_STACK_PER_ASSET | ASSETS |
| Asset Fiat Values | DAILY_ASSET_PRICING | ASSETS |
| Revaluation Report | REEVALUATION | ASSETS |
| Historical Balance Format | HISTORICAL_BALANCE | HISTORICAL_BALANCE |
| Cost Basis Inventory † | COST_BASIS_INVENTORY | BALANCE |
| Organization Wallets | INTERNAL_ACCOUNTS | ACCOUNTS |
| Contacts | CONTACTS | ACCOUNTS |
| Third Party Addresses | THIRD_PARTY_ADDRESSES | ACCOUNTS |
| Chart of Account | CHART_OF_ACCOUNT | GENERAL |
| ERP Rules | ERP_RULES | GENERAL |
| Connected Custodians | CONNECTED_CUSTODIANS | GENERAL |
| Staking Rewards & Positions | STAKING_DATA | STAKING_DATA |
| Audit Trail / Log | AUDIT_LOG | AUDIT_LOG |
| Login History | LOGIN_HISTORY | LOGIN_HISTORY |

† = special handling (see "Reports needing extra parameters" below). The org catalog evolves — `availableReportTypes` is authoritative. **If a requested report isn't in this table, go to Step 1b and derive it from the schema** rather than guessing.

**Export parameters (always include):**

- `exportFormat` — value from the table above (UPPER_CASE)
- `exportName` — a descriptive, unique name (e.g. `"Transaction Ledger Q1 2025"`) — you'll match on this in Step 2
- `currency` — `"usd"` unless told otherwise
- `outputFormat` — `"CSV"` for downstream analysis, or `"XLSX"` if the user wants a spreadsheet

Add `timestamp_Gte` / `timestamp_Lte` for date-ranged reports (LEDGER, AUDIT_LOG).

> ### ⚠️ GraphQL variable types — get these EXACTLY right (first-run correctness)
>
> The BFF **strictly validates variable types**. A wrong type returns HTTP 400 and **no report is created** — and the `execute` tool surfaces this under an `error` / `error_type` field, *not* the GraphQL `errors` array, so it is easy to miss. Declare variables with these exact types:
>
> | Variable | GraphQL type | Notes |
> |---|---|---|
> | `exportFormat` | `String` | the UPPER_CASE value |
> | `exportName` | `String` | unique name |
> | `currency` | `String` | e.g. `"usd"` |
> | `outputFormat` | **`ReportOutputFormat`** | NOT `String`. Value `"CSV"` / `"XLSX"` |
> | `timestamp_Gte` / `timestamp_Lte` | **`DateTime`** | NOT `String`. ISO 8601 value |
> | `identifier_In`, `children_Asset_AssetClass_In`, `children_BelongsTo_In` | **`[String]`** | NOT `[ID]` |
>
> The params must be passed as **variables named exactly** `exportName`, `exportFormat`, etc. — the BFF reads them from `info.variable_values` by name. Inline literals or renamed variables (`$ef`) silently create **no** report.

Example — trigger a Transaction Ledger export (verified working form):

```graphql
query($limit: Int, $offset: Int, $timestamp_Gte: DateTime, $timestamp_Lte: DateTime,
      $exportFormat: String, $exportName: String, $currency: String, $outputFormat: ReportOutputFormat) {
  transaction(limit: $limit, offset: $offset, timestamp_Gte: $timestamp_Gte,
              timestamp_Lte: $timestamp_Lte, exportFormat: $exportFormat,
              exportName: $exportName, currency: $currency, outputFormat: $outputFormat) {
    results { id }
    totalCount
  }
}
```

```json
{
  "limit": 1,
  "offset": 0,
  "timestamp_Gte": "2025-01-01T00:00:00Z",
  "timestamp_Lte": "2025-03-31T23:59:59Z",
  "exportFormat": "BASIC_RAW_TRANSACTIONS",
  "exportName": "Transaction Ledger Q1 2025",
  "currency": "usd",
  "outputFormat": "CSV"
}
```

The export then generates asynchronously in the background. A 200 with `totalCount` only confirms the *query* ran — it does **not** mean a report was created (verify in Step 1c) and it does **not** mean the file is ready (poll in Step 2).

#### Reports needing extra parameters (omit these and the report errors or comes back empty)

| Report (`exportFormat`) | Trigger via | Required extra params |
|---|---|---|
| `ROLLUP_BREAKDOWN` | `transaction` | `identifier_In: [String]` — rollup parent hashes to decompose. Without it the report is **empty**. |
| `COST_BASIS_INVENTORY` | `transaction` (not `organizationBalance`) | exactly **one** `children_Asset_AssetClass_In: [String]` (asset-class id). Optional: at most one `children_BelongsTo_In: [String]`. Missing/multiple → report finishes with `status: ERROR` ("must select exactly one asset class"). Get an asset-class id from `query { assetClass(limit: N) { results { id name symbol } } }`. |
| `ARCHIVED_BALANCES` | `organizationBalance` | Requires an existing **commit snapshot** for the target date. If none exists it stays pending — prefer `HISTORICAL_BALANCE` (Time Capsule) for arbitrary dates. |

**Point-in-time balances.** For a balance report *as of a past date*, `organizationBalance` also accepts `balanceDate: DateTime` (reconstructs balances at that date — this is the Time Capsule path; passing `RAW_BALANCES` + `balanceDate` is promoted to `HISTORICAL_BALANCE`) and `commitId: UUID` (pull from a specific commit snapshot). Omit both for current balances.

#### `LOGIN_HISTORY` has a different shape

`loginHistoryExport` takes only `exportFormat: String!`, `exportName: String!`, `outputFormat: ReportOutputFormat` (no currency/limit/timestamps) and returns `{ success reportId }`:

```graphql
query($exportFormat: String!, $exportName: String!, $outputFormat: ReportOutputFormat) {
  loginHistoryExport(exportFormat: $exportFormat, exportName: $exportName, outputFormat: $outputFormat) {
    success
    reportId
  }
}
```

### Step 1b — Unknown or newly added report? Derive it from the schema (self-service)

`availableReportTypes` is the source of truth — it lists **every** report the org supports, including ones not in the tables above. When a requested report has no row here, do not guess: discover the trigger from the live schema using the MCP introspection tools.

```
- [ ] 1. availableReportTypes -> get this report's exportType + entitiesType + llmDescription
- [ ] 2. Pick the trigger query from entitiesType (Step 1 table). If entitiesType is new/unclear,
         default: transaction (tx / ledger / cost-basis), organizationBalance (balances / assets),
         internalAccount (accounts / metadata).
- [ ] 3. introspect(<query>) -> read the EXACT arg names AND types
- [ ] 4. build_query(<query>) -> canonical variables-as-args template (optional, handy)
- [ ] 5. validate_query(<assembled query>) BEFORE executing
- [ ] 6. Trigger with the 4 export params (+ timestamps only if the query exposes them)
- [ ] 7. Poll; if it errors, apply the error->fix table, then re-trigger
- [ ] 8. On DONE: return the link AND record the working recipe
```

Principles that make this work first-try:

1. **Read the format, never invent it.** Use `exportType` from `availableReportTypes` verbatim as `exportFormat`.
2. **Derive variable types from `introspect`, not from memory.** Declare each variable with the exact type the schema reports. This alone prevents the 400 "used in position expecting type X" failures. Sanity-check the usual ones: `outputFormat` → `ReportOutputFormat`, `currency` → `String`, `timestamp_*` → `DateTime`, list filters → `[String]`.
3. **Validate before executing.** `validate_query` catches arg/type/selection mistakes without creating a junk report.
4. **Start minimal, then add only what the error demands.** Trigger with just the export params first; let the error messages tell you which extra filter a generator requires.

**Error → fix table** (covers every failure mode seen against prod):

| Error | Meaning | Fix |
|---|---|---|
| `Variable '$X' of type 'A' used in position expecting type 'B'` | wrong declared type | re-declare `$X` as `B`, re-validate |
| `Unknown argument 'X' on field 'Y'` | that filter isn't on this query | switch to a query that exposes it (often `transaction`) or drop it |
| `Variable '$X' is never used` | declared a var with no matching arg | make it a real arg on the query, or remove it |
| 200 trigger, but report `status: ERROR` ("must select exactly one …" / "required …") | generator needs an extra required filter | `introspect` to find the matching arg name, fetch valid values from its list query (e.g. `assetClass`, `internalAccount`), add exactly what's required, re-trigger |
| report stays `IN_PROGRESS` indefinitely | data prerequisite missing (e.g. no commit snapshot) | tell the user what's missing and suggest an alternative report |

**Persist what you learn.** Once a new report triggers cleanly to `DONE`:
- Short term: save the recipe via the MCP `memory` tool — trigger query, `exportFormat`, working variable types, and any required filters.
- Durable: propose a new row for this skill's tables (report name, `exportFormat`, trigger query, required params) and surface it to the user so the skill stays current.

### Step 1c — Verify a report row was created (MANDATORY anti-silent-failure check)

**Do this immediately after every trigger, before you tell the user anything succeeded.** The trigger is a query *side effect*: if the request is even slightly malformed (inline literals instead of variables, a renamed variable like `$ef`, a missing required param), the BFF returns `200` with `errors: null` and **silently creates no report**. The only reliable way to know it worked is to look the row up by name.

Query for the row using the **exact** `exportName` you triggered with:

```graphql
query($name: String, $ordering: String, $limit: Int) {
  report(name: $name, ordering: $ordering, limit: $limit) {
    results { id name status }
  }
}
```

```json
{ "name": "<the exact exportName from Step 1>", "ordering": "-created_at", "limit": 1 }
```

- **`results` is empty (no row)** → this is a **SILENT FAILURE**, not "in progress". Do **NOT** report success. Re-check the trigger against the rules above — params passed as **variables** (not inline literals), variables **named exactly** `exportName`/`exportFormat`/`currency`/`outputFormat`/`timestamp_*`, correct types — then re-trigger **once**. If it still creates no row, stop and tell the user it failed silently and could not be created (don't loop forever).
- **A row exists** → good, the report was created. Continue to Step 2 to poll it to `DONE`.

> Make the `exportName` unique per run (e.g. append the date or a timestamp) so this lookup matches *your* row and not an older report with the same name.

### Step 2 — Poll until done

Find the report by the exact `exportName` from Step 1 (most reliable match):

```graphql
query($name: String, $ordering: String, $limit: Int) {
  report(name: $name, ordering: $ordering, limit: $limit) {
    results { id name status link reportSize exportFormat createdAt }
  }
}
```

```json
{ "name": "<the exportName from Step 1>", "ordering": "-created_at", "limit": 1 }
```

**Field/arg gotchas (these fail silently — get them right):**

- The ordering arg is `ordering`, **not** `orderBy`.
- The download field is `link` (a presigned S3 URL), **not** `downloadUrl`.
- The report-type field is `exportFormat`, **not** `exportType`.
- Do **not** filter by `exportFormat` to find your report: the stored value is **lowercase** (e.g. `rollup_breakdown`) while you triggered with UPPER_CASE, so an exact filter matches nothing. Filter by `name`.

**Polling loop:**

1. Query for the latest report by name.
2. Check `status`:
   - `IN_PROGRESS` → wait ~60s (e.g. `sleep 60` in a shell), then query again.
   - `DONE` → `link` holds the presigned download URL. Proceed.
   - `ERROR` → the generator rejected the inputs (e.g. a missing required filter). Read the failure message, fix the params, and re-trigger. Do not silently retry the same call.
3. Repeat up to **10 times**, waiting ~60s between attempts.

> **Check BOTH error channels.** A report can fail in two ways: (1) the trigger returns HTTP 400 with the problem under `error` / `error_type` (and an empty/absent GraphQL `errors`) — treat any non-empty `error` as a hard failure, do **not** report success; (2) the trigger returns 200 but the report later finishes with `status: ERROR`. Never assume success from a 200 alone.

Small reports finish in seconds; large reports (many assets, wide date ranges, large orgs) can take minutes to hours — set expectations early. Once `status == DONE`, share the `link` with the user.

**Presenting the download link.** Never paste the raw presigned URL into the chat — it's long, ugly, and full of credentials. Always render it as a clean clickable **markdown link** with friendly anchor text, putting the full URL in the link target:

```markdown
[Click here to download your report](<the full presigned link>)
```

You may tailor the anchor text to the report, e.g. `[Download your ERP Pre-Sync report (CSV)](<link>)`. Keep the anchor short and human; the URL itself stays hidden behind it. Mention that the link is presigned and expires after a limited window (~24h).

### Step 3 — Download + analyze (optional)

If the user wants the data analyzed (not just the link), download via the presigned URL and inspect it locally with pandas:

```python
import pandas as pd, requests
from io import BytesIO

resp = requests.get("<presigned_url>")
resp.raise_for_status()
df = pd.read_csv(BytesIO(resp.content))
print(df.shape, list(df.columns))
print(df.head())
print(df.dtypes)
```

Always start with `df.head()` and `df.dtypes`, then run the requested analysis (`groupby`, `value_counts`, `describe`, `pivot_table`). Format money as `f"${value:,.2f}"` and summarize large frames rather than dumping every row. For deeper per-report analysis guidance, use the `tres-report-analyzer` skill.

## Rules

- **ALWAYS** confirm report type (and date range, if required) before triggering.
- Match the query to the report's `entitiesType` using the table above — **except** the special-case reports above (`COST_BASIS_INVENTORY` triggers via `transaction`).
- For any report NOT in the tables, follow **Step 1b**: `introspect` the query for exact arg types, `validate_query`, trigger minimal, fix from the error→fix table, then persist the recipe. Never hand-guess types or filters for an unknown report.
- **Variable types are strict:** `outputFormat` is `ReportOutputFormat`, `timestamp_*` are `DateTime`, list filters are `[String]`. A wrong type = HTTP 400 = no report. Pass params as variables named exactly `exportName` / `exportFormat` / etc.
- **ALWAYS run Step 1c after triggering.** Verify the report row exists by exact `exportName` before claiming anything worked. An empty lookup means a **silent failure** (200 + `errors: null` + no row), not "in progress" — never report success without a confirmed row. Use a unique `exportName` per run so the lookup matches your row.
- For `ROLLUP_BREAKDOWN`, you MUST pass `identifier_In`; for `COST_BASIS_INVENTORY`, exactly one `children_Asset_AssetClass_In` — otherwise the report is empty or ERRORs.
- After triggering, verify success on **both** channels: no `error`/`error_type` on the trigger, and `status` reaches `DONE` (not `ERROR`).
- Poll the `report` query by `name`, not `exportFormat`; use `ordering` (not `orderBy`) and `link` (not `downloadUrl`).
- **Present the download link as a clickable markdown link** (e.g. `[Click here to download your report](<link>)`), never the raw presigned URL. Note that the link is presigned and expires after a limited window.
- Default `currency` to `"usd"` and `outputFormat` to `"CSV"` unless the user specifies otherwise.
- Never truncate or shorten transaction hashes, addresses, report IDs, or `identifier_In` values — always show/pass them in full.
- This is a read/export skill — **NEVER** run mutations that modify platform data.
