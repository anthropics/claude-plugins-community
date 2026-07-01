---
name: connect
description: Connect a new source to Unstructured Foundation.
user-invocable: true
disable-model-invocation: true
---

# Connect a source

Connect a new source to Unstructured Foundation. This command is user-invoked only.

When invoked:

1. Call `pipeline_link_source`.
2. Present the returned URL to the user.
3. Tell the user to open the link in their browser and complete the connection.
4. Explain that the link expires after a few minutes and they should run `/foundation:connect` again if it expires.
5. Ask the user to say when the browser flow is complete.

When the user says the browser flow is complete:

1. Call `pipeline_list_sources`.
2. If exactly one newly connected source is visible and ready to process, call `pipeline_process_source` with that `source_id`.
3. If multiple sources are visible, ask which source to process.
4. After starting processing, tell the user they can ask "Are my files ready?" or run `/foundation:start`.

Important: `pipeline_link_source` returns a short-lived URL. Never reuse a URL from an earlier turn.

Use public language: say "connect a source", "process files", and "searchable documents". Avoid internal system terms in user-facing prose.
