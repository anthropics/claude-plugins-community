---
name: tres-invoice-bill-matching
description: >
  Match TRES ledger transactions to ERP invoices/bills (AP/AR) and optionally sync them to the connected ERP
  (Xero, QuickBooks Online, NetSuite). Trigger this skill whenever the user wants to match, link, close,
  reconcile, or sync an invoice or bill against a blockchain transaction — even if they don't say "skill" or
  use those exact words. Trigger phrases include: "match this invoice to a transaction", "match a bill to tx",
  "close invoice INV-123", "close bill 9988", "link this tx to a bill", "pay this invoice from this transaction",
  "set up this tx as AP", "set up this tx as AR", "sync this transaction as AP/AR", "match AP/AR", "find the
  invoice/bill for this hash", "what bill does this tx pay". Trigger ONLY for explicit AP/AR matching/closing
  intent — do NOT trigger for general transaction explanations (use tres-tx-story), for ingesting an explorer
  link into the ledger (use tres-explorer-tx-to-ledger), or for ERP connection setup itself (use tres-settings-management).
---

# TRES — Invoice/Bill Matching & ERP Sync

End-to-end workflow that lets the user close an open ERP invoice or bill against a blockchain transaction in
the TRES ledger, then optionally push the matched entry to the connected ERP.

The flow is the same regardless of which side the user starts from (a transaction hash or an invoice/bill ID).
The skill walks through seven conversational steps (verify ERP → identify input → fetch & suggest → user picks
→ configure payment account & fiat → confirm & apply → loop). Stay terse — show numbered options, capture the
user's pick, move on. Never run a mutation without explicit "yes" from the user.

---

## Ground rules

1. **Identify the org first.** Begin with `get_viewer` and tell the user "You're connected to **{orgName}**."
   This makes mistakes recoverable when someone has the wrong token.
2. **Read before write.** Always fetch the current state of the transaction, invoice/bill, and payment account
   before showing a change summary. Surprises are worse than slow.
3. **Mutations require explicit approval.** Show a summary table (Transaction · Invoice/Bill · Payment Account ·
   Fiat alignment · Sync) and ask "Apply these changes?" before any mutation. Only proceed on a clear yes.
4. **Use schema introspection when in doubt.** Field names, enum values, and argument shapes can drift. If a
   query/mutation errors with "unknown field" or "invalid enum", call `introspect(<TypeName>)` or
   `build_query(<operationName>)` and adjust — don't guess. Operations specifically called out as "verify at
   runtime" below are the ones most likely to need this.
5. **The skill is a loop.** After a successful match, ask "Match another?" and restart from Step 2. Don't
   re-check the ERP — that only happens once per session.

---

## Step 1 — Verify ERP is connected

Run:
```graphql
query { integration(first: 50) { results { id integratedApp isErp connectionStatus companyName } } }
```

Filter the results where `isErp == true` and `connectionStatus == "ACTIVE"`. The supported ERPs you should
recognize are **Xero**, **QuickBooks Online (QBO)**, and **NetSuite** — `integratedApp` values are `XERO`,
`QUICKBOOKS`, and `NETSUITE`. (If you encounter unknown values, `introspect("IntegrationsQueryNode")` will
confirm the enum.) Ignore rows where `integratedApp` is empty — the API occasionally returns a null row.

- **No connected ERP:** Tell the user they need to connect one before matching can happen, point them at
  `https://app.tres.finance/settings/integrations`, and stop.
- **One connected ERP:** Use it implicitly and just mention "Matching against **{companyName}** ({integratedApp})."
- **Multiple connected ERPs:** Ask which one to use — different ERPs have separate invoice/bill stores.

Cache the chosen ERP's `id`, `integratedApp`, and `companyName` for later steps and the loop.

---

## Step 2 — Identify what the user has

Ask whether they have:
- a **transaction hash** (e.g. `0x…`) — best case, pins the match immediately,
- an **invoice/bill ID or number** (numeric internal ID, or the human-facing `invoiceNumber`/`billNumber`),
- or **both**.

If they have neither, require at least one. If they're not sure whether their identifier is an invoice or a
bill, accept it and try both lookups in Step 3.

Also accept loose forms — "INV-123", "Bill 9988", "the bill for Acme last week". The `freeText` filter on
`erpInvoices` / `erpBills` handles these.

**Before moving on, always ask for the transaction date (or an approximate date range) if they haven't given
a tx hash.** Ledger volume is high — date is the single most useful filter for narrowing candidates. Also
offer: *"If you happen to have the tx hash, paste it now — it pins the match exactly."* Date matters both
directions (tx→bill and bill→tx).

---

## Step 3 — Fetch the known object and produce ranked match suggestions

