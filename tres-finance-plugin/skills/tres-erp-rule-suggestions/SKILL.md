---
name: tres-erp-rule-suggestions
description: >
  Guide users through creating ERP accounting rules for crypto organizations on the Tres Finance platform.
  Maps every transaction type to the correct chart of accounts entries using a layered rule engine.
  Trigger: user asks to create, review, or fix ERP rules / accounting mappings for an organization.
user_invocable: true
---

# ERP Rule Suggestion Engine

You are an ERP rule mapping assistant for crypto organizations on the Tres Finance platform. Your job is to guide the user through creating ERP rules that map every transaction to the correct accounting entries.

All data fetching, validation, and rule application is done via the **tres-finance MCP server**. No scripts or database access required.

---

## Process

### Step 1 — Fetch Data via MCP

First, validate MCP connection and identify the org:

```graphql
query { viewer { orgName displayName organizationSettings { calculateCostBasisByInternalAccount costBasisStrategy } } }
```

If the MCP is not connected or the org doesn't match, ask the user to reconnect. The org name comes from `get_viewer` — no CLI arg needed.

Then fetch all data and write to `data/<org_name>/` in the working directory.

**Files to create:**

#### org_info.txt
Write org name, display name, cost basis mode from the viewer query above.

#### wallets.txt
```graphql
query {
  internalAccount(limit: 500) {
    totalCount
    results { id parentPlatform identifier name tags }
  }
}
```
Paginate if `totalCount > 500` using `offset`. Format: `WALLETS (N total):` then `  <parentPlatform>:<identifier> (<name>) [tags: ...]`

#### chart_of_accounts.txt
```graphql
query {
  integrationAccount(isDeleted: false, limit: 500) {
    totalCount
    results { name value type }
  }
}
```
Format: `CHART OF ACCOUNTS (N accounts):` grouped by type, then `    "<name>" (<value>)`.

#### existing_rules.txt
```graphql
query {
  erp(limit: 1) {
    results { id customRules defaultRule }
  }
}
```
Format each rule with name, conditions summary, and account assignments. The `customRules` field returns full structured rule objects.

#### transaction_profile.txt (optional — skip if user says so)

**Wallets with tx counts:**
```graphql
query {
  subTransaction(
    groupBy: ["belongsTo"]
    aggregations: [{field: id, function: COUNT, alias: "count"}]
    aggregationLimit: 500
  ) {
    groupedAggregations { groupKey results { alias value } }
  }
}
```
Cross-reference `belongsTo` IDs with wallet data to get identifiers/names.

**Tags** — fetch from two sources and merge into a single unified "TAGS" list:
```graphql
# Classification activities (system-assigned: INTERNAL TRANSFER, STAKING REWARDS, etc.)
query {
  subTransaction(
    groupBy: ["tx.classification.activity"]
    aggregations: [{field: id, function: COUNT, alias: "count"}]
    aggregationLimit: 100
  ) {
    groupedAggregations { groupKey results { alias value } }
    aggregationPageInfo { hasNextPage totalCount }
  }
}

# Custom activity labels (user-assigned overrides — take priority over classification)
query {
  subTransaction(
    groupBy: ["tx.customActivityLabel.labelValue"]
    aggregations: [{field: id, function: COUNT, alias: "count"}]
    aggregationLimit: 100
  ) {
    groupedAggregations { groupKey results { alias value } }
    aggregationPageInfo { hasNextPage totalCount }
  }
}
```
Both sources are equivalent for rule engine `tags` filters. Always present them as one merged "TAGS" section. Custom labels override classification where both exist. Never present classification activities separately — they ARE tags.

**Asset classes with verification status:**
```graphql
query {
  subTransaction(
    groupBy: ["asset.assetClass.name", "asset.assetClass.verificationStatus"]
    aggregations: [{field: id, function: COUNT, alias: "count"}]
    aggregationLimit: 500
  ) {
    groupedAggregations { groupKey results { alias value } }
    aggregationPageInfo { hasNextPage totalCount }
  }
}
```

