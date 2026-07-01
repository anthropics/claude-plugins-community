---
name: testdino-manual-runs
description: Use when the user wants to manage a manual execution run or update case-level results inside a run — listing runs, creating runs for a release, inspecting a run, assigning cases, or marking case results (passed/failed/blocked/skipped/retest/untested). Accepts counter-style IDs like RUN-12 and TC-156.
---

# TestDino Manual Runs

Use TestDino manual-run tools when the user wants to manage a manual execution run or update case-level results inside a run.

Preferred flow:

1. Call `health` if `projectId` is not known.
2. Use `list_manual_runs` to discover runs by name, state, release, environment, or tags.
3. Use `get_manual_run` to inspect one run's metadata and rollup stats.
4. Use `create_manual_run` or `update_manual_run` for run-level metadata changes.
5. Use `list_run_test_cases` before changing any individual case in a run.
6. Use `update_run_test_case` to assign a case, change its result, or update elapsed time.

Important details:

- `runId` accepts an internal ID or a counter-style ID like `RUN-12`.
- `rtcRef` can be the run test case row ID, case key like `TC-156`, or the underlying test case ID.
- `updates.assigneeUserId` can be a user ID or email address.
- `updates.result` accepts display form or canonical form, but canonical values like `passed`, `failed`, `blocked`, `skipped`, `retest`, and `untested` are safest.
- For create and update payloads, `tags` and `linkedIssues` must be JSON arrays.

Good requests for this skill:

- list manual runs for a release
- create a manual run for sprint MS-12
- show all test cases in run RUN-12
- assign TC-156 in RUN-12 to alice@example.com
- mark TC-156 as passed in RUN-12
