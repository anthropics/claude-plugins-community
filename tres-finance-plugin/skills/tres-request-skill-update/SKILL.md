---
name: tres-request-skill-update
description: >
  Submit feedback about the TRES Claude plugin — bug reports, feature requests, skill
  improvements, new skill ideas, MCP issues, workflow friction, or positive feedback about
  what's working well. Use this skill whenever the user wants to share any kind of feedback
  about the plugin, its skills, or the TRES MCP. Trigger phrases include: "submit feedback",
  "report a bug", "request a feature", "suggest an improvement", "I have an idea",
  "something is broken", "the skill isn't working", "I love this skill", "this worked great",
  "the MCP is returning wrong data", "the flow is confusing", "can you fix the skill",
  "file a skill request", "give feedback", "this could be better".
  Also trigger proactively when the conversation appears to be wrapping up — e.g. the user
  says "thanks", "that's all", "looks good", "we're done", "nothing else", or any other
  signal that the task is complete. In that case, offer a brief feedback prompt instead of
  launching the full guided flow.
  Do NOT trigger for general questions about how a skill works — only when the user wants to
  submit feedback or the conversation is ending.
---

# TRES Plugin Feedback

Guide the user through submitting clear, actionable feedback about the TRES Claude plugin
and save it via the `save_ai_conversation_feedback` TRES MCP tool. No extra configuration
required — works for any user with a TRES API token.

This skill operates in two modes:

1. **Explicit feedback** — the user asks to submit feedback, report a bug, etc. Run the full
   guided flow starting at Step 1.
2. **End-of-conversation prompt** — the conversation is wrapping up. Offer a quick,
   non-intrusive nudge (see Step 0) and only proceed to the full flow if the user opts in.

---

## Step 0 — End-of-Conversation Prompt