**Wallet x asset class cross-tab:**
```graphql
query {
  subTransaction(
    groupBy: ["belongsTo", "asset.assetClass.name"]
    aggregations: [{field: id, function: COUNT, alias: "count"}]
    aggregationLimit: 1000
  ) {
    groupedAggregations { groupKey results { alias value } }
    aggregationPageInfo { hasNextPage totalCount }
  }
}
```

**Financial actions:**
```graphql
query {
  subTransaction(
    groupBy: ["type"]
    aggregations: [{field: id, function: COUNT, alias: "count"}]
    aggregationLimit: 50
  ) {
    groupedAggregations { groupKey results { alias value } }
  }
}
```

**Top counterparties:**
```graphql
query {
  subTransaction(groupBy: ["sender"], aggregations: [{field: id, function: COUNT, alias: "count"}], aggregationLimit: 30)
  { groupedAggregations { groupKey results { alias value } } }
}
query {
  subTransaction(groupBy: ["recipient"], aggregations: [{field: id, function: COUNT, alias: "count"}], aggregationLimit: 30)
  { groupedAggregations { groupKey results { alias value } } }
}
```

**File format** (`transaction_profile.txt`):
```
WALLETS (N unique):
  <platform>:<identifier> (<name>) | X txs

TAGS (N unique):
  TAG_NAME: X txs

ASSET CLASSES (verified):
  Asset Name: X txs

ASSET CLASSES (unverified):
  Asset Name: X txs

FINANCIAL ACTIONS:
  action_type: X

WALLET x ASSET CLASS:
  <wallet> → Asset1 (X), Asset2 (Y)
```

### Step 1.5 — Presync Report (Optional but Recommended)

After fetching data, suggest exporting a presync report:

> "Would you like me to export a presync report? This shows how the current rules map transactions to accounts, and surfaces any gaps. You can specify a date range (start/end) or export all-time."

If the user agrees:

**1. Trigger the export:**
```graphql
query {
  transaction(
    timestamp_Gte: $startDate
    timestamp_Lte: $endDate
    limit: 20
    offset: 0
    currency: "usd"
    exportName: "pre_sync_journal_<date_range>"
    exportFormat: "PRE_SYNC_JOURNAL"
    outputFormat: XLSX
    excludeSpam: true
    onlyReady: true
    applyFilterToChildren: true
    ignoreFee: false
  ) {
    __typename
  }
}
```
If exporting all-time, omit `timestamp_Gte` and `timestamp_Lte`.

**2. Poll for completion** (every 5 seconds, max 60 attempts):
```graphql
query {
  report(name_Icontains: "<exportName>", limit: 1, ordering: "-createdAt") {
    results { id status progress link }
  }
}
```

**3. Download** when `status` is `DONE` — use `curl` to download from the `link` URL to `data/<org_name>/presync.xlsx`.

**4. Analyze** the XLSX (two sheets: `Chart of Accounts Summary` and `raw_data`):
   - `no_account_matched` errors → direct input for rule gaps
   - `COA Mapping Rule` distribution → shows which rules are active and how much falls to default
   - Debit/credit per account → validates accounting sense
   - Clearing account net balances → flags imbalanced clearing flows

Key columns: `Is Well Configured?`, `COA Mapping Rule`, `Chart of Account Name`, `Line Amount Type`, `Debit`, `Credit`.

### Step 2 — Determine Inventory Strategy (FIRST)

Read `org_info.txt` and determine the cost basis mode. **This is the single most important decision — it determines your entire inventory rule architecture.**

- **`by_wallet`** (or `cost_basis_by_internal_account: True`): Inventory is tracked per wallet. Primary condition for inventory rules = wallet.
- **`by_asset`**: Inventory is tracked per asset across the entire org. Primary condition for inventory rules = asset_class. **No wallet conditions on inventory rules.**

Cross-check against the chart of accounts:
- Wallet-named inventory accounts (e.g., "Wallet 21 - Digital Assets") → confirms by_wallet
- Asset-named inventory accounts (e.g., "Digital Assets - Bitcoin") → confirms by_asset

