---
name: tres-upload-tx-header-validation
description: "The exact column header names required by the TRES Finance bulk transaction CSV upload. Use whenever building, fixing, or validating the header row of a TRES manual transaction or sub-transaction upload CSV — especially after an upload fails with \"Missing required column(s): ...\". Trigger phrases include: 'fix my CSV headers', 'bulk transaction upload failed', 'missing required columns', 'validate TRES upload CSV', 'transaction CSV template headers'. This skill is ONLY about the header naming convention; it does not cover row values or upload workflow. Do NOT trigger for contacts import CSV (use tres-import-contacts), wallet upload CSV (use tres-wallets-upload), or general CSV parsing unrelated to bulk TX upload headers."
---

# TRES CSV header naming convention

TRES validates the CSV **header row against human-readable display names** (with spaces and title case), NOT snake_case keys. Using the wrong names fails the upload with:

```
Missing required column(s): Year, Month, Day, Time, Organizational Wallet, Participating Wallet, Network, Direction, Financial Action, Asset Identifier, Amount, Fiat Currency, Transaction Hash, Transfer ID, Function Name, Method ID
```

## The required header row (exact, in order)

```
Year,Month,Day,Time,Organizational Wallet,Participating Wallet,Network,Direction,Financial Action,Asset Identifier,Amount,Fiat Value,Fiat Currency,Transaction Hash,Transfer ID,Function Name,Method ID
```

## Rules

- Use these names **verbatim** — exact spelling, spacing, and title case. They are the display names, not field keys.
- Keep the **order** above (columns A→Q).
- `Fiat Value` (column L) is the one optional column — it does not appear in the "missing required column(s)" error, but include it in the header so the template stays aligned; its cells may be left blank.
- All other 16 columns are required in the header row even if a given cell is empty.

## Common mistake this prevents

Writing programmatic/snake_case headers like `year,month,day,time,wallet_address,third_party,network,direction,type,asset_identifier,amount,fiat_value,fiat_currency,hash,transfer_id,function_name,method_id`. These are rejected — TRES wants the display names above (e.g. `Organizational Wallet` not `wallet_address`, `Participating Wallet` not `third_party`, `Financial Action` not `type`, `Transaction Hash` not `hash`).
