---
name: tres-tx-story
description: >
  Analyze a blockchain transaction by its hash using TRES Finance MCP and generate
  a visual flow diagram showing all asset movements, followed by a plain-language
  explanation of what happened. Use this skill whenever the user provides a
  transaction hash and asks to "analyze", "explain", "visualize", "diagram",
  "show me what happened in", or "tell the story of" a transaction. Also trigger
  when the user pastes a tx hash (long hex string starting with 0x) and asks
  anything about it. Always use this skill for transaction hash analysis — do not
  attempt to answer from memory alone.
---

# TRES Transaction Story

Fetch a transaction by hash from TRES Finance, render a flow diagram of all asset
movements, and explain in plain English what happened.

## MCP Server
All calls use the `TRES Finance MCP` server (URL: `https://ai.tres.finance/mcp`).

---

## Step 1 — Authenticate
Call `get_viewer` (no arguments) to verify the session.

---

## Step 2 — Fetch the Transaction

Query the transaction using its hash as the `identifier`:

```graphql
query GetTransactionByHash($hash: String!, $currency: String) {
  transaction(identifier: $hash, currency: $currency, limit: 1) {
    results {
      id
      identifier
      platform
      timestamp
      success
      decodedFunctionName
      methodId
      fromAddress { identifier displayName isInternal customAccountName }
      toAddress   { identifier displayName isInternal customAccountName }
      contract    { identifier contractName protocols applications }
      classification { activity action functionName }
      ledgerSummary
      applications
      protocols
      internalAccounts { id name }
      children {
        id
        amount
        balanceFactor
        platform
        type
        fiatValue
        nonTaxableType
        isInternalTransfer
        financialActionGroup
        belongsTo { id name identifier }
        sender    { identifier displayName isInternal customAccountName }
        recipient { identifier displayName isInternal customAccountName }
        asset {
          identifier
          symbol: key
          assetClass { id symbol verificationStatus }
        }
      }
    }
  }
}
```

Variables: `{ "hash": "<user_provided_hash>", "currency": "usd" }`

> **Fallback**: If `identifier` returns 0 results, retry with `identifier_Contains`
> using the last 20 characters of the hash. Hashes on some chains may be stored
> without the `0x` prefix — strip it and retry if still empty.

---

## Step 3 — Parse the Data

From the result, extract:

| Field | Purpose |
|---|---|
| `identifier` | The tx hash |
| `platform` | Blockchain (ETHEREUM, SOLANA, etc.) |
| `timestamp` | Date/time |
| `success` | Did it succeed? |
| `decodedFunctionName` | What smart-contract function was called |
| `fromAddress` / `toAddress` | Top-level sender → receiver |
| `contract.contractName` | Smart contract involved (if any) |
| `classification.activity` + `.action` | TRES classification label |
| `children[]` | Each sub-transaction (individual token movement) |

For each child sub-transaction, extract:
- `asset.assetClass.symbol` — the token symbol (e.g. ETH, USDC)
- `amount` — quantity moved
- `fiatValue` — USD equivalent
- `balanceFactor` — `1` = inflow, `-1` = outflow
- `belongsTo.name` — which internal wallet this belongs to
- `sender.identifier` / `recipient.identifier` — counterparties
- `type` — GAS, TOKEN_TRANSFER, etc.

---

## Step 4 — Render the Diagram

Use the `show_widget` tool (Visualizer) to render an HTML widget containing an inline SVG diagram.

---

### PRE-RENDER CHECKLIST — do this before writing a single SVG element

**A. Prepare all label strings first**

For every arrow label (token amount + symbol), apply these formatting rules:
1. Format the amount:
   - amount ≥ 1,000,000 → `"1.2M"` style (1 decimal)
   - amount ≥ 1,000 → `"264K"` or `"12,233"` (comma-separated integer)
   - amount ≥ 1 → round to 2 decimal places max
   - amount < 1 → keep up to 4 significant figures (e.g. `"0.033"`)
