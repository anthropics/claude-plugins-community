---
name: tres-onboarding
description: >
  End-to-end onboarding of a new entity, customer, or account into TRES Finance.
  Orchestrates 8 steps in order: wallet upload, data collection (commit), balance
  validation, reconciliation, cost basis, export unidentified addresses, import contacts,
  and rollup rules. Trigger ONLY when the user explicitly wants to onboard a new entity,
  customer, or account — e.g. "onboard a new entity", "onboard new customer", "start
  onboarding for [name]", "set up a new account in TRES", "run the full onboarding flow",
  "I need to onboard [company name]", "new entity onboarding". Do NOT trigger for
  individual tasks — those have their own dedicated skills. If the user asks to "add
  wallets" without mentioning onboarding, use tres-wallets-upload. "Validate balances" alone
  is tres-asset-balance-validation. "Run a commit" alone is tres-data-collection-commit.
  Only trigger when the user wants the full pipeline.
compatibility: "Requires TRES Finance MCP connector and all sub-skills listed below"
---

# TRES Finance — Full Entity Onboarding

Orchestrate the complete onboarding of a new entity/customer/account into TRES Finance.
This skill does not contain its own low-level logic — instead, it drives the user through
8 sequential steps, invoking the dedicated skill for each one. Think of it as a conductor
that keeps the onboarding moving forward while each sub-skill handles the details.

---

## Before You Start

**No visualizations for input gathering.** Do NOT use show_widget, HTML widgets, interactive
forms, AskUserQuestion widgets, or any visualization tool when collecting initial context from
the user or presenting the onboarding roadmap. Ask all questions and present the roadmap as
plain text in the chat. This keeps the flow fast and responsive — building a widget just to
ask for a name and wallet list adds unnecessary latency. Visualizations are fine later when
individual sub-skills need them (e.g., balance validation dashboards, recon gap tables), but
the onboarding kick-off and step transitions must be text-only.

1. **Confirm intent.** The user must have explicitly requested a full onboarding (new entity,
   new customer, new account). If the request is ambiguous, ask: "Are you looking to run the
   full onboarding flow for a new entity, or do you just need help with a specific step
   (like uploading wallets or validating balances)?"

2. **Collect context.** Ask the user in plain text (no widgets, no forms) for:
   - The entity/customer/account name
   - Any wallets or exchange accounts they already have ready (file, list, etc.)
   - Whether they have a target date in mind for the onboarding

3. **Present the roadmap.** Before diving in, show the user the roadmap as plain text
   in the chat (not as an HTML widget or visualization) so they know what to expect.
   Use something like:

   > Here's the onboarding roadmap for **[Entity Name]**:
   >
   > 1. **Upload Wallets** — Add on-chain wallets and/or exchange accounts
   > 2. **Data Collection (Commit)** — Pull on-chain data for the uploaded wallets
   > 3. **Validate Balances** — Cross-check TRES balances against on-chain sources
   > 4. **Reconciliation** — Review and resolve any balance gaps
   > 5. **Cost Basis** — Configure and run cost basis calculation
   > 6. **Export Unidentified Addresses** — Extract 3rd-party addresses from transactions
   > 7. **Import Contacts** — Label and import the identified addresses back into TRES
   > 8. **Rollup Rules** — Set up transaction aggregation for high-volume wallets
   >
   > We'll go through each step together. Ready to start?

---

## The Onboarding Pipeline

Work through each step in order. After completing each step, briefly summarize what was
accomplished and ask the user if they're ready to move on. If a step isn't relevant
(e.g., no high-volume wallets that need rollup rules), the user can skip it.

**Important:** For each step, invoke the corresponding skill by name. Read its SKILL.md
and follow its instructions. The sub-skill handles all the details — your job is to
transition smoothly between steps and keep the user oriented.

### Step 1: Upload Wallets
**Skill:** `tres-wallets-upload`

Invoke the tres-wallets-upload skill. This guides the user through adding their on-chain
wallets and/or exchange accounts into TRES. Once wallets are created, confirm the count
and proceed.

**Transition:** "Wallets are uploaded. Next, we'll collect on-chain data for them."