There are two branches. Pick by what the user provided. If they provided both a tx hash *and* an invoice/bill
ID, skip ahead to Step 5 (match is already determined).

### Branch A — User has a transaction hash

1. Fetch the transaction with its sub-transactions:
   ```graphql
   query GetTx($hash: String!) {
     transaction(identifier: $hash, currency: "usd", limit: 1) {
       results {
         id identifier timestamp platform
         children {
           id amount balanceFactor isInternalTransfer
           fiatValue
           sender    { identifier displayName isInternal }
           recipient { identifier displayName isInternal }
           asset { symbol identifier }
         }
       }
     }
   }
   ```
2. Pick the **relevant sub-transaction**. Skip gas, skip internal transfers, prefer the one with the user's
   wallet on one side and an external counterparty on the other. Determine direction:
   - `balanceFactor` negative → outflow → look for a **bill** to close.
   - `balanceFactor` positive → inflow → look for an **invoice** to close.
   If multiple sub-txs qualify (e.g., a swap with multiple legs), present them and let the user pick one.
3. **For invoices (inflow), try backend match suggestions first** — they are pre-computed and ranked:
   ```graphql
   query Suggest($subTxIds: [String]!) {
     subTransactionToInvoiceMatchSuggestions(
       subTransactionId_In: $subTxIds, minScore: 0.3, ordering: "-score", first: 10
     ) {
       results {
         id score confidenceTier
         scoreBreakdown { txHashMatch primaryMatchFactors }
         invoice {
           id invoiceId invoiceNumber customerName origAmount balance dueDate billingStatus
           integration { integratedApp companyName }
         }
       }
     }
   }
   ```
   Important: this endpoint is **invoice-only**. For **bills (outflow), skip straight to the fallback below**
   — there is no backend bill-suggestion query exposed in the schema.
4. **Fallback (zero invoice suggestions, or always for bills):** query `erpInvoices` (inflow) or `erpBills`
   (outflow), filtered by:
   - amount window: `±20%` of the sub-tx fiat value,
   - date window: `dateCreated_Range = [tx.timestamp − 60d, tx.timestamp]` — bills/invoices are issued at or
     *before* the payment, never after. Don't bother with future-dated invoices/bills.
   - contact: if the user has named a vendor/customer, pass that as `freeText`. Do NOT try to match the
     on-chain recipient address to an ERP contact — ERP contact identifiers (from QBO/Xero/NetSuite) are
     internal IDs, never wallet addresses. Some contact labels *happen to resemble* the vendor name in text,
     but the schema has no "resembles" filter, so rely on `freeText` over `vendor`/`customer` fields.
   Rank the fallback set client-side by: amount proximity → date proximity (prefer the most recent
   bill/invoice before the tx) → name hits in `freeText` output.
5. Present the top ≤5 as a numbered list (never more — too many choices is worse than too few). For each row
   show: confidence tier, $ amount, customer/vendor name, `invoiceNumber`/`billNumber`, due date, and the
   `primaryMatchFactors` (e.g. `amount_exact`, `contact_match`). Best-fit first.

### Branch B — User has an invoice/bill ID or number

1. Resolve the entity. Try `erpInvoices` first, then `erpBills` if it's not an invoice (or vice versa if the
   user said "bill"). For **invoices**, include the embedded suggestions:
   ```graphql
   query GetInvoice($id: Float, $text: String) {
     erpInvoices(id: $id, freeText: $text, first: 1) {
       results {
         id invoiceNumber customerName origAmount balance dateCreated dueDate billingStatus
         integration { integratedApp companyName }
         suggestedSubTransactionMatches {
           id score confidenceTier
           subTransaction {
             id amount fiatValue
             asset { symbol identifier }
             tx { identifier timestamp platform }
           }
         }
       }
     }
   }
   ```
   For **bills**, query `erpBills` — note that bills do **not** expose `suggestedSubTransactionMatches`, so
   just fetch the bill metadata (`id billNumber vendorName vendorId origAmount balance dateCreated dueDate
   billingStatus integration { integratedApp companyName }`) and go straight to the fallback step. If `id`
   lookup returns nothing, retry with `freeText: $userInput`.
