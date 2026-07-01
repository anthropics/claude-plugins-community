---
name: data-analysis
description: >-
  Trigger when the user says "crunch the numbers", "compare Q3 vs Q4", "what
  does this data show", "break down these numbers", "analyze this CSV",
  "build a pivot", "calculate growth rate", "find outliers", provides a data
  file, references workspace spreadsheets/reports, or pastes a table.
  Performs calculations, statistical analysis, trend identification,
  period-over-period comparisons, distribution analysis, and data
  transformations on CSV, Excel, PDF tables, and JSON. Do NOT trigger for ad
  performance metrics (no API access to ad accounts) or live brand signals
  (use Archival Knowledge).
---

# Data Analysis

<tool_persistence_rules>
**BANNED TOOLS — NEVER call any of these, regardless of context:**
- ❌ `search_documents`
- ❌ `list_documents`
- ❌ `read_document`
- ❌ `read_document_by_path`
- ❌ `file_repository_list_folders`
- ❌ `file_repository_list_files`
- ❌ `file_repository_search_files`
- ❌ `file_repository_search_folders`
- ❌ `file_repository_read_file`

For ANY workspace file operation, call `file_repo_reader` instead. It handles all file discovery, searching, and reading.
</tool_persistence_rules>

---

## Step 1: No clarification required

Ask clarifying questions ONLY if the request is materially ambiguous. Do NOT ask for confirmation between steps.

---

## Step 2: UNDERSTAND AND PLAN (internal)

1. **Understand** — What metric, comparison, or insight is needed?
2. **Determine** — What data is available? Is it uploaded directly, pasted in the conversation, or stored in the workspace file library?
3. **Plan** — Formulate a calculation plan. Think through edge cases: missing values, date formats, unit mismatches.

---

## Step 3: PREPARE DATA

### Supported Inputs

- **CSV** — `pd.read_csv()`. Watch for encoding, delimiter, header issues.
- **Excel** — `pd.read_excel()`. Check for multiple sheets; ask user which if ambiguous.
- **PDF** — `fetch_and_analyze_pdf` to extract, then process in code_interpreter.
- **Structured datasets** — JSON or data pasted in conversation.
- **Workspace files** — Files stored in the workspace file library. See "Retrieving Files from the Workspace" below.

### Retrieving Files from the Workspace

Users store files (reports, spreadsheets, research documents, brand assets) in the workspace file library. Users will rarely call it a "repository" — they typically say **"files," "documents," "reports," "saved docs," "saved research," "library,"** or **"brand files."** Any request that refers to previously saved or stored data should trigger this retrieval flow.

Files are stored at the **workspace level** (shared across all spaces in the workspace).

<dependency_checks>
When the user asks you to find, open, or analyze a stored file:

**First — confirm this is a file repository request, not a feed request.** This skill handles files stored in the **workspace file library** (spreadsheets, CSVs, uploaded documents, brand files). It does NOT handle feed-based data (signals, insights, brand mentions, audience convos, trending topics). If the user is asking about signals, insights, or feed items from a Space, route to the **Archival Knowledge** skill instead.

Common user phrases that belong here (file repository): "open the spreadsheet," "pull that Excel file," "find the CSV," "analyze the file on [topic]," "what's in the brand files," "find the report we uploaded."

Common user phrases that belong in Archival Knowledge (feeds): "what signals do we have," "any insights on [topic]," "what's been trending," "show me brand mentions," "what are people saying."

**Hand off to `file_repo_reader`.** All file repository operations — locating, searching, reading, and analyzing files — are handled by the `file_repo_reader` sub-agent. Do NOT call any of these tools directly:

- ❌ `file_repository_list_folders`, `file_repository_list_files`, `file_repository_search_files`, `file_repository_search_folders`, `file_repository_read_file`
- ❌ `search_documents`, `list_documents`, `read_document`, `read_document_by_path`

The ONLY tool you call for workspace files is `file_repo_reader`. Pass it:

- `query` — a detailed, self-contained natural-language instruction describing what the user needs. Include: what file to find (name, keyword, or topic), what to do with it (read, analyze, extract data, summarize), and what format the output should take.

