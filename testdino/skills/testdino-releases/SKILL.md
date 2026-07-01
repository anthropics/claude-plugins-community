---
name: testdino-releases
description: Use when the user wants to browse, inspect, create, or update releases/milestones in a TestDino project. Covers list_releases, get_release, create_release, and update_release. Accepts counter-style IDs like MS-12.
---

# TestDino Releases

Use TestDino release tools when the user wants to browse, inspect, create, or update releases in a project.

Preferred flow:

1. Call `health` if `projectId` is not known.
2. Use `list_releases` when the user needs discovery, filtering, or release lookup.
3. Use `get_release` when the user already has a specific `releaseId` or needs full release details.
4. Use `create_release` or `update_release` for release changes.

Important details:

- `releaseId` accepts either the internal ID or a counter-style ID like `MS-12`.
- `type` accepts either display form or canonical form, but canonical lowercase values are safest.
- `linkedIssues` must be sent as a JSON array for create and update operations.

Good requests for this skill:

- list releases in a project
- show details for release MS-12
- create a sprint or iteration release
- update release dates or status