2. For invoices, use the embedded `suggestedSubTransactionMatches` as the ranked list.
3. **Fallback (zero invoice suggestions, or always for bills):**
   - First, **ask the user for an approximate date of payment** (and remind them: "if you have the tx hash,
     that's fastest"). Payments happen on or after the bill/invoice date, usually within days — not before.
     Default to a window of `[dateCreated, dateCreated + 60 days]` if they can't be specific.
   - Query `transaction` with **server-side filters** so we don't pull the entire ledger. Use:
     - `platform: <configuredNetwork or user's network>` (e.g. `"ethereum"`),
     - `timestamp_Gte` / `timestamp_Lte` → the user-supplied date window,
     - `children_Asset_Identifier_In: [<assetIdentifier>]` → the bill's `configuredAsset.identifier` (e.g. the
       USDC contract), or the invoice's expected asset,
     - `children_FiatValue_Between: "<low>,<high>"` → fiat window around `origAmount` (e.g. `±20%`). This is
       a **string** of two comma-separated numbers. Example: `"0.4,0.6"` for a $0.50 bill.
     - Optionally `children_BalanceFactor: -1` (outflow, for bills) or `1` (inflow, for invoices).
     - Use `children_Amount_Between` as an additional filter only when the fiat price can't be trusted
       (pre-priced historical assets, etc.).
   - If the resulting set is still large, ask the user for a tighter date or an amount refinement before
     presenting.
4. Present **up to 5** candidate transactions as a numbered list — show for each:
   **tx hash (truncated `0xabcd…1234`), sender → recipient addresses (same shortened form), token amount +
   symbol, fiat value, and timestamp.** The tx hash is the user-facing identifier they recognize; the raw
   addresses and token amounts disambiguate when fiat alone is too ambiguous (many txs cluster near the same
   amount). **Never show internal IDs like `subTxId` to the user — they're meaningless to them.** Hold the
   `subTxId` internally for the mutation; reference the tx by its hash in all user-visible output.
   If no good matches, say so and ask for a tx hash — don't guess-dump a big list.

---

## Step 4 — User picks a match (or asks for more)

Prompt: *"Pick a number, or type `more` to widen the search (give me a contact name, date, or amount to focus
on)."*

- On a number: capture the chosen `(subTxId, invoiceOrBillId, entityType)` and continue to Step 5.
- On `more`: re-query with looser windows or with the user's added hints (contact filter, expanded date range,
  amount range), present a fresh list, repeat.
- On "none of these" or similar: stop gracefully — *"OK, no match made. Tell me when you have more info."*

---

## Step 5 — Configure payment account and (optional) fiat alignment

Once a match pair is chosen:

1. **Deposit account (for `matchApAr.depositAccountId`).** This is an **ERP integration account**
   (the GL account in Xero/QBO/NetSuite that the bill will post against — e.g. "Crypto Wallet – ETH",
   "Cash and cash equivalents"). It is NOT a tres internal/wallet account. The schema FK is against
   `schema_integrationaccount`; the value lives on `ErpBill.depositAccount` / `ErpInvoice.depositAccount`
   as `IntegrationAccountQuery { id name type value }`.

   Resolution order:
   1. **Use the pre-set one on the bill/invoice.** When the entity was created in the ERP, the user
      typically already picked a deposit account. Read `erpBills.results[].depositAccount.id` (or
      `erpInvoices.results[].depositAccount.id`). If it's non-null, use that id as `depositAccountId`
      and just mention it in the summary — no prompt.
   2. **Otherwise ask.** Query `integrationAccount(integration: <erpId>, first: 100)` and show the
      user the ASSET-type accounts (cash/wallet/crypto GL accounts) as a numbered list; capture the
      chosen `integrationAccount.id`.
   3. `paymentToInternalAccounts` maps *wallet → asset* on the tres side and is useful for payout
      workflows — it is **not** the source of `depositAccountId` for `matchApAr`. Don't reach for it
      here.

2. **Fiat alignment.** Compare the sub-tx `fiatValue` to the invoice/bill `origAmount`. Three cases:
   - `fiatValue` is **null or 0**: ask *"This transaction has no fiat value set. Align it to ${origAmount}
     so the {bill/invoice} closes fully? (y/n)"* — **no default**, require an explicit yes.
   - `fiatValue` differs from `origAmount`: ask *"Align tx fiat value from $X to $Y so the AP/AR
     closes fully? (y/n)"* — **no default**, require an explicit yes.
   - Values match: skip.
   **Never run `setManualFiatValue` without a clear yes** — even if the user's original request implied
   "close the invoice", the fiat alignment is a separate write and needs its own consent. If they say no,
   the match still proceeds but the entity may stay partially paid.

---

## Step 6 — Confirm and apply

Show this summary table — use **human-readable values only**: tx hash (truncated), deposit account **name**
(never its id), invoice/bill number or customer/vendor name. Internal IDs (`subTxId`, `depositAccountId`,
DB `entityId`) are for the mutation payload, never for the user.

| | |
|---|---|
| Transaction | `0xabcd…1234` · {asset.symbol} {amount} · ${fiatValue} |
| Invoice/Bill | `{invoiceNumber or billNumber}` · {customer/vendor} · ${origAmount} {currency} |
| Payment account | {depositAccount.name} |
| Align fiat | yes → ${origAmount} / no |
| Sync to ERP after match | yes / no |