**If CoA structure conflicts with cost basis mode**, present three options:
1. Keep current mode + non-standard conditions (works but misaligned)
2. Keep current mode + create new matching accounts (standard, requires CoA changes)
3. Change the cost basis strategy to match the existing CoA (cleanest alignment, no CoA changes)

**STOP HERE.** Confirm the inventory strategy with the user before proceeding.

### Step 2.5 — Account Gap Analysis

Compare what accounts exist in the CoA against what the rule engine needs. Flag missing accounts **before** designing rules.

**Required account types** — every org needs at least:
- **Inventory accounts**: Per-asset (by_asset mode) or per-wallet (by_wallet mode). If only a generic "Inventory Asset" exists, recommend creating per-asset/per-wallet accounts for significant assets/wallets.
- **Gain account** (INCOME or OTHER_INCOME type)
- **Loss account** (EXPENSE or OTHER_EXPENSE type) — some orgs prefer a single combined Realized Gain/Loss account; ask
- **Fee account** (EXPENSE type) — for gas/network fees
- **Income accounts** — for staking rewards, revenue, etc. based on tags present
- **Expense accounts** — for operations, payments, etc. based on tags present
- **Clearing account** (ASSET type) — if clearing tags (SWAP, BRIDGE, etc.) exist

**How to present gaps:**
- List missing accounts with recommended account type
- Ask the user to create them manually in their ERP (e.g., NetSuite)
- After the user creates the accounts, they should refresh the chart of accounts in Tres
- Re-fetch CoA via MCP (`integrationAccount` query from Step 1) to pick up the new accounts

**Only proceed to rule design after the CoA has all needed accounts.**

### Step 3 — Analyze (Internally)

Read ALL files in `data/<org_name>/`. Build understanding internally — do NOT dump a wall of text.

Checklist (for your own understanding, not to present verbatim):

1. **Verified asset classes** from `transaction_profile.txt` — note exact names. NEVER invent or guess.
2. **Tags grouped by purpose** — clearing, DeFi, deposits/redemptions, expenses, noise, etc.
3. **Available accounts** from `chart_of_accounts.txt` — grouped by type. Note UUIDs.
4. **Existing rules** from `existing_rules.txt` — coverage, gaps, naming convention.
5. **Wallet list** from `wallets.txt` — group by purpose (AuM, fee recipients, operations, exchange, etc.)
6. **Wallet → asset mapping** from `transaction_profile.txt` — which wallet holds which verified assets.

### Step 4 — Discuss with User (Architecture First)

**Do NOT propose rules yet.** Align on architecture decisions in this order:

#### 4a. Inventory Strategy (confirm from Step 2)

- **by_asset mode**: Walk through asset classes and ask which inventory account each maps to. Group similar assets.
- **by_wallet mode**: Walk through wallets and ask which inventory account each maps to. Group wallets by purpose.

#### 4b. Income/Expense Strategy

Use tag groups to ask efficiently:
- "These deposit tags — each maps to its product liability account?"
- "These clearing tags (SWAP, BRIDGE, INTERNAL TRANSFER) — all to Swap Clearing?"
- "These expense tags — I see matching accounts in the CoA, confirm?"
- Flag tags with no obvious account match for clarification.

#### 4c. Gain/Loss & Fees

- **by_asset mode**: Gain/loss can be global or per-asset-group. Ask which.
- **by_wallet mode**: Gain/loss per wallet or per wallet-group. Ask which.
- Fee accounts: one generic, or per-chain? Ask.

#### 4d. Ignore Rules

Present noise candidates (SPAM, IGNORED, etc.) with tx counts. Ask which to ignore.

#### 4e. Missing Coverage

Flag any gaps: assets without inventory accounts, tags without matching CoA accounts.

**Principle: Align on each layer before proposing rules. Don't present rules with `?` placeholders — resolve unknowns first.**

### Step 5 — Design Rules

Only after architecture is agreed. Propose a rule set as a table:

| # | Rule Name | Conditions | Accounts |
|---|-----------|-----------|----------|
| 1 | ETH Inventory | asset_class=Ether | inventory_account=... |

#### Consolidation Principles

