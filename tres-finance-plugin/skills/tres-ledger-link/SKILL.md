---
name: tres-ledger-link
description: >
  Build a TRES Finance dashboard ledger URL (Transactions tab) with a precise filter set — date
  range, wallets, assets, tags, status, amount, and more — so it can be shared with a customer or
  reused. Use whenever the user asks for a "ledger link", "dashboard link", "filter URL", or "send
  <customer> a link to <some filtered view>". Scoped to the Transactions tab only (not Accounting,
  Roll Forward, Pivot Tables, Cost Basis, or Trial Balances).
---

# Generate Dashboard Ledger Link

Your job is to produce a working TRES Finance dashboard URL that opens the **Transactions tab of the
ledger** with a precise filter set applied, so the user can share it with a customer (or use it
themselves).

This skill is scoped to the **Transactions tab only**. If the user asks for a link to Accounting,
Roll Forward, Pivot Tables, Cost Basis, or Trial Balances — stop and tell them this skill does not
cover those tabs.

---

## Step 1 — Resolve the org subdomain

The dashboard URL is `https://<org-subdomain>.tres.finance/ledger`.

Resolve `<org-subdomain>` from the MCP `get_viewer` query (use the returned `orgName`). **Do not ask
the user.**

```graphql
query { viewer { orgName } }
```

State the subdomain you used in your final message so the user can correct it in one shot if it is
wrong.

---

## Step 2 — Collect the filters the user wants

Read the filters out of the user's request in plain English (date range, wallets, assets, tags,
status, etc.). If a filter is ambiguous (e.g. "USDC" when the org has multiple USDC variants, or "Q1"
without a year), ask before generating. A wrong value silently produces a broken / empty view.

Only include filters the user explicitly asked for. The dashboard fills in defaults for everything
else — extra params just add noise.

---

## Step 3 — Build the URL

Base path is always:

```
https://<org-subdomain>.tres.finance/ledger
```

No path segment after `/ledger` (that is the Transactions tab).

Append `?` and the query string built from the rules below. URL-encode every value (spaces → `%20`).
Inside a single value, encode commas; between distinct array items, a comma is the literal delimiter.

### 3.1 Date & pagination

| Param      | Format / values | Notes |
|------------|-----------------|-------|
| `fromDate` | `YYYY-MM-DD` | UTC date |
| `toDate`   | `YYYY-MM-DD` | UTC date |
| `dateType` | `Month to date`, `Year to date`, `Last 30 days`, `Last month`, `Before this month`, `Custom date`, `All time`, `Year`, `Quarters` | URL-encode spaces. **Omit** if `Last 30 days` (default). For an arbitrary `fromDate`/`toDate` range, use `Custom date`. |
| `page`     | integer | Omit if `1`. |
| `pageSize` | integer | Omit if `20` (default). |

If `dateType=All%20time`, `fromDate` / `toDate` are ignored — do not include them.

### 3.2 Multi-select array filters (comma-joined IDs)

| Param | What goes in it |
|-------|-----------------|
| `internalAccounts` | numeric database ID of org-owned wallets |
| `tags` | wallet group IDs, or `no-label` for unlabeled |
| `thirdPartyAccounts` | raw address string of an external account (sender/receiver identifier on a sub-transaction — not necessarily a named contact in the system) |
| `customNameLabelTags` | contact group IDs |
| `addresses` | raw unidentified address strings |
| `assetClasses` | asset class enum IDs (e.g. `CRYPTO`, `FIAT`, `NFT`) |
| `assets` | asset IDs |
| `activities` | tag IDs uppercase (e.g. `SPAM`, `STAKING`), or `no-label` |
| `automations` | automation IDs |
| `platforms` | platform names **lowercased** (e.g. `ethereum`, `bitcoin` — NOT the uppercase enum) |
| `actions` | financial action enum names (e.g. `SEND`, `RECEIVE`) |
| `functions` | decoded function names |
| `applications` | application IDs |
| `protocols` | protocol IDs |
| `methodIds` | 4-byte hex method IDs (`0xa9059cbb`) |
| `transactionHash` | tx hash(es) |
| `transactionView` | `readyPending` (default), `onlyReady`, `onlyPending`, `onlyDeleted` |
| `transactionType` | any of `isManual`, `onlyPlug` |
| `filterByBookmark` | bookmark types **lowercased** |
| `missingCounterMatchedTransfers` | `all` (default), `false` (has counter transfer), `true` (no counter transfer) |
| `balanceFactor` | `1` (Inflow), `-1` (Outflow). Typically a single value. |
| `amountAsset` | single asset ID (pair with `amountBetween`) |

