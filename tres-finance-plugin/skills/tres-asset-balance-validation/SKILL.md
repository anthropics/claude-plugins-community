---
name: tres-asset-balance-validation
description: >
  Validate wallet balances in TRES Finance against DeBank and generate a discrepancy
  report. Use this skill whenever the user asks to validate, verify, cross-check, or
  audit their TRES balances against on-chain data or DeBank. Also trigger when the
  user asks if their balances are correct or wants to see discrepancies. Only
  EVM-compatible wallets are supported.
---

# Tres Finance — Asset Balance Validation

## Overview

This skill validates wallet balances in **Tres Finance** against **DeBank**, providing a clear discrepancy report as both an interactive HTML file and a PDF. It compares per-asset token amounts (including DeFi position underlying tokens) for each EVM wallet and flags matches, minor differences, major discrepancies, missing assets, untracked tokens, and unmatched positions.

> **Scope:** Only EVM-compatible wallets are supported (DeBank limitation). Exchange accounts, non-EVM chains, and empty wallets are skipped.

---

## When to Use

Trigger this skill whenever a user asks to:

- Validate or verify their TRES balances
- Cross-check or audit wallets against external on-chain data
- Compare TRES data to DeBank
- Check if their balances are correct

**Example phrases:**
- *"Validate my balances"*
- *"Check my wallets against DeBank"*
- *"Are my TRES balances correct?"*
- *"Show me any discrepancies between TRES and on-chain data"*

---

## Prerequisites

