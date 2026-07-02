---
name: tres-import-contacts
description: "Import contacts (address book entries) into TRES Finance from a CSV or XLSX file. Use this skill whenever the user wants to import, upload, or bulk-add contacts, address labels, or address book entries into TRES — whether from a file they filled in after using the export-3rd-party-contacts skill, or from any CSV/XLSX that maps addresses to names. Trigger phrases include: 'import contacts', 'upload contacts', 'add contacts from file', 'import address book', 'load contacts into TRES', 'bulk label addresses', 'import the contacts file', 'upload the filled contacts sheet'. Also trigger when the user says something like 'I filled in the contacts file, now import it' or 'here is my contacts spreadsheet, please upload it to TRES'. Do NOT trigger for exporting or extracting unidentified addresses — that's the export-3rd-party-contacts skill. Do NOT trigger for viewing or searching the existing address book."
---

# TRES Finance — Import Contacts from CSV/XLSX

## Goal

Read a user-provided CSV or XLSX file containing address-to-name mappings and import them as contacts into the TRES address book. This is the second half of the contacts workflow: the user previously exported unidentified addresses (via the export skill), filled in names and tags, and now wants to push those labels back into TRES.

## MCP Server

All GraphQL calls use the **user-tres-finance** MCP server (`execute` tool).

## Expected File Format

The file should have these columns (header names are matched case-insensitively):

| Contact Name | Contact Address | Contact Tag |
|---|---|---|
| Binance Hot Wallet | 0xABC... | Exchange |
| Vendor X | 0xDEF... | Vendor |

- **Contact Name** — the label to assign to the address (required for import; rows without a name are skipped)
- **Contact Address** — the blockchain address (required)
- **Contact Tag** — optional tag(s) for the contact. Multiple tags can be separated by commas (e.g. `Exchange, Custodian`)

The column order doesn't matter — the skill matches by header name. The file may contain additional columns (like the "Address details" enrichment columns from the export skill) — those are ignored.

## Workflow

### Step 1 — Authenticate

Call `get_viewer` (no arguments) to confirm the session is active and note the organization name.

### Step 2 — Read and parse the file

The user will provide a CSV or XLSX file. Detect the format from the file extension.

**For XLSX files:**
Use Python with `openpyxl==3.1.5`. If not installed, stop and display:
> "openpyxl is not installed. Please run: `python3 -m venv .venv && .venv/bin/pip install openpyxl==3.1.5`"

- If the workbook has multiple sheets, look for one named "Contacts" (case-insensitive). If not found, use the first sheet.
- Read the header row to find the column indices for "Contact Name", "Contact Address", and "Contact Tag" (match case-insensitively, trim whitespace).
- Read all data rows.
- Filter out trailing empty rows — openpyxl sometimes reads extra `None` rows at the bottom of the sheet. Skip any row where all cells are `None` or empty strings.

**For CSV files:**
Use Python's built-in `csv` module.

- Open the file with `encoding='utf-8-sig'` to handle the BOM (byte-order mark) that Excel adds when saving CSVs. Without this, the first header may appear as `\ufeffContact Name` and won't match.
- Try comma delimiter first. If the header row doesn't contain the expected columns, retry with semicolon delimiter (common in European-locale Excel exports).
- Read the header row to find column indices, same matching logic as above.
- Read all data rows.

### Step 3 — Validate and filter

For each row:

1. **Skip if Contact Name is blank or missing** — the user hasn't identified this address yet, so there's nothing to import.
2. **Skip if Contact Address is blank or missing** — can't label an address that doesn't exist.
3. **Trim whitespace** from name, address, and tag values.
4. **Parse tags**: if Contact Tag contains commas, split into multiple tags. Trim each tag. Remove empty strings.
5. **Deduplicate by address** (case-insensitive): if the same address appears multiple times, keep the last occurrence (the user likely corrected it). Warn about duplicates.

After filtering, report to the user:
- Total rows in the file
- Rows skipped (blank name)
- Rows to import
- Any duplicates found

Then show a preview table of the first 10 rows that will be imported (address, name, tags) and ask the user to confirm before proceeding.

### Step 4 — Check existing contacts (only for imports with 50+ rows)

For small imports (<50 rows), skip this step and go straight to importing — fetching the entire address book for a handful of contacts adds unnecessary delay.

