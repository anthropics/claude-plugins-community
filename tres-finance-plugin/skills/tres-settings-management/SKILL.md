---
name: tres-settings-management
description: Manage Organization Settings and Platform Settings via the TRES MCP GraphQL API. Use when users ask about org settings, platform settings, configuration, feature flags, enable/disable platforms, balance diff, commit strategy, cost basis, ERP, pricing, sync boundaries, or any setting read/write operation. Trigger phrases include "get settings", "show settings", "update settings", "change settings", "enable platform", "disable platform", "balance diff", "commit strategy", "cost basis strategy", "set min sync date", "configure", "turn on", "turn off".
---

# TRES MCP - Organization & Platform Settings

## How This Skill Works

This skill lets users view and modify configuration for their TRES Finance organization and individual blockchain/exchange platforms. There are two levels:

- **Organization Settings** — Apply to the entire org: how cost basis is calculated, which features are enabled, ERP behavior, pricing sources, commit scheduling, etc.
- **Platform Settings** — Apply per-platform (e.g., Ethereum, Arbitrum) and optionally per-wallet: commit strategy, sync date boundaries, balance diff, asset filtering, etc.

---

## Ground Rules

### 1. Always Start by Identifying the Org

Before doing anything, confirm which organization the user is connected to:

```graphql
query { admin { orgName } }
```

Tell the user: "You're connected to **{orgName}**."

### 2. Read Before Write

Before any mutation, ALWAYS fetch the current value of the setting(s) being changed. Show a clear before/after comparison.

### 3. Mutations Require Explicit Approval

Before executing ANY mutation, you MUST:
1. Show a clear summary table with **Setting**, **Current Value**, and **New Value**
2. Explicitly ask: "Shall I apply these changes to **{orgName}**?"
3. Only proceed after the user confirms
4. After execution, show the confirmed result from the mutation response

### 4. Warn About High-Risk Changes

Flag these settings as potentially dangerous and add a warning:
- `costBasisStrategy` — Changing mid-period can cause recalculations across the entire org
- `disableAutoCommit` — Stops all automatic data processing
- `skipCostBasis` — Disables cost basis entirely
- `commitStrategy: SKIP_ALL` — Fully disables a platform's data pipeline
- `enableMultiEntity` — Structural change, hard to reverse
- `allowShort` — Enables short positions in cost basis

### 5. Use Schema Introspection for Field Discovery

Do NOT rely on hardcoded field lists. Use the MCP `introspect` tool to discover available fields and their types dynamically:

- `introspect("OrganizationSettingsObjectType")` — all readable org settings
- `introspect("setOrganizationSettings")` — all writable org settings with descriptions
- `introspect("PlatformSettingsObjectType")` — all readable platform settings
- `introspect("setPlatformSettings")` — all writable platform settings with descriptions

When a user asks "what can I configure?" or you need to verify a field name or enum values, introspect first.

---

## Setting Categories (use when users ask vaguely)

If the user says "show me the settings" without specifics, offer these categories with plain-language explanations:

| Category | What It Controls |
|---|---|
| **Cost Basis** | How gains/losses are calculated (FIFO, LIFO, etc.), per-wallet vs org-wide, impairment |
| **Commit Pipeline** | Automatic data processing schedule, priority, stuck detection, sync hours |
| **Internal Transfers** | How transfers between the org's own wallets are detected and matched |
| **Pricing** | Where asset prices come from, stablecoin pegging, swap alignment |
| **ERP Integration** | How data syncs to accounting systems (NetSuite, Xero, QuickBooks) |
| **Dashboard & Features** | Which UI features are enabled (pivot tables, vesting, payments, multi-entity) |
| **Staking** | Staking rewards tracking and position management |
| **Reconciliation** | Cross-org and subsystem reconciliation behavior |
| **Reports** | Scheduled report timing, format, and content |
| **Platform Collection** | Which blockchains/exchanges are enabled, their sync boundaries and filters |

---

## Reading Organization Settings

### Query Structure

```graphql
query {
  admin {
    orgName
    organizationSettings {
      # include only the fields relevant to the user's question
    }
  }
}
```