Write the query as if briefing an analyst who has access to the full workspace file library but no prior context. The more specific and complete, the better the results.

Example inputs:

```
"Find the Seattle Scarborough Excel file and produce a cross-variable analysis linking demographics to media usage. Focus on sex/income/professional profile connections to news consumption, streaming, social media, radio, and local sports/event behaviors. Include the strongest percentages and index values, and end with 5-7 strategic insights for media planning."
```

```
"Find the Q4 brand report PDF and summarize the key findings on audience growth and engagement trends."
```

If `file_repo_reader` returns multiple matching files, present the options to the user as a table and ask which one they want, then re-call `file_repo_reader` with the specific file name.
</dependency_checks>

### Data Cleaning Checklist

- Missing values (nulls, empty strings, "N/A", "-")
- Duplicate rows
- Inconsistent date formats
- Numeric columns stored as strings (currency symbols, commas, %)
- Trailing whitespace and mixed case in categorical columns

---

## Step 4: EXECUTE AND VALIDATE

Run all calculations. Then **sanity-check before presenting**:
- Do totals add up?
- Are percentages between 0-100?
- Do trends match the raw data?

Only perform analysis the user explicitly asked for. Do NOT proactively suggest additional analyses unless they seem unsure how to proceed.

---

## Step 5: PRESENT

Lead with the key insight or takeaway. Follow with supporting data and breakdowns.

**Output format rule: Always present data as markdown tables, never as raw JSON.** Even when the underlying data is JSON, transform it into a readable table before showing it to the user. JSON output is only acceptable if the user explicitly requests raw data or a code block.

### Analysis Patterns

| Pattern | What to calculate |
|---|---|
| **Comparison** | Absolute values AND relative differences (% change). Rank items. |
| **Trend** | Period-over-period changes. CAGR for long periods. Seasonality, inflection points. |
| **Distribution** | Mean, median, mode, std dev. Outliers beyond 2 std devs. |
| **Correlation** | Correlation coefficients, direction, strength. Caveat: correlation ≠ causation. |
| **Composition** | Each component's share. Both absolute values and percentages. |

---

## Visualization

<tool_persistence_rules>
**MANDATORY: When the user asks for any visualization — a chart, graph, plot, visual, diagram of data, or comparison visual — you MUST call the `render_chart` tool. This is non-negotiable.**

Trigger phrases that REQUIRE `render_chart`:
- "chart," "graph," "plot," "visualize," "show me a visual," "bar chart," "pie chart," "line graph"
- "can you graph this," "make a chart of," "plot the data," "visualize the trend"
- "compare visually," "show the breakdown," "display as a chart"
- Any request where the user wants to SEE data rather than READ data

**NEVER do any of the following instead of calling `render_chart`:**
- ❌ Generate a chart via code interpreter or code execution
- ❌ Output chart markup inline in your response
- ❌ Describe what a chart would look like without rendering one
- ❌ Offer to create a chart later or ask if the user wants one — if they asked, render it
- ❌ Use any other tool, library, or method to produce a visualization

`render_chart` is the ONLY supported way to create visualizations. If you find yourself writing code that imports matplotlib, plotly, seaborn, or any charting library — STOP. Use `render_chart` instead.
</tool_persistence_rules>

<render_chart_rules>
**NEVER include `callbacks` or `callback` fields anywhere in the chart config.**
- ❌ `tooltip: { callbacks: {} }` — BANNED
- ❌ `ticks: { callback: {} }` — BANNED
- Simply omit these keys entirely. Do not set them to `{}`, `null`, or any value.
- If you need custom tick formatting, use `ticks.format` options only (no function references).
</render_chart_rules>

---

## Skill Deferral

This skill handles quantitative data analysis on files. Route elsewhere for:
- Paid ad library searches → Ad Intelligence skill
- Social media posts/sentiment → Social Intelligence skill
- General web/news research → Web Research skill
- Archived brand signals/insights (feeds, not files) → Archival Knowledge skill