For larger imports, fetch the current address book to identify which addresses already have labels. This helps the user understand what will be created vs. updated.

```graphql
query AddressBook($limit: Int, $offset: Int) {
  customAccountNameLabel(limit: $limit, offset: $offset) {
    results {
      originalIdentifier
      labelValue
      tags
    }
    totalCount
  }
}
```

Paginate through all results (500 at a time). Build a lookup dictionary keyed by `originalIdentifier.lower()`.

Compare against the import list and report:
- **New contacts** — addresses not in the current address book
- **Updates** — addresses that already exist but will get a new name or tags

**Important**: `setCustomAccountNameLabelTags` is a **replace** operation, not append. If a contact currently has tags `["Exchange", "Custodian"]` and the import file has `["Vendor"]`, the old tags will be overwritten. Warn the user about this for any contacts being updated that already have tags.

Present this breakdown to the user before proceeding. If there are updates, list a few examples showing old name → new name so the user can sanity-check.

### Step 5 — Import contacts

For each validated row, make two API calls:

**5a. Set the contact name:**

```graphql
mutation SetContactName($identifier: String, $labelValue: String) {
  setCustomAccountName(identifier: $identifier, labelValue: $labelValue) {
    accountTxsSummary {
      accountIdentifier
      displayName
    }
  }
}
```

Variables:
```json
{
  "identifier": "<the address>",
  "labelValue": "<the contact name>"
}
```

**5b. Set tags (only if the row has tags):**

```graphql
mutation SetContactTags($identifier: String!, $tags: [String]!) {
  setCustomAccountNameLabelTags(identifier: $identifier, tags: $tags) {
    accountTxsSummary {
      accountIdentifier
      displayName
    }
  }
}
```

Variables:
```json
{
  "identifier": "<the address>",
  "tags": ["Exchange", "Custodian"]
}
```

**Batching strategy:** The API doesn't have a bulk endpoint. For small imports (<20 contacts), fire all name mutations in parallel, then all tag mutations in parallel — this is fast and safe. For larger imports, process in batches of 10 parallel calls to avoid overwhelming the API, and show progress to the user every 25 contacts (e.g. "Imported 25/142...").

**Error handling:** If a mutation fails for a specific address, log the error and continue with the next row. Don't stop the entire import. Collect all failures for the summary.

### Step 6 — Summary

After all mutations complete, present a summary:

- Total contacts imported successfully (name set)
- Total contacts with tags set
- Any failures (list the address and error message)

If there were failures, suggest the user can retry by running the skill again with the same file — already-imported contacts will just be updated (the mutation is idempotent for names).

## Edge Cases

- **File has no header row**: If the first row doesn't contain recognizable column names, tell the user the expected format and ask them to fix the file.
- **File has wrong columns**: If "Contact Address" column can't be found, the file isn't usable. Report which columns were found and what's expected.
- **Empty file**: If the file has headers but no data rows, tell the user.
- **All names blank**: If every row has a blank Contact Name, tell the user — they probably uploaded the unfilled template by mistake.
- **Very large files (>500 rows)**: Warn the user this will take a while and ask for confirmation.
- **Special characters in names**: Pass through as-is — TRES handles unicode in labels.
- **Mixed case addresses**: The `setCustomAccountName` mutation accepts addresses as-is. Don't normalize case — pass the original value from the file.
- **Tag with extra spaces**: `" Exchange , Custodian "` → trim to `["Exchange", "Custodian"]`.
- **Address not in any transaction**: The mutations work even for addresses that TRES has never seen in a transaction — they create the address book entry regardless.
- **Tags overwrite**: `setCustomAccountNameLabelTags` replaces existing tags entirely. If the user only wants to add tags, they would need to merge with existing tags first (the skill does not do this automatically — it's a replace operation). Flag this to the user when updating existing contacts that already have tags.
- **CSV BOM prefix**: Excel-saved CSVs include a UTF-8 BOM (`\ufeff`) that corrupts the first column header. Always open CSVs with `encoding='utf-8-sig'`.
- **Semicolon-delimited CSVs**: European Excel exports use `;` instead of `,`. If comma parsing doesn't find the expected headers, retry with semicolon.
- **Trailing empty rows in XLSX**: openpyxl reads empty rows at the end of the sheet. Skip rows where all values are `None` or empty.