2. Truncate the symbol:
   - symbol ≤ 6 chars → use as-is (ETH, USDC, DAI, CRV)
   - symbol 7–10 chars → use as-is only if the full label fits (see step 3)
   - symbol > 10 chars OR contains `+` OR is a compound LP token → replace with `"LP tokens"`
3. Measure the full label: `label = amount + " " + symbol`. Count characters. Multiply by 7. That's the pixel width.
4. The available space for a label = the arrow's x-span minus 20px safety margin.
   - Left gap (wallet→contract): x goes from 136 to 248 → span = 112px → max label = 13 chars
   - Right gap (contract→wallet): x goes from 408 to 504 → span = 96px → max label = 11 chars
5. If `label_px_width > available_space`, shorten further: abbreviate amount to 1 sig fig, or use symbol-only if still too wide.

**B. Count the arrows and calculate SVG height**

- Count non-gas arrows (outflows + inflows). Call this `N`.
- Each arrow row occupies 34px of vertical space.
- Base node centre Y = 50 + (N × 34) / 2 (so arrows fan symmetrically around the node centre).
- Gas arrow hangs 60px below the bottom of the left wallet circle.
- SVG height = node_centre_y + node_radius + 80 (gas arrow + label + padding).
- Minimum SVG height = 230px.

**C. Lay out arrow Y positions**

- Space arrows evenly, 34px apart, centred on `node_centre_y`.
- First arrow y = node_centre_y - ((N-1) × 34) / 2
- Each subsequent arrow y += 34
- Outflow arrows (wallet → contract) use left half of diagram.
- Inflow arrows (contract → wallet) use right half.
- If there is exactly 1 inflow and multiple outflows, centre the inflow arrow at `node_centre_y`.

---

### Fixed node positions (do not change these)

```
ViewBox width: 640
Left wallet circle:    cx=90,  cy=node_centre_y, r=46
Contract rect:         x=248,  y=node_centre_y-55, width=160, height=110, rx=12
Right wallet circle:   cx=550, cy=node_centre_y, r=46

Arrow x coordinates:
  Outflow (left→centre): x1=136, x2=246   midpoint_x=191
  Inflow (centre→right): x1=410, x2=504   midpoint_x=457
  Gas (downward):        x1=x2=90, y1=node_centre_y+46
```

These x values are derived from the node edges and must not be adjusted. They guarantee labels always fall in the clear gap between nodes.

---

### Arrow label placement rules (no exceptions)

```
Label x = midpoint_x of arrow (191 for outflows, 457 for inflows)
Label y = arrow_y - 12
text-anchor = "middle"
font-size = 10.5px
font-weight = 500
```

**Never** place a label at the same y as another label. If two arrows are only 34px apart, their labels (at y-12) are 34px apart — that is sufficient. Never stack two labels at the same y coordinate.

**Never** use `text-anchor="start"` for labels that fall near node edges — always `"middle"` anchored at the midpoint x.

---

### Node internal text rules

Wallet circle (r=46, so usable text band = ±36px from centre):
```
Line 1 (name):    y = cy - 8,  font-size=11, font-weight=500
Line 2 (address): y = cy + 7,  font-size=9.5, font-family=monospace
Line 3 (role):    y = cy + 21, font-size=9
```
Three lines maximum. Each line must fit within the circle width (chord at that y ≈ 80px = ~11 chars at 9px, ~9 chars at 10px). Truncate wallet names longer than 10 chars.

Contract rect (width=160, height=110):
```
Line 1 (name):     y = rect_top + 28, font-size=11, font-weight=500
Line 2 (subname):  y = rect_top + 44, font-size=10
Line 3 (function): y = rect_top + 60, font-size=9.5
Line 4 (address):  y = rect_top + 76, font-size=9, font-family=monospace
Line 5 (type):     y = rect_top + 92, font-size=9
```
Maximum 5 lines. Each line centred at x=328. Lines must fit within 152px (160 - 8px padding each side) → max ~21 chars at 9px. Truncate anything longer.

---

### Gas arrow rules

