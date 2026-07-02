---
name: tres-export-3rd-party-contacts
description: "Extract all 3rd-party (non-owned) addresses from a TRES Finance environment and export them as an XLSX workbook to help users build their contacts list. Use this skill whenever the user wants to export, list, or identify 3rd-party addresses, counterparties, or external addresses from their transactions — even if they don't say 'contacts'. Also trigger when the user asks to prepare a contacts import file, find unknown addresses, or build an address book from transaction history. Do NOT trigger for viewing existing contacts or searching the address book — only for extracting NEW 3rd-party addresses from transaction data."
---

# TRES Finance — Export 3rd-Party Addresses as Contacts Workbook

## Goal

Fetch all **unidentified** external addresses from the user's TRES environment using the `accountTxsSummary` query (the same data source that powers the "Unidentified Addresses" tab in the TRES UI), deduplicate them, enrich them with activity data, and produce an XLSX workbook with two tabs:

1. **Contacts** — the import-ready sheet matching the TRES contacts template. The user fills in names and tags here, then imports this sheet back into TRES.
2. **Address details** — enrichment data (network, tx counts, fiat volumes) to help users identify who each address belongs to.

The workflow gives users a fast way to build their address book: Claude extracts, deduplicates, and enriches the unidentified addresses, and the user just needs to label them.

## MCP Server

All GraphQL calls use the **user-tres-finance** MCP server (`execute` tool).

## Workflow

### Step 1 — Authenticate

Call `get_viewer` (no arguments) to confirm the session is active and note the organization name.

### Step 2 — Fetch unidentified addresses

Use the `accountTxsSummary` query with `identificationState: "UNIDENTIFIED"` — this is the same query the TRES UI uses for the "Unidentified Addresses" tab under Accounts. It already excludes the organization's own wallets and returns only external counterparty addresses that haven't been named yet.

```graphql
query UnidentifiedAddresses($limit: Int, $offset: Int, $identificationState: String, $excludeInternalAccounts: Boolean, $fiatCurrency: String) {
  accountTxsSummary(
    limit: $limit
    offset: $offset
    identificationState: $identificationState
    excludeInternalAccounts: $excludeInternalAccounts
    fiatCurrency: $fiatCurrency
  ) {
    totalCount
    results {
      accountIdentifier
      displayName
      inflowTxCount
      outflowTxCount
      inflowFiatValue
      outflowFiatValue
    }
  }
}
```

Variables:
```json
{
  "limit": 500,
  "offset": 0,
  "identificationState": "UNIDENTIFIED",
  "excludeInternalAccounts": true,
  "fiatCurrency": "usd"
}
```