- Organization is resolved from the auth token — no org ID needed
- Never request all fields at once — pick the category relevant to the question
- Use `introspect("OrganizationSettingsObjectType")` to discover available fields if needed

### Nested Fields (must expand sub-fields when querying)

These fields return objects/lists, not scalars. Always include their sub-fields:

| Field | Sub-fields | What It Is |
|---|---|---|
| `peggedStableCoinsToFiat` | `assetName`, `currency` | Stablecoins treated as equivalent to fiat |
| `pricingApiSourcePerAsset` | `assetName`, `pricingApiSource` | Custom pricing source per asset |
| `netsuiteCurrencySymbolToInternalId` | `currency`, `internalId` | NetSuite currency mapping |
| `simpleMatchingStrategies` | `beforeRange`, `afterRange` | Reconciliation time windows |
| `proofOfFunds` | `organizationName` | Proof of funds client config |

### Additional Admin Fields

The `admin` query also provides:
- `orgName` — the organization's display name
- `disabledPlatforms` — quick list of platforms with collection fully disabled
- `auth0Connections` — available SSO login methods

---

## Writing Organization Settings

### Mutation Structure

Uses patch semantics — only include the fields you want to change. Everything else stays as-is.

```graphql
mutation {
  setOrganizationSettings(
    costBasisStrategy: FIFO
  ) {
    organizationSettings {
      costBasisStrategy
    }
  }
}
```

Use `introspect("setOrganizationSettings")` to discover all mutable fields, their types, and descriptions.

### Workflow for Changing Org Settings

1. **Read** the current values of the setting(s) being changed
2. **Show** the user a before/after comparison table
3. **Warn** if any high-risk settings are involved
4. **Ask** for approval
5. **Execute** the mutation
6. **Confirm** by showing the returned values

---

## Reading Platform Settings

### Query Structure (top-level query)

Returns only platforms/accounts with explicit overrides. Platforms using all defaults won't appear.

```graphql
query {
  platformSettings(platform: ETHEREUM) {
    results {
      settingsId
      platform
      internalAccountId
      platformSettings {
        commitStrategy
        calculateBalanceDiff
        minLastSyncedAt
        maxToDate
        # add fields as needed — use introspect("PlatformSettingsObjectType") for full list
      }
    }
  }
}
```

### Filtering Options

All arguments are optional — combine as needed:

| Argument | Type | Use Case |
|---|---|---|
| `platform` | `Platform` | Show settings for a specific chain/exchange |
| `internalAccountId` | `Int` | Show settings for a specific wallet |
| `settingsId` | `String` | Exact match on storage key |
| `settingsId_Icontains` | `String` | Partial match (e.g., "ethereum" matches "ethereum_714128") |

- **No args** → all stored platform settings
- **`platform` only** → platform-wide + all per-wallet overrides for that platform
- **`platform` + `internalAccountId`** → only the per-wallet override
- **`internalAccountId` only** → all platforms for that wallet

### Quick Check: Which Platforms Are Disabled?

```graphql
query { admin { disabledPlatforms } }
```

---

## Writing Platform Settings

### Mutation Structure

Patch semantics — only included fields are merged. Existing values preserved.

```graphql
mutation {
  setPlatformSettings(
    platform: ARBITRUM
    internalAccountId: 714128    # omit for platform-wide
    commitStrategy: FULL
    minLastSyncedAt: "2025-01-01T00:00:00+00:00"
  ) {
    settingsId
    platformSettings {
      commitStrategy
      minLastSyncedAt
    }
  }
}
```

Use `introspect("setPlatformSettings")` to discover all available arguments.

### Key Arguments

- `platform` (required) — target blockchain or exchange
- `internalAccountId` (optional) — scope to a specific wallet. Omit for platform-wide
- DateTime values must be ISO 8601 with timezone: `"2025-01-01T00:00:00+00:00"`

### Balance Rollup (Balance Diff)

To enable balance-diff-based activity tracking for specific assets:

```graphql
mutation {
  setPlatformSettings(
    platform: ARBITRUM
    internalAccountId: 714128
    balanceRollupSettings: {
      assetIdentifiers: ["native"]
      interval: DAILY
    }
  ) {
    settingsId
    platformSettings {
      balanceRollupSettings { assetIdentifiers interval }
    }
  }
}
```

