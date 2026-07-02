---
name: tres-wallets-upload
description: >
  Upload and onboard multiple on-chain wallets or exchange accounts into Tres Finance.
  Use this skill whenever the user wants to add wallets, onboard wallets, import wallets,
  upload wallet addresses, ingest wallets, or connect exchanges into Tres — whether from
  a file (CSV/Excel) or by typing them manually. This skill guides Claude through the full
  flow: wallet type selection → input collection → validation → preview with editable
  HTML table → exchange credential collection (if exchange) → user confirmation → batch
  creation via the TRES MCP API. Always trigger this skill for wallet onboarding, wallet
  data ingestion, or any request to "add wallets to Tres".
compatibility: "Requires TRES Finance MCP connected (https://ai.tres.finance/mcp)"
---

# TRES Wallet Upload Skill

Onboard on-chain wallets and exchange accounts into Tres Finance with validation, preview, and confirmation.

---

> ⚠️ **EXECUTION RULE — READ BEFORE STARTING:**
> This skill is a strict sequential checklist. You MUST follow every step in the exact order written — do not skip, merge, or reorder steps. Before moving to the next step, verify the current step is fully complete. Steps that involve API calls (schema fetch, existing-wallet check, batch mutation) are mandatory — never skip them to save time or because results seem obvious. If you catch yourself about to skip a step, stop and execute it first.

---

## Step 0 — Ask Wallet Type

Before doing anything else, ask the user what kind of wallet they want to add using `ask_user_input_v0`:

```
question: "What would you like to add to Tres?"
options:
  - "On-Chain Wallets (Ethereum, Solana, Bitcoin, etc.)"
  - "Exchange Accounts (Binance, Coinbase, Kraken, etc.)"
type: single_select
```

- If the user selects **On-Chain Wallets** → proceed to **[ON-CHAIN FLOW]** (Step OC-1)
- If the user selects **Exchange Accounts** → proceed to **[EXCHANGE FLOW]** (Step EX-1)

---

---

# ON-CHAIN FLOW

---

## Step OC-1 — Ask for Input Method

Ask the user how they want to provide their on-chain wallets using `ask_user_input_v0`:

```
question: "How would you like to add your wallets?"
options:
  - "Upload a file (CSV or Excel)"
  - "Enter manually in a table"
type: single_select
```

Wait for the user's response, then proceed to the matching option in Step OC-2.

---

## Step OC-2 — Collect Wallet Data

### Option A: File Upload
If the user selects "Upload a file" (or uploads a CSV or Excel file directly):
- Read the file with pandas / openpyxl from `/mnt/user-data/uploads/`
- Expected columns (flexible): `name`, `address` (or `identifier`), `network` (or `platform`), `tags` (optional), `description` (optional)
- Normalise header names (case-insensitive, strip spaces, accept aliases)
- Parse into a list of wallet dicts, then proceed to Step OC-3

### Option B: Simple Manual Entry (conversational)
If the user selects "Enter manually in a table":
- **Do NOT render an HTML widget.** Instead, ask the user to provide their wallets in plain text, one per line, in this format:
  ```
  Name | Address | Network | Tags (optional)
  ```
  Example:
  ```
  Treasury Hot | 0xABCD...1234 | ETHEREUM | defi,treasury
  Cold Storage | bc1q...xyz | BITCOIN |
  ```
- Once the user pastes their wallets, parse the lines into a list of wallet dicts, then proceed to Step OC-4.
- If the user is unsure of the network name, tell them to type it as best they can and you will fuzzy-match it to the correct `ParentPlatform` value.

---

## Step OC-3 — Fetch Live Platform List from Schema

**Always** fetch the ParentPlatform enum values live from the TRES MCP schema — never hardcode them. Use:

```graphql
# Via TRES MCP introspect tool:
introspect("ParentPlatform")
```

This returns the full list of valid enum values to use in the network dropdown and for validation.

### Identifying exchanges vs on-chain wallets

To filter the ParentPlatform list to on-chain platforms only, exclude any value that matches a known exchange/custodian. The authoritative live list of supported exchanges is fetched in the Exchange Flow (Step EX-1). As a local heuristic for the on-chain filter, exclude these:

```
ANCHORAGE, AQUANOW, ASCENDEX, B2C2, BACKPACK, BINANCE_EXCHANGE, BINANCE_EXCHANGE_TR,
BITCOIN_SUISSE, BITFINEX, BITGET, BITGO, BITMEX, BITSO, BITSTAMP, BITVAVO, BREX,
BTC_MARKETS, BTCTURK, BULLISH, BYBIT, CEFFU, CIRCLE, COBO, COINBASE, COINBASE_COMMERCE,
COINBASE_EXCHANGE, COINBASE_INTERNATIONAL, COINBASE_PRIME, COINEX, COPPER, CRYPTOCOM,
CRYPTOCOM_EXCHANGE, CUSTOMERS_BANK, DERIBIT, EQUALSMONEY, FALCONX, FIDELITY,
FIFTH_THIRD_BANK, FIREBLOCKS, FORDEFI_UTXO, FTX, FTXUS, GATEIO, GEMINI, HITBTC, HTX,
KRAKEN, KRAKEN_CUSTODY, KRAKEN_FUTURES, KUCOIN, LAYERONE, LEDGER_ENTERPRISE, LMAX,
LUKKA, M2, MERCADO, MERCURY, MERCURY_TREASURY, MEOW, MEOW_TREASURY, MESH_PAYMENTS,
MORGAN_STANLEY, NONCO, OKX, PAXFUL, PARADEX, QONTO, QREDO, REVOLUT_FR, REVOLUT_UK,
SVB_GO, SVB_ONLINE, SYGNUM, TALOS, VERTEX, WHITEBIT, WINTERMUTE, WISE_US,
BANK_HAPOALIM_BIZ, BANK_HAPOALIM_INTERNATIONAL, BANK_OF_AMERICA,
BANQUE_POPULAIRE_RIVES_DE_PARIS, CHASE, CHECKOUT
```

Any platform NOT in this list is treated as an on-chain wallet requiring a standard blockchain address.

---

## Step OC-4 — Validate Wallets

Run ALL checks below. Collect errors per-row; do NOT abort early.

### Required field checks
| Field | Rule |
|-------|------|
| `name` | Non-empty string |
| `identifier` | Non-empty string |
| `parentPlatform` | Must be a valid `ParentPlatform` enum value (from live schema) |

### Network name normalisation
If a network name from a CSV is lowercase or mixed-case (e.g. `tezos`, `Ethereum`), uppercase it and fuzzy-match to the nearest valid `ParentPlatform` enum value. Show a warning banner in the preview noting the normalisation and asking the user to confirm.

### Address format validation per network (on-chain only)
Apply these regex rules for on-chain wallets. Skip for exchanges.

| Network(s) | Rule |
|---|---|
| ETHEREUM, BNB, POLYGON, AVALANCHE_*, ARBITRUM, OPTIMISM, BASE, FANTOM, MOONBEAM, and other EVM chains | `^0x[0-9a-fA-F]{40}$` |
| BITCOIN | P2PKH `1...`, P2SH `3...`, or Bech32 `bc1...` — 25–62 chars |
| SOLANA | Base58, 32–44 chars: `^[1-9A-HJ-NP-Za-km-z]{32,44}$` |
| TRON | `^T[1-9A-HJ-NP-Za-km-z]{33}$` |
| TEZOS | `^tz[123][1-9A-HJ-NP-Za-km-z]{33}$` |
| SUI, APTOS | `^0x[0-9a-fA-F]{62,64}$` |
| STELLAR | Starts with `G`, 56 chars |
| RIPPLE | Starts with `r`, 25–34 chars |
| CARDANO | Starts with `addr1`, length > 50 |
| NEAR | Ends in `.near` OR 64-char hex |
| TON | Starts with `EQ` or `UQ`, 48 chars |
| ALGORAND | 58-char Base32 uppercase |

### Network–address mismatch detection
Flag obvious mismatches (e.g. `0x...` address on SOLANA network, or Bitcoin address on ETHEREUM).

### Duplicate detection

**Within-batch duplicates:**
Flag rows sharing the same `(identifier, parentPlatform)` pair. Mark both as errors.

**Existing-wallet check against Tres (batches ≤ 200 wallets):**
```graphql
{
  internalAccount(identifier_In: ["addr1", "addr2", ...]) {
    results { id name identifier parentPlatform }
  }
}
```
Build a lookup: `key = identifier.toLowerCase() + "|" + parentPlatform.toUpperCase()`
- Match → mark as **⚠️ warning** (yellow): `"Exists (ID: XXXXX)"` — API will update, not duplicate
- Summary bar must show: `X new | Y already exist | Z errors`

For batches > 200: skip the API check, show a note in the preview.

---

## Step OC-5 — Show Text Preview

> 🚫 **HARD GATE:** Do NOT render this preview until Step OC-4 (validation) AND the existing-wallet Tres API check are both fully complete. Showing the preview without the API check is a violation of this skill.