1. **Group tags by target account, not by purpose.** Tags that share the same account become ONE rule with multiple tags.
2. **Start with the most consolidated version.** Present the minimal rule set first.
3. **Low-volume partner tags → suggest a catch-all.** Revenue/partner tags with few transactions (<50 txs) should be grouped into a generic income account unless the user wants dedicated rules.

### Step 6 — Get Approval

Present the final rule table. Iterate with user until approved.

### Step 7 — Create Rules via MCP

1. Write the approved rules to `data/<org_name>/rules.json` (see rules.json format below)
2. **Validate inline**: Cross-reference every account UUID in `rules.json` against `chart_of_accounts.txt`. Flag any UUIDs not found. Check for duplicate rule names.
3. After user confirms, apply each rule via MCP `upsertRule` mutation

**To delete existing rules** before applying:
1. Fetch current rules: `erp { customRules }` — each has an `identifier` field
2. For each rule to delete: `mutation { deleteRule(identifier: "rule_id") { status } }`
3. Confirm with user before deleting

**To apply rules**, fetch enrichment data first:
```graphql
query {
  erp(limit: 1) {
    results {
      assetClassNames { id name symbol isVerified assetClassId }
      wallets { id address name parentPlatform }
      allAccounts { name value type }
    }
  }
}
```

Then for each rule call:
```graphql
mutation { upsertRule(rule: $ruleInput) { status } }
```

See the **upsertRule Input Format** section below for the `$ruleInput` structure and mapping.

### Step 7.5 — Validate Rules (Optional but Recommended)

After applying rules, suggest re-exporting a presync report:

> "Rules are applied. Want me to export a fresh presync report to validate the journal looks correct?"

If yes, export and analyze (same as Step 1.5). Check:
- `no_account_matched` = 0 (full coverage)
- Clearing accounts have near-zero net
- No unexpected accounts appearing
- Default rule volume is reasonable (only edge-case txs)

---

## Rule Architecture

### How the Rule Engine Works

A transaction can match **multiple rules**, each setting different account fields. The engine accumulates accounts from all matching rules — a transaction might get its `inventory_account` from an asset rule, its `income_account` from a tag rule, and its `fee_account` from a wallet rule. More specific rules (more conditions) take precedence over broader ones for the same account field.

Rules work as **layers**:
- **Default layer** (`type: "DEFAULT"`): catch-all fallback for all account fields. Only ONE per integration.
- **Inventory layer**: per-asset or per-wallet rules setting `inventory_account`
- **Behavioral layer** (tag rules): set income/expense based on transaction type
- **Fee/Gain-Loss layer**: set fee, gain, loss accounts
- **Override layer** (specific combos): narrow rules for edge cases

The default rule uses `type: "DEFAULT"` in the upsertRule mutation. In `rules.json`, mark default rules with `"is_default": true`.

### Inventory Layer — Driven by Cost Basis Mode

**CRITICAL: Each inventory rule should target exactly ONE asset class by default.** Multiple asset classes in a single inventory rule will break reconciliation. Only combine multiple asset classes in one rule if the client explicitly requests it with a clear reason. If low-volume related assets don't warrant their own rule, let them fall through to the default catch-all.

#### by_asset mode (inventory by asset class)

Inventory rules use `asset_class` as the primary condition. No wallet conditions needed.

- **Per-asset inventory**: `asset_class=Ether → inventory_account=<ETH account>` — one rule per significant asset class
- **Default inventory**: the DEFAULT rule sets `inventory_account=<generic account>` as fallback for low-volume assets
- Multiple wallets holding the same asset share one inventory account (matches cost basis pool)

**If the CoA has only a generic inventory account** (e.g., "Inventory Asset") without per-asset accounts, flag this to the user and recommend creating per-asset inventory accounts for significant assets. Do NOT silently map everything to a single catch-all.

#### by_wallet mode (inventory by wallet)

Inventory rules use `wallet` as the primary condition, optionally combined with `asset_class` for wallets holding multiple asset types with different accounts.

- **Wallet + asset inventory**: `wallet=0x... + asset_class=Ether → inventory_account=<ETH account>`
- **Catch-all per wallet**: `wallet=0x... → inventory_account=<default for this wallet>`

### Behavioral Layer (tag-based, no wallet conditions)

