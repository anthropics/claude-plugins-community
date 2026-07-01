---
name: testdino-manual-tests
description: Use when the user wants to create, update, or browse manual QA test cases and suites in TestDino — not execution runs. Covers list_manual_test_suites, list_manual_test_cases, get_manual_test_case, create_manual_test_case, update_manual_test_case, create_manual_test_suite.
---

# TestDino Manual Tests

Use TestDino manual-test tools when the user wants to create, update, or browse manual QA cases and suites.

Preferred flow:

1. Call `health` if `projectId` is not known.
2. Use `list_manual_test_suites` to find the destination suite when needed.
3. Use `list_manual_test_cases` or `get_manual_test_case` to inspect existing cases.
4. Use `create_manual_test_case`, `update_manual_test_case`, or `create_manual_test_suite` for edits.

Boundary:

- This skill is for manual test cases and suites.
- Manual execution runs are a separate workflow and should use the manual-run tools.

Good requests for this skill:

- create a manual test case
- update preconditions or steps
- list manual cases in a suite
- create a new manual test suite

Common filters from the docs:

- search
- suite
- status
- priority
- severity
- type
- layer
- behavior
- automation status
- tags
- flaky flag

When creating a case:

- confirm or resolve the target suite first
- include steps, preconditions, and postconditions when the user provides them
- preserve existing fields on updates by sending only the fields that should change
- send structured arrays for fields like tags when the MCP payload requires arrays