**Do NOT render an HTML widget.** Instead, present the wallet data as a clean markdown table in plain text so the user can review it:

```
| # | Name | Address | Network | Tags | Status |
|---|------|---------|---------|------|--------|
| 1 | Treasury Hot | 0xABCD...1234 | ETHEREUM | defi | ✅ New |
| 2 | Cold Wallet | bc1q...xyz | BITCOIN | | ⚠️ Exists (ID: 12345) |
| 3 | Bad Wallet | invalid-addr | SOLANA | | ❌ Invalid address |
```

- Show a summary line: `X new | Y already exist | Z errors`
- List all errors below the table with row number and description:
  ```
  Errors:
  - Row 3 (Bad Wallet): Invalid SOLANA address format
  ```
- If there are errors, tell the user to correct and re-paste the data before proceeding
- If there are only warnings (existing wallets), ask: "Ready to upload? Existing wallets will be updated. Type **yes** to confirm."
- If all rows are valid, ask: "Ready to upload N wallets to Tres Finance. Type **yes** to confirm."

When the user confirms → proceed to Step OC-6.

---

## Step OC-6 — Final Confirmation

When Claude receives `TRES_WALLET_UPLOAD_CONFIRMED:`:
1. Parse the JSON payload
2. Present a plain-text summary:
   ```
   About to upload N wallets to Tres Finance:
   - 3 ETHEREUM wallets
   - 2 SOLANA wallets
   - 1 TEZOS wallet (will update existing)

   Shall I proceed?
   ```
3. Wait for explicit user confirmation ("yes", "confirm", "go ahead")

---

## Step OC-7 — Execute Batch Upload

Call `updateBatchInternalAccounts` via TRES MCP:

```graphql
mutation UpdateBatchInternalAccounts($internalAccounts: [InternalAccountInput]) {
  updateBatchInternalAccounts(internalAccounts: $internalAccounts) {
    internalAccounts {
      id
      name
      identifier
      parentPlatform
      status
    }
    validationResults {
      iaIdentifier
      validationResult {
        issueType
        errorMessage
      }
    }
  }
}
```

Variables per wallet:
```json
{
  "name": "Treasury Hot",
  "identifier": "0xABCD...",
  "parentPlatform": "ETHEREUM",
  "tags": ["defi", "treasury"],
  "enforceCollectTransactions": true
}
```

Note: `platformKeys` is not included for on-chain wallets.

### Chunking
If batch > 100 wallets, split into chunks of 50 and call sequentially.

### Result handling
- Parse `validationResults` — surface any `issueType` / `errorMessage` to the user
- Show success count and any failures
- For failures, offer to retry just the failed wallets

---

---

# EXCHANGE FLOW

---

## Step EX-1 — Introduction & Guide

Show the user the integration guide link:

> Before connecting an exchange, please review the **Tres Finance Exchange Integration Guide**:
> 👉 https://help.tres.finance/article/integrating-your-exchange-accounts-with-tres-finance

Then fetch the **live validated exchange list** from TRES MCP — never hardcode it:

```graphql
query GetAllValidatedExchanges {
  ledgerFilters {
    allValidatedExchanges {
      id
      displayName
    }
  }
}
```

This returns the authoritative list of supported exchanges (47 as of writing, but always fetch live). Sort A-Z by `displayName`. Present as a native `<select>` dropdown using `ask_user_input_v0` or inline in a `show_widget` form, mirroring the Tres UI with a "Connection Guidelines ↗" link alongside the label.

---

## Step EX-2 — Fetch Required Fields for the Selected Exchange

Once the user selects an exchange, fetch its credential fields. **Use the `id` value (lowercase) as the `exchangeName`:**

```graphql
query ExchangeRequiredFields {
  exchangeRequiredFields {
    requiredFields(exchangeName: "<exchange_id_lowercase>") {
      name
      type
      description
      mapping
    }
  }
}
```

**Important:** Skip any field where `mapping` starts with `https://` — these are integration guide links, not credential inputs. Show them as a clickable link instead.

Store the remaining fields. Each field has:
- `name` — the credential field key
- `description` — the human-readable label to show the user
- `mapping` — the key used when constructing `platformKeys` (e.g. `platform_keys.api_key`)
- `type` — use to determine input type

---

## Step EX-3 — Collect Exchange Credentials (Conversational)

**Do NOT render an HTML widget.** Instead, ask the user for credentials in plain conversational steps.