Paginate through all results (increment `offset` by 500 each time until you've collected all entries from `totalCount`).

### Step 3 — Deduplicate and detect network

The `accountTxsSummary` query can return the same address more than once (e.g. different casing variants of the same EVM address, or separate rows for sender vs. receiver context). Deduplicate by **lowercased** `accountIdentifier`:

- Build a dictionary keyed by `accountIdentifier.lower()`
- For each address, keep the first occurrence's original casing and accumulate the total inflow + outflow tx count and fiat values
- Skip addresses with an empty or null `accountIdentifier`

Sort the deduplicated addresses by total fiat volume (inflow + outflow) descending, so the most active counterparties appear first — these are typically the ones the user will want to label first.

**Network detection:** The API does not return a network field, so infer the network from the address format. Use these rules:

| Address pattern | Network |
|---|---|
| Starts with `0x` (42 chars, hex) | EVM |
| Starts with `KT1` | Tezos (contract) |
| Starts with `tz1`, `tz2`, `tz3` | Tezos |
| Starts with `T` (34 chars, base58) | Tron |
| Starts with `bc1` or `1` or `3` (25–62 chars) | Bitcoin |
| Starts with `r` (25–35 chars) | XRP Ledger |
| Starts with `cosmos1` | Cosmos |
| Starts with `osmo1` | Osmosis |
| Starts with `terra1` | Terra |
| Starts with `addr1` or `stake1` | Cardano |
| Starts with `bnb1` | BNB Beacon Chain |
| Starts with `G` (56 chars) | Stellar |
| Starts with `D` or `A` or `L` or `M` or `ltc1` (26–35 chars) | Litecoin/Dogecoin (best guess) |
| None of the above | Unknown |

This is a best-effort heuristic — EVM addresses in particular could belong to Ethereum, Polygon, Arbitrum, Base, Avalanche, BSC, or any other EVM-compatible chain. The label "EVM" is intentionally broad because the address alone can't distinguish which chain it's on.

### Step 4 — Build the XLSX workbook

Use Python with `openpyxl==3.1.5`. If not installed, stop and display:
> "openpyxl is not installed. Please run: `python3 -m venv .venv && .venv/bin/pip install openpyxl==3.1.5`"

#### Tab 1: "Contacts" (import-ready)

This sheet matches the TRES contacts import template exactly:

| Contact Name | Contact Address | Contact Tag |
|---|---|---|
| *(blank)* | 0xABC... | *(blank)* |

- **Contact Name**: leave blank (the user will fill this in)
- **Contact Address**: the address identifier (original casing)
- **Contact Tag**: leave blank (the user will fill this in)
- Sorted by total fiat volume descending (same order as Address details)

#### Tab 2: "Address details" (enrichment)

| Contact Address | Network | Inflow Txs | Outflow Txs | Inflow USD | Outflow USD | Total USD |
|---|---|---|---|---|---|---|
| 0xABC... | EVM | 142 | 38 | 1,240,500 | 890,200 | 2,130,700 |
| KT1Xyz... | Tezos (contract) | 6 | 0 | 40,144,631 | 0 | 40,144,631 |
| TBmxn... | Tron | 23 | 5 | 340,100 | 52,000 | 392,100 |

- Same address order as the Contacts tab (sorted by Total USD descending)
- `Network`: inferred from address format (see Step 3)
- `Inflow Txs` / `Outflow Txs`: from `accountTxsSummary` results
- `Inflow USD` / `Outflow USD`: from `accountTxsSummary` fiat values
- `Total USD`: sum of inflow + outflow fiat values

#### Formatting guidelines

- Bold the header row on all tabs
- Auto-fit column widths for readability
- Format USD columns as numbers (no $ prefix in cells — use Excel number formatting)
- The "Contacts" tab should be the first/active sheet when the file opens, since that's the one the user will work in

### Step 5 — Save and present

Save the XLSX to the outputs directory. Use a descriptive filename like `tres_3rd_party_contacts_<org_name>_<date>.xlsx` (replace spaces and special chars with underscores).

Present the file to the user with a brief summary:
- How many unique unidentified addresses were found
- Total number of transactions involving these addresses
- A link to the XLSX file

Then explain what each tab is for:

> **Your workbook has 2 tabs:**
>
> 1. **Contacts** — This is the import-ready sheet. Fill in the **Contact Name** for each address you recognize, and optionally add a **Contact Tag** (e.g. `Exchange`, `Vendor`, `Treasury`). When you're done, use the **contacts import skill** to upload this sheet back into TRES.
>
> 2. **Address details** — Reference tab showing the detected network, activity stats for each address (inflow/outflow transaction counts and USD volumes). Use this to prioritize which addresses to label — the highest-volume counterparties are at the top. The network column helps narrow down which chain the address belongs to.

## Edge Cases

- **No unidentified addresses found**: If the result set is empty, tell the user — it likely means all counterparty addresses are already in the contacts list.
- **Mixed-case addresses**: EVM addresses can appear in different checksummed forms. Always compare in lowercase for deduplication, but preserve the original case in the output.
- **Zero/burn addresses**: Include `0x0000000000000000000000000000000000000000` in the output if it appears — the user may still want to label it as "Burn Address" or similar.
- **Unknown network**: If an address doesn't match any known pattern, set Network to "Unknown". Don't skip the address — it's still a valid counterparty.
