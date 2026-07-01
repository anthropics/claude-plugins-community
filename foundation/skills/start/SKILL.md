---
name: start
description: Start using Unstructured Foundation and choose the best next step.
user-invocable: true
disable-model-invocation: true
---

# Start Unstructured Foundation

Orient the user to Unstructured Foundation. This command is user-invoked only; do not use it for unsolicited capability messages.

First, call `pipeline_processing_status` with no `since` value.

Use the returned status to give the next step:

- `no_sources`: Say no sources are connected yet. Suggest `/foundation:connect`, then processing files, then asking what is searchable.
- `never_run`: Say sources are connected but files have not been processed yet. Mention source names if the status includes them. If names are missing and `pipeline_list_sources` is available, call it.
- `running`: Say files are still being processed. Include progress counts if returned.
- `failed`: Say processing hit a problem. Summarize the status and do not retry automatically.
- `ready`: Say Foundation is ready. Offer short examples like "What documents do you have access to?", "Search my documents for quarterly revenue.", and "What's new since yesterday?"

If sources are already connected, still mention that the user can add another source with `/foundation:connect`.

Do not call `pipeline_link_source` unless the user explicitly asks to connect a source now.

Use public language: say "Unstructured Foundation", "sources", "files", "documents", "processed", "searchable", and "data source". Avoid internal system terms in user-facing prose.
