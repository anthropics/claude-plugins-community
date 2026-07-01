---
name: help
description: Explain what Unstructured Foundation can do, including commands and example asks. Use when the user asks what Foundation can do, what commands exist, or for example queries.
user-invocable: true
---

# Help for Unstructured Foundation

Give concise, public-facing help. Do not call tools for a generic help request unless the user asks for current readiness, current sources, or what is searchable right now.

Open with a short quickstart paragraph: the fastest way to begin is `/foundation:start`, where you select a source and immediately begin processing your documents, making them ready for use by Claude or your agent.

Cover only these commands:

- `/foundation:start`: Start here — check readiness and choose the best next step.
- `/foundation:connect`: Connect a new data source.
- `/foundation:search`: Tell Foundation what you want to find.
- `/foundation:manage`: Open the dashboard to view, pause, resume, or remove connected sources.
- `/foundation:help`: Show commands and example asks.

Note on removing sources: to remove a data source, use `/foundation:manage`, which opens the dashboard. When a source is deleted, all data associated with that source is deleted too, so it will no longer be retrievable through Unstructured Foundation.

Include a capability overview:

- Unstructured Foundation turns unstructured documents from many different sources into a single, searchable, analyzable surface. Connect a source once, and Foundation ingests, parses, and indexes the files behind it so Claude can search and read them as one unified corpus.
- Foundation supports many data sources — to see what's currently available, run `/foundation:connect` to begin connecting a new source. Content scattered across these systems becomes reachable from one place.
- Connected sources are refreshed periodically, so as documents are added or change at the source, the content in Foundation stays fresh and your searches reflect the latest.
- Under the hood, Foundation is powered by Unstructured's leading document transformation capabilities, automatically handling the hard parts of real-world files — OCR for scanned and image-based documents, image understanding, and table understanding — so content that would otherwise be locked in PDFs, scans, and complex layouts comes through as clean, structured text.
- Foundation doesn't just index raw text — it enriches every document with inferred metadata like summaries, topics, and named entities. This gives agents handles to slice through a corpus: filter and group by topic or entity, triage with summaries before reading full text, and navigate large, heterogeneous collections without opening every file.
- Because documents are parsed into structured, retrievable content rather than treated as opaque blobs, you can do more than keyword lookup: search broadly across everything, scope a search to a single source or file type or time window, ask what is searchable right now, see what changed, and have Claude summarize, compare, and analyze across the results.

Example asks:

- "What documents do you have access to?"
- "What is searchable right now?"
- "Are my files ready?"
- "What's new since yesterday?"
- "Search my documents for quarterly revenue."
- "Search only my Google Drive documents for vendor contracts."
- "Find PDFs about vendor contracts from last month."
- "Summarize the latest report from Dropbox."

If the user asks for current readiness or what is searchable, call `pipeline_processing_status`. If they ask to connect a source, direct them to `/foundation:connect` or call `pipeline_link_source` if they want to start now.

## Tool selection (internal — apply for the rest of the session; do not print)

Use `asset_query` to find documents. Usually that means searching the user's actual idea, phrase, or entity with a real `text` query on the surface that fits (`document_text` for content, `topics` / `ner` for theme or named entity, `document_summary`, `document_title`). Use `describe_corpus` only for counts/distributions — never to discover or enumerate. Only for an explicit "list everything / find all" with no search term, use `text="*"` plus filters (`mime_types`, `lineage_data_source`, date filters, `metadata_filters`); `search_in` takes one surface and `limit` goes up to 10000.