| Requirement | Details |
|---|---|
| TRES Finance access | Must be authenticated via `get_viewer` |
| DeBank API key | Free key available at [cloud.debank.com](https://cloud.debank.com) |
| EVM wallets | At least one `0x...` wallet tracked in TRES |

---

## Process Overview

### Step 1 — Authenticate with TRES
Call `get_viewer` to confirm the organization name.

### Step 2 — Fetch wallets and balances from TRES

**IMPORTANT — Timeout handling:** The `internalAccount` query with both `balances` and `positions` will timeout for large orgs. Split into two separate queries:

**Query 1: Wallets + Balances only (no positions)**

```graphql
query {
  internalAccount {
    results {
      id
      name
      identifier
      isExchange
      platforms
      balances {
        amount
        asset {
          symbol
          contract { identifier }
        }
        fiatValue { value unitPrice fiatCurrency }
      }
    }
  }
}
```

> **Note:** The `amount` field is returned as a **string**, not a number. Always `float()` it before arithmetic.

**Wallet classification:**

| Type | Condition | Validated? |
|---|---|---|
| EVM | `0x...` address + EVM platform + `isExchange: false` | ✅ Yes |
| Exchange | `isExchange: true` | ❌ No |
| Non-EVM | Bitcoin, Tezos, Tron, etc. | ❌ No |
| Empty | No asset balances | ❌ No |

**Supported EVM platforms:** Ethereum, Arbitrum, Optimism, Polygon, Base, Avalanche, Binance, Gnosis Chain, zkSync, Fantom, Celo, Berachain, Linea, Scroll, Sonic, HyperEVM.

### Step 3 — Fetch DeFi positions from TRES

**Do NOT use the `positions` sub-field on `internalAccount`** — it returns all historical snapshots (can be 3000+ entries per wallet) and will timeout or exceed token limits.

Instead, use the dedicated `getStatelessWalletsPositions` query which returns **current** positions only:

```graphql
query {
  getStatelessWalletsPositions(
    walletIdentifiers: ["0x..."],
    platform: ETHEREUM,
    application: "aave-v3"
  ) {
    walletIdentifier
    displayName
    positionType
    platform
    children {
      symbol
      amount
      assetIdentifier
      fiatValue
    }
    fiatValue
    id
  }
}
```

**Required parameters:**
- `walletIdentifiers`: array of wallet addresses
- `platform`: must be an enum value like `ETHEREUM`, `POLYGON`, `ARBITRUM`, etc.

**Optional but recommended:**
- `application`: filter by protocol (e.g. `"aave-v3"`, `"verse"`, `"lido"`, `"merkl"`, `"uniswap-v4"`, `"sablier"`, `"ethena"`, `"stakewise"`, `"quickswap"`, `"steer"`, `"yieldnest"`, `"morphoblue"`)

**IMPORTANT:** Without the `application` filter, the query returns empty results. Always specify the application.

**Batching strategy:**
1. First, fetch DeBank `all_complex_protocol_list` for each wallet to discover which protocols have positions
2. Map DeBank protocol names to TRES application names (lowercase, hyphenated)
3. Use GraphQL aliases to batch multiple wallet+platform+application combos into a single query:

```graphql
query {
  a1: getStatelessWalletsPositions(walletIdentifiers: ["0x..."], platform: ETHEREUM, application: "aave-v3") {
    walletIdentifier displayName positionType platform id
    children { symbol amount assetIdentifier fiatValue }
  }
  a2: getStatelessWalletsPositions(walletIdentifiers: ["0x..."], platform: ETHEREUM, application: "verse") {
    walletIdentifier displayName positionType platform id
    children { symbol amount assetIdentifier fiatValue }
  }
}
```

Keep each batched query to ~6 aliases max to avoid timeouts.

### Step 4 — Retrieve DeBank API key

Read `DEBANK_API_KEY` from plugin user config — do **not** ask the user to paste it in chat.
If the key is absent or empty, stop and display:

> "DEBANK_API_KEY is not configured. Please add it via the plugin settings (obtain your key at https://cloud.debank.com)."

### Step 5 — Fetch DeBank data via bash

For each EVM wallet, fetch **two** endpoints:

1. **Token balances:** `all_token_list` — covers all chains without requiring a `chain_id`
2. **DeFi protocol positions:** `all_complex_protocol_list` — returns LP, staking, lending positions with underlying token amounts

Use `--data-urlencode` with `-G` so the wallet address is never shell-interpolated into the URL string:

```bash
# Token balances
curl -s -G \
  -H "AccessKey: ${user_config.DEBANK_API_KEY}" \
  --data-urlencode "id=$WALLET_ADDR" \
  "https://pro-openapi.debank.com/v1/user/all_token_list"

# DeFi positions
curl -s -G \
  -H "AccessKey: ${user_config.DEBANK_API_KEY}" \
  --data-urlencode "id=$WALLET_ADDR" \
  "https://pro-openapi.debank.com/v1/user/all_complex_protocol_list"
```

**Fiat-value filter:** Discard any token where `price < 0.01` — these are excluded from all matching, display, and reporting.

**Rate limiting:** Add a 0.3s delay between wallet requests to avoid 429 errors.

### Step 6 — Match regular assets

Matching must be **chain-aware**. DeBank's `all_token_list` returns a `chain` field per
token (e.g. `"eth"`, `"arb"`, `"bsc"`). TRES balances are tied to a specific platform
via the wallet's `platforms` array or the balance's context. Always prefer a per-chain
match before falling back to cross-chain aggregation.

**Chain ID mapping** (DeBank `chain` → TRES platform):

| DeBank `chain` | TRES platform |
|---|---|
| `eth` | ETHEREUM |
| `arb` | ARBITRUM |
| `op` | OPTIMISM |
| `matic` | POLYGON |
| `base` | BASE |
| `bsc` | BNB (Binance) |
| `avax` | AVALANCHE |
| `ftm` | FANTOM |
| `xdai` | GNOSIS |
| `era` | ZKSYNC |
| `celo` | CELO |
| `linea` | LINEA |
| `scrl` | SCROLL |
| `mnt` | MOONBEAM |

**Matching order (most specific first):**

1. **Contract + chain match (best):** `asset.contract.identifier` (lowercase) vs DeBank
   token `id` (lowercase), on the same chain. This is the most precise match.
2. **Symbol + chain match:** For native tokens (no contract), match by `asset.symbol`
   (case-insensitive) AND DeBank `chain` matching the TRES platform for that balance row.
   This correctly handles the common case where a wallet holds ETH on both Ethereum and
   Arbitrum — each TRES balance row matches its corresponding DeBank per-chain entry.
3. **Symbol-only match (last resort):** If a TRES native token balance cannot be matched
   to any specific DeBank chain entry, fall back to symbol-only matching. This handles
   edge cases where TRES or DeBank uses a different chain label.

### Step 7 — Match DeFi position underlying tokens

This is a critical step that compares DeFi position underlying tokens between TRES and DeBank.

#### 7a. Filter out position NFT rows

Remove position NFT tokens from the regular comparison (e.g. `UNI-V3-POS`, `RCL`, `SAB-LOCKUP`, `SLP`, `STEER`, `UNI-V4-POS`). These are replaced by the underlying token rows from positions.

#### 7b. Process TRES positions

From `getStatelessWalletsPositions` results, for each position:
1. Aggregate `children` by symbol — a position may have multiple entries for the same token (e.g. supply + unclaimed rewards in QuickSwap or Uniswap V4), so sum the amounts
2. Use `displayName` to identify the protocol and token composition

```python
# Example: aggregate children for a position
def aggregate_children(children):
    agg = {}
    for c in children:
        sym = c['symbol']
        amt = float(c['amount']) if isinstance(c['amount'], str) else c['amount']
        if sym not in agg:
            agg[sym] = {'amount': 0, 'assetIdentifier': c.get('assetIdentifier', '')}
        agg[sym]['amount'] += amt
    return agg
```

#### 7c. Process DeBank positions

From `all_complex_protocol_list`, for each protocol's `portfolio_item_list`:
1. Extract `asset_token_list` for supply tokens and `reward_token_list` for rewards
2. Use protocol `name` and item `name` (e.g. "Lending", "Liquidity Pool") as the position label

#### 7d. Compare position tokens

Match DeBank protocol positions to TRES positions by:
1. Protocol name match (case-insensitive, first word)
2. Token symbol overlap between children

For each matched position token:
- **If TRES data exists:** Compare amounts, compute delta %, assign match/minor/major status
- **If no TRES data:** Assign `position` status (purple badge)

### Step 8 — Build and render the report

Create **two outputs**:
1. **Interactive HTML file** — Dark-themed, with filter buttons, collapsible wallet cards, dedicated DeFi Positions section per wallet
2. **PDF report** — Landscape A4, all wallet tables expanded, using reportlab

Save both to the outputs directory.

---

## Report Layout — CRITICAL

### DeFi Positions must be visually separated

Each wallet card in the report MUST have **two distinct sections**:

1. **DeFi Positions section** (top, purple-themed) — A dedicated box with purple border and dark purple background (`#1a1033` bg, `#7c3aed` border) showing all position-related rows. This section appears BEFORE the regular token table.

2. **Regular tokens table** (below) — Standard token balance comparison rows.

### Position asset indicator

Every position asset row MUST have a **purple dot indicator** (CSS circle, 8px, `#a855f7`) next to the asset name. This ensures positions are instantly recognizable:

```html
<span style="display:inline-block;width:8px;height:8px;background:#a855f7;border-radius:50%;margin-right:6px;vertical-align:middle;"></span>
```

> **Do NOT use emojis or inline SVGs** — they may not render in all viewers. Use pure CSS shapes only.

### Position rows show dual badges

Position rows that have a TRES match show TWO badges:
- A `POSITION` badge (purple)
- A match-status badge (`MATCH`/`MINOR`/`MAJOR`)

### Auto-expand wallets with positions

Wallet cards that contain DeFi positions should be auto-expanded (`<details open>`) so positions are immediately visible.

---

## Number Formatting Rules

### Token amounts
- Max **3 decimal places** for all amounts
- Amounts ≥ 1,000: use comma separator with 3 decimals (e.g., `846,492.356`)
- Amounts < 1,000: use 3 decimals (e.g., `0.386`)
- Very small amounts (< 0.000001): use scientific notation (e.g., `3.54e-07`)
- Null/missing: show em dash `—`

```javascript
function formatAmount(n) {
  if (n === null || n === undefined) return '\u2014';
  if (Math.abs(n) < 0.000001) return n.toExponential(2);
  if (Math.abs(n) >= 1000) return n.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 3});
  return n.toFixed(3);
}
```

### Fiat values
- Shown in **parentheses** next to every token amount: `846,492.356 ($17,562.21)`
- Shown in **parentheses** next to every delta %: `5.33% ($81.21)`
- Format: `($X,XXX.XX)` — always 2 decimal places, comma-separated thousands
- Null/missing: omit entirely (no empty parentheses)

### Fiat value computation — CRITICAL

**Use a single price source** (DeBank's token price) to compute fiat values for **both** the TRES and DeBank columns. This ensures:
- When amounts match, the fiat delta is $0 (not inflated by pricing source differences)
- The fiat delta next to delta % represents the actual USD value of the amount discrepancy

```python
# For regular tokens:
price = debank_token['price']  # single source
tres_fiat = tres_amount * price
debank_fiat = debank_amount * price
delta_fiat = abs(tres_amount - debank_amount) * price

# For position tokens — same principle:
price = debank_asset_token['price']
tres_fiat = tres_aggregated_amount * price
debank_fiat = debank_amount * price
delta_fiat = abs(tres_aggregated_amount - debank_amount) * price
```

**Do NOT** use TRES `fiatValue` for the TRES column and DeBank price for the DeBank column — this creates misleading fiat deltas when TRES and DeBank use different token prices.

---

## Native Token Matching (Multi-Chain Wallets)

Native tokens (ETH, BNB, etc.) often appear on multiple chains in TRES for a single
wallet (e.g., ETH on Ethereum + ETH on Arbitrum). DeBank's `all_token_list` returns
**separate per-chain entries** with a `chain` field — it does NOT aggregate them.

**Rule: match per-chain first, aggregate only as a last resort.**

1. **Per-chain match (default):** For each TRES native token balance, use the balance's
   platform context to find the corresponding DeBank entry by symbol + chain. For example,
   a wallet with 0.00956 ETH on Ethereum and 0.001168 ETH on Arbitrum should produce two
   separate comparison rows — one matched to DeBank's `chain: "eth"` entry and one to
   `chain: "arb"`.

2. **Aggregation fallback (rare):** Only aggregate TRES balances across chains when
   DeBank returns fewer entries than TRES for the same symbol. This can happen if DeBank
   merges certain bridged token balances. When aggregating, add a note like
   `"Aggregated: ETH (eth) + ETH (arb)"`.

**Why this matters:** Blindly aggregating before comparing creates false discrepancies.
If Ethereum ETH matches perfectly but Arbitrum ETH has a gap, aggregation masks the
Ethereum match and produces a single misleading delta. Per-chain matching preserves
granularity and makes it easy to identify exactly which chain is out of sync.

---

## Status Badges

| Badge | Color | Hex | Meaning |
|---|---|---|---|
| **Match** | Green | `#22c55e` | Delta < 1% |
| **Minor** | Orange | `#f59e0b` | Delta 1–10% |
| **Major** | Red | `#ef4444` | Delta > 10% |
| **Missing** | Grey | `#6b7280` | Asset in TRES but not found in DeBank |
| **Untracked** | Blue | `#3b82f6` | Asset in DeBank but not tracked in TRES |
| **Position** | Purple | `#a855f7` | DeFi position token (with or without TRES data) |

---

## Report Sections

The rendered report (both HTML and PDF) includes:

1. **Summary cards** — Wallets checked, assets compared, matched, minor, major, missing, untracked, positions, and match rate %
2. **Filter bar** (HTML only) — Buttons to filter by status: All, Match, Minor, Major, Missing, Untracked, Position
3. **Per-wallet card** containing:
   - **DeFi Positions box** (purple-themed, at top) — Position assets with purple dot indicator, protocol label, dual status badges
   - **Regular tokens table** — Each asset with symbol, chain, TRES amount (+ fiat), DeBank amount (+ fiat), delta % (+ fiat delta), status badge
4. **Skipped wallets** — List of wallets not validated and the reason why
5. **Notes & Caveats** — Sync lag, DeFi positions explanation, native token aggregation, price filter, missing/untracked explanations

---

## Important Caveats

- **Sync lag:** TRES balances reflect the last sync time. Recent on-chain activity may show as a discrepancy.
- **DeFi positions:** Underlying tokens from LP, staking, and lending positions are shown as individual rows in a dedicated purple section. Both TRES and DeBank amounts are compared where TRES position data is available. Active LP positions will naturally show some discrepancy because TRES and DeBank snapshot at different times.
- **Native token matching:** ETH, BNB, etc. are matched per-chain first (using DeBank's `chain` field mapped to TRES platforms). Multi-chain balances are only aggregated as a fallback when DeBank returns fewer entries than TRES for the same symbol.
- **Multi-chain coverage:** DeBank `all_token_list` covers all chains; tokens on chains not configured in TRES appear as "Untracked."
- **Price filter:** Tokens with `price < $0.01` (zero-price, null, or micro-cap) are excluded from all reports.
- **Missing in DeBank:** Typically spam/airdrop tokens (HEX, ASCZBR, etc.) that DeBank filters out.
- **Untracked in TRES:** Tokens on chains not configured in TRES, or small dust amounts.

---

## Error Handling

| Situation | Response |
|---|---|
| DeBank `401` error | Display "Invalid API key" in artifact |
| DeBank `429` error | Display "Rate limited — reload in 60s" |
| Empty token list for non-empty wallet | Flag wallet as suspicious |
| Non-EVM wallet | Skip and list in "Skipped wallets" section |
| `internalAccount` positions timeout | Use `getStatelessWalletsPositions` per wallet/platform/application instead |
| `getStatelessWalletsPositions` returns empty | Ensure `application` parameter is provided; without it the query returns empty |
| Position ID not extractable | Skip that position (don't crash) |
| `amount` field is string not number | Always cast with `float()` before arithmetic |

---

## Next Steps (after report renders)

- **Re-run** — Rebuild the report with fresh data at any time
- **Drill down** — For any Major discrepancy, inspect the specific asset across platforms in TRES to identify which chain is out of sync
- **Position discrepancies** — Minor discrepancies on active LP positions are expected due to different snapshot times between TRES and DeBank