If you do not know the exact ID for a multi-select value, query the BFF via the `execute` MCP tool
first to look it up. Do **not** guess.

### 3.3 Range filter

| Param | Format | Notes |
|-------|--------|-------|
| `amountBetween` | `<min>,<max>` | Either side may be empty: `100,500` (range), `100,` (≥100), `,500` (≤500). The single comma is required. |

### 3.4 Boolean filters (include only when `true`)

`showSpam`, `missingFiat`, `failedTransactions`, `nonTaxableType`, `missingCostBasis`,
`internalTransactions`, `ignoreFee`

Example: `?showSpam=true&missingFiat=true`. Never emit `=false` — `false` is the default.

### 3.5 Notes / radio-with-input

| Param | Values |
|-------|--------|
| `commentContains` | `1` = has notes, `-1` = no notes, `0` = show all (omit), or any text string to search note content |

### 3.6 Other singles

| Param | Format |
|-------|--------|
| `savedFilters` | saved-filter ID (single value) |
| `description` | single string |
| `globalSearch` | single string |

---

## Step 4 — Validate before sending

Walk the URL through this checklist. If any rule fails, fix it before handing it over.

1. Path is exactly `/ledger`. No tab suffix, no `?id=...`.
2. `fromDate` / `toDate` paired with `dateType=Custom%20date` (or `dateType` omitted), never with
   `Last%2030%20days` or `All%20time`.
3. No `=false` on any boolean.
4. Multi-select values are **comma-joined**, never repeated keys (`?platforms=ethereum,bsc`, never
   `?platforms=ethereum&platforms=bsc`).
5. `platforms` values are **lowercased** (`ethereum`, not `ETHEREUM`). All other enum IDs match the
   schema (`SPAM`, not `Spam`; `CRYPTO`, not `crypto`).
6. `amountBetween` always has exactly one comma, even when one side is open.
7. If `activities` includes `SPAM`, also set `showSpam=true` so the link is self-contained.
8. If `transactionHash` is set, the dashboard ignores any date filter — warn the user when you also
   see a date in their request.
9. Spaces are URL-encoded (`Custom date` → `Custom%20date`).
10. Only filters the user asked for are included.

---

## Step 5 — Hand it over

Send the URL on its own line so it is easy to copy. Briefly state which filters are encoded (and which
subdomain you used) so the user can sanity-check before forwarding to the customer.

Example handoff:

> Built for org `<subdomain>`: filters are platform=ethereum, activities=SPAM, fromDate/toDate Apr
> 2026 (Custom date), showSpam=true.
>
> https://<subdomain>.tres.finance/ledger?fromDate=2026-04-01&toDate=2026-04-30&dateType=Custom%20date&platforms=ethereum&activities=SPAM&showSpam=true

---

## Worked examples

**Last month's Ethereum SPAM transactions:**

```
https://<subdomain>.tres.finance/ledger?fromDate=2026-04-01&toDate=2026-04-30&dateType=Custom%20date&platforms=ethereum&activities=SPAM&showSpam=true
```

**All-time view of two specific wallets:**

```
https://<subdomain>.tres.finance/ledger?dateType=All%20time&internalAccounts=12345,67890
```

**USD-only large transfers ≥ 50k:**

```
https://<subdomain>.tres.finance/ledger?assetClasses=FIAT&amountBetween=50000,&amountAsset=USD
```

**Failed transactions missing fiat in Q1 2026:**

```
https://<subdomain>.tres.finance/ledger?fromDate=2026-01-01&toDate=2026-03-31&dateType=Custom%20date&failedTransactions=true&missingFiat=true
```

**A specific saved filter:**

```
https://<subdomain>.tres.finance/ledger?savedFilters=12345
```

---

## Rules

- **This skill is for general, ad-hoc filtered views** the user describes in plain English. To pin a
  single just-created transaction so a pending/backdated row shows immediately, set `transactionHash`
  with `dateType=All%20time`.
- **Never hand-craft a ledger URL outside this skill** — use it whenever the user asks for a ledger /
  dashboard / filter link.
- **Never include `=false`** on a boolean filter.
- **Never repeat a key** (`?x=a&x=b`) — comma-join into one value.
- **Never use display names** where the dashboard expects enum IDs.
- **Always validate** against the Step 4 checklist before responding.
- **Always state** the subdomain and filters used in your handoff message.