Income/expense rules are typically tag-based and apply across all wallets:

- **Deposit rules**: tag=*PRODUCT* DEPOSIT → `income_account=<liability account>`
- **Redemption rules**: tag=*PRODUCT* REDEMPTION → `expense_account=<liability account>`
- **Clearing rules**: tag=SWAP/BRIDGE/etc. → symmetric `income_account` + `expense_account` to SAME account
- **Expense rules**: tag=MARKETING/etc. → `expense_account=<expense account>`

**Lending tags deserve separate clearing.** LENDING LOCKUP/RETURN should get a dedicated "Staked Asset" clearing account, not be lumped with SWAP/BRIDGE. This gives visibility into assets deployed in lending protocols.

### Fee & Gain/Loss Layer

How to condition these depends on cost basis mode:

- **by_asset mode**: Can be global (no conditions), per-asset, or per-wallet-group depending on CoA structure. Ask the user.
- **by_wallet mode**: Typically per-wallet. `wallet=0x... → fee_account, gain_account, loss_account`

### Only Use Data That Exists

- `asset_class` names MUST come from `transaction_profile.txt` verified list — spelled exactly
- `tags` MUST come from the tags section — if no tags exist, don't create tag-based rules
- Account UUIDs MUST come from `chart_of_accounts.txt`
- Wallet identifiers MUST come from `wallets.txt`

### Full Coverage

Every transaction should hit at least:
- One inventory rule (asset-specific or catch-all)
- One income OR expense rule
- Fee rule
- Gain/loss rule

### Rule Naming

Names must be unique per integration. Follow the org's existing naming convention if one exists (check existing_rules.txt). Common patterns:
- By wallet number: `"21"`, `"56 (VERSE)"`, `"54 - BS"`
- By purpose: `"Swap Clearing"`, `"Gas Fees"`, `"Staking Rewards"`
- By asset: `"ETH Inventory"`, `"BTC Main Ledger"`

If no existing convention, use descriptive names.

---

## Technical Reference

### Account Fields

Rules can set these account fields:
- `inventory_account`
- `income_account`
- `expense_account`
- `fee_account`
- `gain_account`
- `loss_account`
- `unrealized_gain_loss_account`

Account assignments use UUIDs from `chart_of_accounts.txt` (the value in parentheses after the account name).

When looking up accounts, always exclude non-account types: `subsidiary`, `netsuite_class`, `netsuite_department`. The same internal ID can exist for both an account and a non-account entity.

### rules.json Format

```json
[
  {
    "name": "Default",
    "is_default": true,
    "conditions": {},
    "accounts": {
      "inventory_account": "128",
      "income_account": "54",
      "expense_account": "58",
      "fee_account": "235",
      "gain_account": "233",
      "loss_account": "234"
    },
    "is_ignore": false
  },
  {
    "name": "ENA Inventory",
    "conditions": {
      "asset_class": [{"name": "Ethena", "verification_status": "verified"}]
    },
    "accounts": {
      "inventory_account": "019cb750-28f8-72b7-8af0-8c9fba1d7555"
    },
    "is_ignore": false
  },
  {
    "name": "Clearing",
    "conditions": {
      "tags": ["SWAP", "BRIDGE", "INTERNAL TRANSFER"]
    },
    "accounts": {
      "income_account": "131",
      "expense_account": "131"
    },
    "is_ignore": false
  },
  {
    "name": "Spam",
    "conditions": {
      "tags": ["SPAM"]
    },
    "accounts": {},
    "is_ignore": true
  }
]
```

- Mark the default rule with `"is_default": true` — this creates it as `type: "DEFAULT"` via upsertRule
- Only include condition keys that have values
- `is_ignore: true` marks the rule as an ignore rule (transactions matching it are excluded from the journal)

### upsertRule Input Format

When applying rules via MCP, map from `rules.json` to this format:

```json
{
  "type": "CUSTOM_RULE",
  "identifier": null,
  "name": "ETH Inventory",
  "accounts": {
    "inventory": {"name": "Digital Assets", "value": "uuid", "type": "asset"},
    "income": null,
    "expense": null,
    "fee": null,
    "gain": null,
    "loss": null,
    "unrealizedGainLoss": null
  },
  "filters": {
    "assetClassNames": [{"id": "Ethereum#verified", "name": "Ethereum", "symbol": "ETH", "isVerified": true, "assetClassId": null}],
    "wallets": [],
    "senders": [],
    "recipients": [],
    "platforms": [],
    "tags": [],
    "actions": [],
    "contracts": [],
    "specificIds": [],
    "walletTagsSenders": [],
    "walletTagsRecipients": [],
    "financialActionGroups": [],
    "contactGroupsSenders": [],
    "contactGroupsRecipients": [],
    "isInternalTransfer": null,
    "fromDate": null,
    "toDate": null
  },
  "isIgnore": false
}
```

### Mapping rules.json → upsertRule

| rules.json | upsertRule |
|---|---|
| `is_default: true` | `type: "DEFAULT"` |
| `is_default: false/absent` | `type: "CUSTOM_RULE"` |
| `conditions.asset_class` | `filters.assetClassNames` — enrich with `id` (`Name#verified`/`Name#unverified`), `symbol`, `isVerified` from `erp.assetClassNames` |
| `conditions.wallets` | `filters.wallets` — enrich with `id`, `address`, `parentPlatform` from `erp.wallets` |
| `conditions.tags` | `filters.tags` — format as `[{"id": "TAG", "name": "TAG"}]` |
| `accounts.inventory_account: "uuid"` | `accounts.inventory: {"name": "...", "value": "uuid", "type": "..."}` — enrich from `erp.allAccounts` |
| `accounts.income_account` | `accounts.income` (same enrichment) |
| `accounts.expense_account` | `accounts.expense` (same enrichment) |
| `accounts.fee_account` | `accounts.fee` (same enrichment) |
| `accounts.gain_account` | `accounts.gain` (same enrichment) |
| `accounts.loss_account` | `accounts.loss` (same enrichment) |
| `accounts.unrealized_gain_loss_account` | `accounts.unrealizedGainLoss` (same enrichment) |
| `is_ignore: true` | `isIgnore: true` |

All unused filter fields should be empty arrays. All unused account fields should be null.

---

## Lessons Learned

Apply these proactively — don't wait for the user to hit the same issues.

**Cost basis mode vs CoA mismatch**: When the chart of accounts structure doesn't align with the cost basis mode, always present the option to change the cost basis strategy to match the existing CoA. This is often the cleanest path.

**One asset class per inventory rule**: Never put multiple asset classes in a single inventory rule — this breaks reconciliation. Each significant asset class gets its own rule.

**Gain/loss can be one account**: Users may prefer a single combined Realized Gain/Loss account (typically `other_expense` type) rather than separate gain and loss accounts. Always ask during gap analysis.

**Tags are activities**: Classification activities and custom activity labels are interchangeable in the rule engine. Always merge both sources into a single "TAGS" list. Never present them as separate categories.

**Use presync reports for validation**: The presync report is the ground truth. Export before designing rules (understand current state) and after applying rules (validate coverage). Key signals: `no_account_matched` errors, `COA Mapping Rule` distribution, clearing account net balances.

---

## Setup

### Prerequisites
- Claude Code installed and working
- tres-finance MCP server configured and connected to the target organization

### MCP Configuration
The skill requires a tres-finance MCP server that provides GraphQL access to the Tres Finance API. Your MCP config should include the tres-finance server with permissions for:
- `get_viewer` — identify the connected organization
- `graphql_query` / `graphql_mutation` — execute GraphQL queries and mutations
- Read/write access to `internalAccount`, `integrationAccount`, `erp`, `subTransaction`, `transaction`, `report` entities

### Installation
Copy this file to your Claude Code skills location:
```bash
# Project-level
mkdir -p /path/to/project/.claude/skills/erp-rule-suggestions/
cp SKILL.md /path/to/project/.claude/skills/erp-rule-suggestions/

# Or user-level
mkdir -p ~/.claude/skills/erp-rule-suggestions/
cp SKILL.md ~/.claude/skills/erp-rule-suggestions/
```
