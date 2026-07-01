---
name: manage
description: Open the Unstructured Foundation dashboard to manage connected sources.
user-invocable: true
disable-model-invocation: true
---

# Manage sources

Open the Unstructured Foundation dashboard so the user can manage their connected sources. This command is user-invoked only.

When invoked:

1. Call `pipeline_manage_sources`.
2. Present the returned URL to the user.
3. Tell the user to open the link in their browser to view status, pause or resume indexing, remove sources, and connect new ones.
4. Note that removing a source also deletes all data associated with it, so its documents will no longer be searchable through Unstructured Foundation.
5. If the user instead wants to add a new source, point them to `/foundation:connect`.

Use public language: say "manage sources", "data source", "pause or resume", "remove", and "searchable documents". Avoid internal system terms in user-facing prose.