---

### Step 2: Data Collection (Commit)
**Skill:** `tres-data-collection-commit`

Invoke the tres-data-collection-commit skill. This triggers on-chain data collection for
the wallets that were just uploaded. The commit may take some time depending on the number
of wallets and their history.

**Transition:** "Data collection is in progress / complete. Next, let's validate that the
balances TRES pulled match what's actually on-chain."

---

### Step 3: Validate Balances
**Skill:** `tres-asset-balance-validation`

Invoke the tres-asset-balance-validation skill. This compares TRES balances against DeBank
(for EVM wallets) and generates a discrepancy report. Review any issues with the user.

**Transition:** "Balance validation is done. Let's move on to reconciliation to close any
remaining gaps."

---

### Step 4: Reconciliation
**Skill:** `tres-recon-gaps`

Invoke the tres-recon-gaps skill. This fetches reconciliation gap data, displays it, and
helps the user resolve any on-chain vs. book balance discrepancies. If there are no gaps,
celebrate and move on.

**Transition:** "Reconciliation is squared away. Now let's set up cost basis calculation."

---

### Step 5: Cost Basis
**Skill:** `tres-cost-basis`

Invoke the tres-cost-basis skill. This walks through strategy selection if needed, triggers
cost basis calculation, surfaces per-asset results and financial issues, and covers
reevaluations, spec-ID rules, and related cost basis operations as needed. Review any
financial issues (negative balances, missing fiat prices) that surface.

**Transition:** "Cost basis is configured and running. Next, let's identify the external
addresses your wallets have been interacting with."

---

### Step 6: Export Unidentified Addresses
**Skill:** `tres-export-3rd-party-contacts`

Invoke the tres-export-3rd-party-contacts skill. This extracts all unidentified external
addresses from the entity's transactions and exports them as an XLSX workbook. The user
will need to review and label these addresses (who each address belongs to).

**Transition:** "The unidentified addresses have been exported. Once you've labeled them,
we'll import them back as contacts. If you need time to fill in the names, we can pause
here and come back to the next step later — just say 'continue onboarding' when ready."

**Note:** This step produces output that the user needs to review and fill in offline.
Offer to pause the onboarding here and resume later. If the user wants to continue
immediately (maybe they'll label contacts later), that's fine — skip to Step 8.

---

### Step 7: Import Contacts
**Skill:** `tres-import-contacts`

Invoke the tres-import-contacts skill. This reads the user's labeled contacts file and
imports the address-to-name mappings into the TRES address book.

**Transition:** "Contacts are imported! Last step — let's set up rollup rules for any
high-volume wallets."

---

### Step 8: Rollup Rules
**Skill:** `tres-rollup-rules`

Invoke the tres-rollup-rules skill. This helps the user identify wallets with high
transaction volume and create daily or monthly rollup rules to consolidate small
sub-transactions (gas fees, staking rewards, etc.) into cleaner aggregated entries.

If no wallets need rollup rules, skip this step.

---

## Completion

Once all steps are done (or skipped where appropriate), wrap up with a summary:

> **Onboarding complete for [Entity Name]!**
>
> Here's what we accomplished:
> - Uploaded X wallets across Y networks
> - Collected on-chain data
> - Validated balances (note any outstanding issues)
> - Reconciled gaps (note status)
> - Configured cost basis strategy: [strategy]
> - Exported and imported Z contacts
> - Set up N rollup rules
>
> The entity is ready to go in TRES Finance.

---

## Handling Interruptions and Resumption

The user may need to pause and come back later (especially around Step 6-7 where they
need to label contacts offline). Keep track of which step was last completed. If the
user comes back and says something like "continue onboarding" or "where were we with
onboarding [entity]?", pick up from the next incomplete step.

## Skipping Steps

The user can skip any step if it's not relevant. For example:
- No EVM wallets → skip balance validation (Step 3)
- No gaps → reconciliation completes quickly (Step 4)
- No need for contacts right now → skip Steps 6-7
- No high-volume wallets → skip rollup rules (Step 8)

Always respect the user's choice and move to the next step.