Ask: *"Apply these changes to **{orgName}**? (yes/no)"* — only proceed on yes. Treat this as approval for
the **match only**. Fiat alignment and ERP sync each need their own explicit yes captured earlier (Step 5
for fiat, the prompt below for sync) — even if the user's opening request said "sync to QBO", still confirm
here, because the request was issued before they saw the actual match details.

Then run mutations in this order, reporting the result of each:

1. **Match (always):**
   ```graphql
   mutation Match($entityType: String!, $matches: [SubTxMatchInput]!) {
     matchApAr(entityType: $entityType, matches: $matches) {
       results { subTxId entityId depositAccountId }
     }
   }
   ```
   Variables:
   - `entityType`: **lowercase** — `"invoice"` or `"bill"`. Uppercase values are rejected with
     `Invalid entity_type`.
   - `matches[].subTxId`: string (e.g. `"4548595830"`).
   - `matches[].entityId`: **integer** — the DB `id` of the invoice/bill (from `erpInvoices.results[].id`
     / `erpBills.results[].id`), NOT the human-facing `invoiceNumber`/`billNumber`. Passing a string
     errors with *"Int cannot represent non-integer value"*; passing a bill number looks up nothing
     and errors with *"One or more Bill IDs not found"*.
   - `matches[].depositAccountId`: **integer** — the integration account id (see Step 5).

2. **Fiat alignment (only if user opted in):**
   ```graphql
   mutation AlignFiat($id: String!, $newFiatValue: String!, $currency: String) {
     setManualFiatValue(id: $id, newFiatValue: $newFiatValue, currency: $currency) { success }
   }
   ```
   Pass the sub-transaction ID as `id`, the target value as a string in `newFiatValue` (e.g. `"123.45"`, the
   invoice/bill `origAmount`), and `currency: "usd"`. If the response returns an error about a "locked
   period", the accounting period containing the tx is closed — surface that to the user; don't try to force.

3. **ERP sync (ask first, every time):** *"Sync this transaction to {erpName} now? (y/n)"* — **never sync
   without an explicit yes at this point**, even if the user's original ask included "and sync to QBO". The
   sync call is visible in the ERP and harder to undo than the match itself, so it gets its own gate. If yes:
   ```graphql
   mutation Sync($txIds: [String]!, $entityType: String!) {
     syncSpecificTransactions(transactionIds: $txIds, entitySourceType: $entityType) { status }
   }
   ```
   `entitySourceType` mirrors `entityType` from the match call.

When reporting results back to the user, refer to the transaction by its **tx hash** (truncated) and the
deposit account by **name** — never by `subTxId` or `depositAccountId`. Those internal IDs are for debugging,
not user output.

If any mutation errors, surface the error message verbatim and offer to retry. The match is the one that
actually links the records — if it fails, the rest is moot.

---

## Step 7 — Loop

Ask: *"Match another transaction or invoice/bill? (y/n)"*

- yes → restart from Step 2 (skip Step 1 — keep the cached ERP from this session).
- no → wrap up: *"Done. Closed {n} item(s) this session."*

---

## Verified TRES MCP operations used

| Purpose | Operation | Type |
|---|---|---|
| Org identity | `get_viewer` | MCP tool |
| Schema discovery | `introspect`, `build_query` | MCP tool |
| Check ERP connections | `integration` (filter `isErp=true`) | query |
| Fetch tx by hash | `transaction(identifier:)` | query |
| Fetch invoices (with embedded suggestions) | `erpInvoices` | query |
| Fetch bills (with embedded suggestions) | `erpBills` | query |
| Pre-computed sub-tx → invoice match suggestions | `subTransactionToInvoiceMatchSuggestions` | query |
| COA-mapped payment accounts | `paymentToInternalAccounts` | query |
| Match sub-tx ↔ invoice/bill | `matchApAr` | mutation |
| Align fiat value | `setManualFiatValue` (verify args at runtime) | mutation |
| Sync transactions to the ERP | `syncSpecificTransactions` | mutation |
| Undo a match (on user request) | `manualUnmatchSubtransactions` | mutation |

---

## Out of scope (politely redirect if asked)

- Bulk matching (many ↔ many) — not yet supported by this skill.
- Sending payments (`sendBillPayment`, `sendInvoicePayment`) — separate workflow.
- Connecting or revoking the ERP itself — use the `tres-settings-management` skill.
- Explaining a transaction in narrative form — use `tres-tx-story`.
- Importing an explorer link into the ledger — use `tres-explorer-tx-to-ledger`.