When the conversation appears to be ending (the user says "thanks", "that's all", "looks
good", etc.) and this skill is triggered proactively:

Ask casually:

> **Before you go — any feedback on how this session went? Bugs, ideas, or things that could
> be better? Happy to log it for the team in 30 seconds.**

- If the user **declines** ("no", "I'm good", "nah") — say "No worries, have a great day!"
  and stop. Do NOT push further.
- If the user **shares something** — transition into Step 1 and run the full guided flow,
  but keep it lightweight. Skip questions they've already answered in the conversation and
  aim for a quick turnaround.
- Keep the tone light and optional — this should never feel like a mandatory survey.

---

## Step 1 — Identify Submitter

1. Call `get_viewer` (TRES MCP, no arguments) to identify the submitter.
   - Extract the organization name from the response.
   - If `get_viewer` fails, use `"Unknown org"` as the submitter and continue.

2. Get the user's git identity for the feedback record:
   ```bash
   git config user.name && git config user.email
   ```
   Use line 1 as `agent_name` and line 2 as `agent_email`. If git is not available, use
   the system username and leave email empty.

Tell the user: **"You're connected as {orgName}. What feedback would you like to share?"**

---

## Step 2 — Understand the Feedback

Let the user describe their feedback in their own words first. Then classify it into one of
these categories based on what they said:

| Category | When to use |
|---|---|
| Bug report | Something is broken, erroring, or producing wrong results |
| Feature request | A new capability that doesn't exist yet |
| Improvement | An existing feature works but could be better (UX, formatting, flow, performance) |
| New skill idea | A proposal for an entirely new skill |
| MCP / data issue | The TRES MCP is returning wrong data, missing fields, or behaving unexpectedly |
| Positive feedback | Something is working well and the user wants the team to know |
| General feedback | Anything else — workflow friction, confusion, documentation, onboarding |

Confirm the category with the user: **"It sounds like this is a {category} — is that right?"**

If the feedback is about a specific skill or MCP tool, identify which one. If it's general
or about the plugin overall, note that.

**Known skills:**

| Skill | Description |
|---|---|
| `tres-asc845-swap-reprice-skill` | ASC 845 swap repricing to zero clearing account residuals |
| `tres-explorer-tx-to-ledger` | Add explorer TX to the TRES ledger |
| `tres-tx-story` | TX flow diagram and explanation |
| `tres-recon-gaps` | Reconciliation gap resolution |
| `tres-asset-balance-validation` | Balance validation vs DeBank |
| `tres-report-analyzer` | Analyze TRES report XLSX exports |
| `tres-report-advisor` | Recommend the right TRES report |
| `tres-invoice-bill-matching` | Match txs to ERP invoices/bills |
| `tres-export-3rd-party-contacts` | Export unidentified counterparties to XLSX |
| `tres-import-contacts` | Import contacts from CSV/XLSX |
| `tres-cost-basis` | Cost basis calculation, strategy, issues, reevaluations, exports |
| `tres-rollup-rules` | Sub-transaction rollup rules (aggregate txs) |
| `tres-onboarding` | Full entity onboarding (orchestrates sub-skills) |
| `tres-settings-management` | Org and platform settings |
| `tres-wallets-upload` | Wallet onboarding |
| `tres-upload-tx-header-validation` | Bulk transaction CSV header naming validation |
| `tres-request-skill-update` | This feedback skill |

> **Maintainer note**: update this table when new skills are added to the plugin.

---

## Step 3 — Dig Deeper

Based on the category, ask targeted follow-up questions to make the feedback actionable.
Ask one or two questions at a time — keep it conversational, not interrogative.

**For bug reports:**
- What exactly happened? What did you see?
- What did you expect to happen instead?
- What were you doing when it happened? (steps to reproduce)
- Did you see an error message? If so, what did it say?
- Can you share a specific example? (tx hash, wallet address, input you used)

**For feature requests & improvements:**
- What problem would this solve for you?
- How do you handle this today without the feature?
- Can you describe what the ideal experience would look like?
- How often do you run into this need?

**For new skill ideas:**
- What workflow or task would this skill automate?
- Who on your team would use it, and how often?
- Can you walk through a concrete example of how you'd use it?
- What data source would it need? (TRES MCP, external API, local files)

**For MCP / data issues:**
- Which MCP tool or query was involved?
- What data did you get back, and what was wrong about it?
- What did you expect the data to look like?
- Can you share the specific query or identifiers you used?

**For positive feedback:**
- What specifically worked well?
- Was there anything that surprised you (in a good way)?
- Is there a particular workflow or use case where it really shined?
- Would you change anything to make it even better?

**For general feedback:**
- What part of the experience are you reacting to?
- Was anything confusing or unclear?
- What would have made it better?

Adapt based on what the user has already told you — skip questions they've already answered.
The goal is to get enough detail that someone reading the feedback can understand the context
and take action without needing to ask follow-up questions.

---

## Step 4 — Preview the Feedback

Compose the feedback and show it to the user for review. Format it clearly:

```
Headline: {concise summary — max 80 chars}

Category: {Bug report | Feature request | Improvement | New skill idea | MCP issue | Positive feedback | General}
Area: {skill name, "MCP", or "General"}
Org: {orgName}

---

{Well-structured description that includes:
 - What the feedback is about (context)
 - The core issue, idea, or praise (substance)
 - Supporting details — steps to reproduce, examples, expected behavior, etc.
 - Impact — how often this comes up, how many people it affects, how it blocks work}

Tags: {comma-separated list}
```

**Writing the description:**
- Synthesize the user's answers into a clear, readable narrative — don't just dump Q&A pairs.
- Lead with the most important point.
- Include concrete details (tx hashes, error messages, specific steps) — these are what make
  feedback actionable.
- For positive feedback, be specific about what worked and why it mattered.

Also show the user the **conversation excerpt** that will be submitted (see Step 5 format).
This gives them informed visibility into what leaves their machine.

Ask: **"Here's what I'll submit — does this capture everything? Want to change anything?"**

Iterate if the user wants edits. Only proceed on explicit confirmation.

---

## Step 5 — Submit Feedback

Call `save_ai_conversation_feedback` with these arguments:

| Argument | Value |
|---|---|
| `headline` | Concise summary (max 80 chars). Prefix with category: `[Bug]`, `[Feature]`, `[Improvement]`, `[New Skill]`, `[MCP Issue]`, `[Praise]`, or `[Feedback]` |
| `description` | The full structured description from Step 4 |
| `conversation` | Scoped and redacted conversation excerpt (see format below) |
| `tags` | Array — always include `"plugin-feedback"`, plus the category tag (`"bug"`, `"feature"`, `"improvement"`, `"new-skill"`, `"mcp-issue"`, `"praise"`, `"general"`), plus the skill name if applicable |
| `agent_name` | From git config (Step 1) |
| `agent_email` | From git config (Step 1) |

**Conversation format** — include only the **last 30 exchanges** (user+assistant pairs)
from your context window, not the entire session history. Apply a redaction pass before
including any message:

- Replace `Bearer [A-Za-z0-9._\-]{20,}` → `Bearer [REDACTED]`
- Replace standalone 64-character hex strings → `[REDACTED_HEX]`
- Replace file paths matching `/Users/<name>/` or `/home/<name>/` → `/Users/[REDACTED]/`
- Remove any apparent BIP-39 mnemonic phrases (12–24 dictionary words)

Format:
```
USER: <text, redacted>

ASSISTANT: <text, redacted>

TOOL_CALL: <tool_name>(arg1=value1, arg2=value2)
TOOL_RESULT: <one-line summary of the result>

... continue for the last 30 exchanges only ...
```

---

## Step 6 — Report Result

**On success:**
Tell the user:
> Your feedback has been submitted — thank you! The team will review it.

If the feedback was a bug or blocker, add:
> If this is urgent, reach out to the team directly as well.

**On failure:**
Surface the error from the MCP tool and suggest:
- Check that the TRES API token is valid
- Try again — it may be a transient issue

---

## Error Handling

| Situation | Action |
|---|---|
| `get_viewer` fails | Continue with "Unknown org" as submitter |
| `save_ai_conversation_feedback` fails | Surface the error; suggest checking TRES API token |
| User cancels at preview | Say "No problem — feedback was not submitted" and stop |
| User provides empty description | Ask again — a description is required |
| git config unavailable | Use system username for agent_name, leave agent_email empty |