`assetIdentifiers` can be `"native"` for the chain's native asset, or contract addresses for tokens.

---

## Enabling / Disabling Platforms

Use `setPlatformCollectionStatus` (not `setPlatformSettings`) for simple enable/disable.

```graphql
mutation {
  setPlatformCollectionStatus(
    platformCollectionStatuses: [
      { platform: ARBITRUM, enabled: true }
      { platform: POLYGON, enabled: false }
    ]
  ) {
    success
  }
}
```

- `enabled: true` → platform will be collected in commits (FULL)
- `enabled: false` → platform is fully skipped (SKIP_ALL)

Supports bulk operations — multiple platforms in one call.

---

## Resolving Wallet Addresses to Internal Account IDs

When the user provides a wallet address, look up the internal account ID:

```graphql
query {
  internalAccount(identifier: "0x1887fa9edadeab7562b01cc3f4fa246ace2c3cdd") {
    results {
      id
      name
      identifier
      parentPlatform
    }
  }
}
```

Use the returned `id` as `internalAccountId` in platform settings mutations.

Note: `parentPlatform` represents the top-level chain family (e.g., `ethereum` covers Ethereum, Arbitrum, Polygon, etc.). A single wallet address on `ethereum` parentPlatform can have platform-specific settings for each L2.

---

## Common Workflows

### "Change the cost basis method to LIFO"

1. Query current: `admin { organizationSettings { costBasisStrategy } }`
2. Show: "Current: FIFO → New: LIFO"
3. Warn: "Changing the cost basis method will trigger recalculation. This affects all historical gain/loss calculations."
4. Ask for approval
5. Execute: `setOrganizationSettings(costBasisStrategy: LIFO)`

### "Enable Arbitrum"

1. Query disabled: `admin { disabledPlatforms }` — confirm ARBITRUM is in the list
2. Show: "ARBITRUM: Disabled → Enabled"
3. Ask for approval
4. Execute: `setPlatformCollectionStatus(platformCollectionStatuses: [{platform: ARBITRUM, enabled: true}])`

### "Set sync start date for wallet X on Polygon"

1. Resolve wallet: `internalAccount(identifier: "0x...")` → get `id`
2. Read current: `platformSettings(platform: POLYGON, internalAccountId: {id})` → get `minLastSyncedAt`
3. Show: "Wallet {name} on POLYGON: minLastSyncedAt: 1970-01-01 → 2025-01-01"
4. Ask for approval
5. Execute: `setPlatformSettings(platform: POLYGON, internalAccountId: {id}, minLastSyncedAt: "2025-01-01T00:00:00+00:00")`

### "Add balance diff for native asset on a specific wallet"

1. Resolve wallet: `internalAccount(identifier: "0x...")` → get `id`
2. Read current: `platformSettings(platform: ETHEREUM, internalAccountId: {id})`
3. Show: "Adding balance rollup for native asset (DAILY interval) on wallet {name} / ETHEREUM"
4. Ask for approval
5. Execute: `setPlatformSettings(platform: ETHEREUM, internalAccountId: {id}, balanceRollupSettings: {assetIdentifiers: ["native"], interval: DAILY})`

### "Show me which platforms are disabled"

1. Execute: `admin { disabledPlatforms }`
2. Present as a clean list grouped by chain family if many results

### "What pricing source is configured?"

1. Execute: `admin { organizationSettings { pricingApiSource peggedStableCoinsToFiat { assetName currency } pricingApiSourcePerAsset { assetName pricingApiSource } } }`
2. Present: default source + any per-asset overrides + pegged stablecoins

---

## Error Handling

| Error | Meaning | Resolution |
|---|---|---|
| 403 / Permission denied | User lacks `admin:*` permission | Contact org admin to grant access |
| Empty `platformSettings` results | No custom overrides — platform uses defaults | This is normal; explain that defaults apply |
| "does not exist for organization" | Internal account ID not found in this org | Verify the wallet address and re-resolve |
| Invalid enum value | Wrong value for a setting | Use `introspect` on the enum type to show valid options |
| DateTime parse error | Wrong format | Must be ISO 8601 with timezone: `"2025-01-01T00:00:00+00:00"` |
