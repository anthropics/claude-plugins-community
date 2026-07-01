---
name: search
description: User-viewable, user-invocable guidance for searching and reading Unstructured Foundation documents. Use when the user asks to find, filter, summarize, or retrieve processed files from connected sources.
user-invocable: true
---

# Search And Retrieval Guidance

This skill is user-viewable and user-invocable. Use it as the retrieval workflow for natural-language requests about searchable documents in Unstructured Foundation.

Keep this file safe for users to read. Prefer product-facing language, avoid exposing private implementation notes, and mention raw IDs only when they are needed for a developer/debugging request.

## Readiness First

If the user asks whether files are ready, what is searchable, or why search has no results, call `pipeline_processing_status` before making a claim.

Map status to the next step:

- `no_sources`: no sources are connected yet; suggest `/foundation:connect`.
- `never_run`: sources are connected, but files have not been processed yet.
- `running`: files are still being processed; include progress counts when available.
- `failed`: processing hit a problem; summarize the status without retrying automatically.
- `ready`: documents are searchable; continue with search or retrieval.

When a search returns no useful matches, check readiness unless this was already done in the same flow. Do not tell the user that documents do not exist until the relevant processed data is ready.

## Choosing The Right Tool

`asset_query` is the front door for finding, filtering, listing, or enumerating documents — including broad "find all …" requests. `describe_corpus` answers *how many* / *what distribution* only (counts and breakdowns by source, type, or date); it never returns document identities or content, so don't use it to discover or enumerate documents. When unsure, start with `asset_query`.

## Search With `asset_query`

Use `asset_query` to find documents. Required parameters are:

- `text`: the user's query.
- `search_in`: a list containing exactly one current search surface.

Current `search_in` values:

- `document_summary`: generated document summaries.
- `document_title`: document names or titles.
- `document_text`: full processed document text.
- `topics`: generated topic labels.
- `ner`: generated entity labels.

Examples:

```text
asset_query(text="quarterly revenue", search_in=["document_text"])
asset_query(text="vendor contracts", search_in=["document_summary"])
asset_query(text="Acme Corp", search_in=["ner"])
```

Choose the surface by intent:

- Broad question answering: start with `document_text`.
- Finding a specific file by name: use `document_title`.
- Finding documents by high-level meaning: use `document_summary`.
- Finding themes: use `topics`.
- Finding people, organizations, locations, or other entities: use `ner`.

Query syntax:

- Use ordinary words for simple keyword search, such as `vendor contracts`.
- Use uppercase Boolean operators when the user combines terms explicitly, such as `revenue AND forecast` or `contract OR agreement`.
- Use a trailing prefix wildcard for prefix matches, such as `acqui*`.
- Use quoted phrases for exact phrases, such as `"master services agreement"`.
- Use `text="*"` when the user wants filtered browsing rather than a keyword search, such as all PDFs from a data source or all documents modified since a date.

Useful optional filters include `lineage_data_source`, `mime_types`, `created_at`, `modified_at`, `first_seen_at`, `last_materialized_at`, `metadata_filters`, `limit`, `offset`, and `strict`.

Use public language when explaining filters. Say "data source" to the user, but distinguish source type from source instance when choosing filters:

- `lineage_data_source` scopes to a source lineage or connector type, such as Google Drive, Dropbox, Slack, S3, or another source type, when that exact lineage value is known.
- `metadata_filters={"platform_workflow_id": "<source-id>"}` scopes to one configured source instance. The `<source-id>` is the source ID returned by `pipeline_list_sources` and corresponds to that connector instance, not to the connector type.

Filter guidance:

- Use `lineage_data_source` for named source lineages or connector types, such as all Google Drive documents or all Slack documents, when the exact lineage value is known.
- Use `mime_types` for requested file types, such as PDFs, slides, spreadsheets, or plain text.
- Use `modified_at` when the user asks what changed, was updated, or was modified in a time range.
- Use `created_at` when the user asks what was added or created in a time range.
- Use `first_seen_at` when the user asks what Foundation first ingested during a time range.
- Use `last_materialized_at` when the user asks what Foundation refreshed, reprocessed, or made newly searchable during a time range.
- Use exact `metadata_filters` only when the user asks for a specific metadata field/value or when a previous tool response exposed the exact field/value to reuse.
- Use `metadata_filters={"platform_workflow_id": "<source-id>"}` to scope a search to a single specific connected source instance. The `<source-id>` is the source ID returned by `pipeline_list_sources` — the same value works directly as the `platform_workflow_id` metadata filter. This is an instance-level filter, not a type-level filter. Prefer it when the user has multiple sources of the same connector type, for example two different Google Drives, and wants just one of them. Use `lineage_data_source` when the user names a connector type broadly.
- Prefer `text="*"` plus filters for requests like "show all PDFs from Dropbox" or "what was modified since Monday" when no keyword is provided.

## Finding All Matching Documents

`asset_query` already enumerates — don't page through the corpus, read every file, or ask the user to narrow just because the corpus is large.