- Always vertical, pointing down from the bottom of the left wallet circle.
- x1 = x2 = 90 (same as wallet cx)
- y1 = node_centre_y + 46 + 2 (2px gap below circle edge)
- y2 = y1 + 55
- Label: placed to the RIGHT of the line — `x=98, y=(y1+y2)/2, text-anchor="start"`
- Below the arrow tip, add a small pill: rect with label "network fee", centred at x=90.
- Gas label max length: `"0.033 ETH gas"` = 13 chars. Always fits.

---

### Color coding

| Element | Fill | Stroke/Color |
|---|---|---|
| Internal wallet (sender) | `#EAF3DE` | `#639922` |
| Internal wallet (receiver) | `#dcfce7` | `#16a34a` |
| Smart contract | `#EEEDFE` | `#7F77DD` |
| Outflow arrow | — | `#dc2626` |
| Inflow arrow | — | `#16a34a` |
| Gas arrow | — | `#ea580c` |
| Outflow label text | — | `#dc2626` |
| Inflow label text | — | `#16a34a` |
| Gas label text | — | `#ea580c` |

---

### Animation

```css
@keyframes flowDash { to { stroke-dashoffset: -40; } }
@keyframes fadeUp   { from { opacity:0; transform:translateY(14px); } to { opacity:1; transform:translateY(0); } }

Outflow arrows: stroke-dasharray:8 5; animation: flowDash 1.1s linear infinite;
Inflow arrows:  stroke-dasharray:8 5; animation: flowDash 1.1s linear infinite;
Gas arrow:      stroke-dasharray:4 4; animation: flowDash 1.7s linear infinite;
Cards/sections: opacity:0; animation: fadeUp .5s ease forwards; (staggered delays)
```

---

### Header

Single line of plain text, no pill badges:
```
[hash-pill: 0xABCD...1234]   Chain · Date · function() · ✓ success
```
Hash pill style: monospace, 11px, bg-secondary, border, border-radius 6px, padding 4px 10px.
Everything else: 12px, color-text-secondary. Success mark: color-text-success, font-weight 500.

---

### Stat cards (below diagram)

3-column grid, one card per: total sent (red), total received (green), gas paid (orange).
Format values as: `−$272,910` / `264K LP` / `0.127 ETH`. Keep under 12 chars.
Sublabel: 11px, muted, shows token breakdown if multiple assets.

---

### Footer route card

`[function() badge]  via ContractName  · [protocol tag] [protocol tag]  [Explain X ↗ button]`
Function badge: yellow bg `#FEF9C3`, text `#854d0e`, border-radius 6px.
Protocol tags: bg-secondary, border, border-radius 4px, 11px.
Button: calls `sendPrompt('How does [ContractName/protocol] work?')`

---

## Step 5 — Plain-Language Explanation

After the diagram, write a short explanation (3–6 sentences) in simple, non-technical
language. Cover:

1. **What happened**: The core action (swap, transfer, deposit, stake, etc.)
2. **Who was involved**: Wallets and contracts in plain terms
3. **What moved**: Which assets changed hands and in what direction
4. **Net result**: What the org's wallets ended up with / paid out

**Tone**: Imagine explaining to someone who understands crypto but not accounting.
Avoid jargon like "balanceFactor", "sub-transaction", "FIFO". Say "sent", "received",
"paid as gas", "swapped X for Y", etc.

**Example**:
> This was a token swap on Uniswap. Your wallet (Main Treasury) sent 1,000 USDC to
> the Uniswap V3 router contract, which in turn sent back 0.412 ETH (worth ~$1,020).
> You also paid 0.003 ETH (~$7.40) in gas fees to the Ethereum network.
> Net result: you traded stablecoins for ETH at roughly $2,476 per ETH.

---

## Error Handling

| Situation | Action |
|---|---|
| Transaction not found | Tell user the hash wasn't found in TRES. Ask if they want to check the hash or try a different one. |
| No children (empty sub-txs) | Show header only; note "No asset movements recorded — the tx may be a failed or contract-only interaction." |
| Missing fiat values | Show amounts without USD; note "USD value unavailable for some assets." |
| Auth failure | Tell user to check TRES connection and re-authenticate. |
