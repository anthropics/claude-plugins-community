---
name: testdino-sessions
description: Use when the user wants to browse, inspect, create, or update exploratory testing sessions in TestDino — by state, status, session type, assignee, release, or tags. Covers list_sessions, get_session, create_session, and update_session. Accepts counter-style IDs like SES-12.
---

# TestDino Exploratory Sessions

Use TestDino session tools when the user wants to browse, inspect, create, or update exploratory testing sessions.

Preferred flow:

1. Call `health` if `projectId` is not known.
2. Use `list_sessions` to discover sessions by state, status, session type, assignee, release, or tags.
3. Use `get_session` to inspect one session in detail.
4. Use `create_session` or `update_session` for session changes.

Important details:

- `sessionId` accepts an internal ID or a counter-style ID like `SES-12`.
- `assigneeUserId` accepts either a user ID or an email address.
- `state` accepts display form or canonical form, but canonical lowercase values are safest.
- `tags` and `linkedIssues` must be JSON arrays for create and update operations.

Good requests for this skill:

- list exploratory sessions in a project
- create an exploratory session for auth regression
- assign a session to alice@example.com
- update session state to under review