First, show the integration guide link:
> 📖 Before connecting, review the guide: https://help.tres.finance/article/integrating-your-exchange-accounts-with-tres-finance

Then ask for the fields one by one (or all at once in a single prompt), clearly listing what is needed:

```
To connect <Exchange Name>, I need the following:

**Account Name** (required) — a friendly name for this account in Tres
**API Key** (required)
**API Secret** (required, will be stored securely)
**Tags** (optional) — comma-separated tags

Please provide these values. Keep API secrets private — do not share them in public channels.
```

- For fields where `field.name` contains "secret", "private", "signing", or "passphrase" — note they will be stored securely
- For optional fields (e.g. OKX sub-account), label them clearly as `(optional)`
- Skip any field where `mapping` starts with `https://` — show it as a link instead

### Mandatory confirmations (ask as yes/no questions before proceeding)
Before accepting the credentials, ask:
1. "Do you confirm the API key has **read-only permissions**? (yes/no)"
2. "Do you agree to the **Tres Finance Terms of Service**? (yes/no)"

Only proceed once both are confirmed.

Once all credentials and confirmations are collected, store them in the queue format and proceed to Step EX-4.

---

## Step EX-4 — Accumulate Exchange Accounts

After collecting credentials for an exchange:
1. Parse and store the account data in a pending queue
2. Confirm: `✅ <accountName> (<exchange>) added to queue`
3. Display the running queue as a brief list:
   ```
   Queued accounts:
   1. My Binance Account (BINANCE_EXCHANGE)
   ```
4. Ask: "Would you like to **add another exchange** or **proceed to upload**?"

If user wants to add another → loop back to **Step EX-1** (queued accounts are preserved).
If user wants to proceed → go to **Step EX-5**.

---

## Step EX-5 — Final Review & Confirmation

Present a plain-text summary of all queued accounts:

```
Ready to connect the following exchange accounts to Tres Finance:

1. My Binance Account (BINANCE_EXCHANGE)
2. Kraken Main (KRAKEN)

Shall I proceed?
```

Wait for explicit user confirmation ("yes", "confirm", "go ahead", etc.)

---

## Step EX-6 — Execute Exchange Account Creation

Call `updateBatchInternalAccounts` via TRES MCP for all queued accounts:

```graphql
mutation UpdateBatchInternalAccounts($internalAccounts: [InternalAccountInput]) {
  updateBatchInternalAccounts(internalAccounts: $internalAccounts) {
    internalAccounts {
      id
      name
      identifier
      parentPlatform
      status
    }
    validationResults {
      iaIdentifier
      validationResult {
        issueType
        errorMessage
      }
    }
  }
}
```

Variables per exchange account:
```json
{
  "name": "<accountName>",
  "identifier": "<accountName>",
  "parentPlatform": "<EXCHANGE_ID_UPPERCASE>",
  "tags": ["<tag1>"],
  "enforceCollectTransactions": true,
  "platformKeys": "{\"api_key\": \"...\", \"api_secret\": \"...\"}"
}
```

**Important:**
- `identifier` = account name (no blockchain address for exchanges)
- `platformKeys` = a **JSON string** (not an object), built from `field.mapping` → value pairs collected in the form
- `parentPlatform` = exchange `id` uppercased (e.g. `binance_exchange` → `BINANCE_EXCHANGE`)
- Process all accounts in a single batch call where possible

### Result handling
- Show success/failure per account
- Surface `issueType` and `errorMessage` for failures
- Offer to retry failed accounts

---

## Error Messages & Recovery

| Situation | What to do |
|-----------|-----------|
| CSV has no `address` column | Ask user to map which column contains the wallet address |
| Unknown network name | Fuzzy-match to nearest `ParentPlatform` enum value, show warning banner, ask user to confirm |
| Address format invalid | Mark as error in preview; user must fix or remove the row before upload |
| Duplicate in batch | Mark both rows as errors; user must remove or fix one |
| Wallet already exists in Tres | Mark as ⚠️ warning (yellow); proceed — API will update it |
| No file and no wallets typed | Prompt user to either upload a file or use the manual table |
| Batch > 200 wallets | Skip existing-wallet API check; show informational note |
| MCP mutation returns error | Show error per wallet; offer retry |
| Exchange credentials rejected | Show the validation error and prompt user to re-enter credentials |
| `exchangeRequiredFields` returns empty | Inform user that this exchange may need manual setup; link to the guide |
| `allValidatedExchanges` returns empty | Fall back to informing user and linking to https://help.tres.finance |