- Filter-expressible criteria (type, source, date, metadata): `asset_query(text="*", search_in=[...], ...)` with `mime_types` / `lineage_data_source` / date filters / `metadata_filters`. `text="*"` returns an unranked `filter_only` set; `search_in` is still required (one surface). Raise `limit` (default 20, max 10000); above 10000, add filters rather than paging.
- Content criteria: search whichever surface fits — `document_text` for full text, `document_summary` / `topics` / `ner` for enriched discovery — to bucket matches, then fetch artifacts only on the ambiguous remainder.
- Handle autonomously; ask the user to narrow only when the request is ambiguous or the set exceeds the single-call max. Don't fall back to `describe_corpus` (counts, not documents).

## Follow Up With `asset_doc_id`

Search results include `asset_doc_id` values such as `adid:<uuid>`. Use `asset_doc_id` for all document follow-up calls.

For full processed text:

```text
asset_get_doc_text(asset_doc_id="adid:...")
```

For generated views:

```text
asset_get_artifact(asset_doc_id="adid:...", artifact_kind="document_summary")
asset_get_artifact(asset_doc_id="adid:...", artifact_kind="topics")
asset_get_artifact(asset_doc_id="adid:...", artifact_kind="ner")
```

Use generated views when the user asks for a summary, topics, entities, or a quick understanding of a file. Use full text when the user asks detailed questions, wants evidence from a document, or needs content that may not appear in a generated view.

Do not teach or use alternate generated-view lookup modes. Use `asset_doc_id` from `asset_query`, then call `asset_get_doc_text` or `asset_get_artifact`.

## Common Flows

For "search my documents for X":

1. If readiness is uncertain, call `pipeline_processing_status`.
2. Call `asset_query(text=X, search_in=["document_text"])`.
3. Summarize the best matches with document names and why they match.
4. Use `asset_get_doc_text` for top matches when the user needs the answer, not just search results.

For "summarize this/the latest/the matching document":

1. Use `asset_query` to identify the document if no `asset_doc_id` is already known.
2. Use `asset_get_artifact(asset_doc_id=..., artifact_kind="document_summary")`.
3. If the generated summary is missing or too thin, use `asset_get_doc_text` and summarize from the text.

For "what is searchable right now" or broad corpus counts:

Counts/distribution only — for finding or enumerating documents (even "find all"), use `asset_query`.

1. Use `pipeline_processing_status` first.
2. If documents are ready and `describe_corpus` is available, use it for corpus-wide counts.
3. Use `describe_corpus(group_by="lineage_data_source")` when the user asks for a connector/source-type breakdown or asks which source types have searchable documents.
4. Use `describe_corpus(group_by="platform_workflow_id")` when the user asks for a breakdown by specific connected source instance. Map source IDs to source names with `pipeline_list_sources` when possible; share raw source IDs only when the user asks for IDs or debugging details.
5. Keep the explanation public-facing; do not expose internal index IDs.

For "what changed since [date/time]":

1. Call `pipeline_processing_status(since=...)` first, using the user's date or time.
2. Summarize processing changes from that status before searching.
3. If the user wants document matches, call `asset_query` with `text="*"` and the matching `modified_at`, `created_at`, `first_seen_at`, or `last_materialized_at` filter.
4. Retrieve generated summaries or full text for the relevant matches as needed.

For "summarize what changed since [date/time]":

1. Call `pipeline_processing_status(since=...)` first.
2. Use `asset_query(text="*", search_in=["document_summary"], modified_at=...)`, `created_at=...`, `first_seen_at=...`, or `last_materialized_at=...` according to the user's wording.
3. Use each result's `asset_doc_id` with `asset_get_artifact(asset_doc_id=..., artifact_kind="document_summary")` for concise follow-up retrieval.
4. Use `asset_get_doc_text(asset_doc_id=...)` only when the summary is missing, too thin, or the user asks for evidence.

For "what is searchable by data source":

1. Use `pipeline_processing_status` first.
2. If the user means connector/source types, call `describe_corpus(group_by="lineage_data_source")`.
3. If the user means specific configured source instances, call `pipeline_list_sources` and `describe_corpus(group_by="platform_workflow_id")`; map source IDs to source names when explaining results.
4. If the distinction is ambiguous and affects the answer, ask whether they mean source type or a specific connected source instance.
5. Keep the explanation public-facing; do not expose internal index IDs.

For "search only [source type]" where the user names a connector/source type such as Google Drive, Slack, Dropbox, or S3:

1. Interpret the named source as a source-lineage or connector-type filter.
2. Call `asset_query` with `lineage_data_source` set to the requested source value.
3. If no matches appear, check readiness and explain that the filter may be too narrow, the exact lineage value may differ, or the source type may not be processed yet.

For "search only this specific source" where the user means one configured source instance, not a connector/source type:

1. Call `pipeline_list_sources` to identify the source the user means and obtain its source ID.
2. Call `asset_query` with `metadata_filters={"platform_workflow_id": "<source-id>"}`, combined with a real `text` query or `text="*"` for filtered browsing.
3. This pins results to exactly the documents ingested by that connector instance, which is useful when several sources share the same connector type. Refer to the source by name when explaining results to the user. Share the source ID only when the user specifically asks for IDs or debugging details.

## User-Facing Language

Prefer public terms: Unstructured Foundation, sources, connected sources, data source, processed files, searchable documents, document text, summary, topics, entities, generated view.

Avoid exposing private implementation notes. It is okay to mention exact MCP tool names, parameters, or returned fields when answering a developer/integrator question or when the user asks how the retrieval workflow works.
