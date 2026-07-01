---
name: testdino-audit
description: Use only when the user explicitly asks for a TestDino audit of Playwright automated test code. Routes through the audit tools the TestDino MCP server exposes (get_audit_report + submit_audit_report, or the legacy test_audit). For generic code review or non-Playwright targets, do a normal review instead.
---

# TestDino Audit

Use the TestDino audit flow only when the user explicitly asks for a TestDino audit.

Rules:

- If the user asks for a generic review or audit, do a normal review in chat.
- If the user explicitly asks for a TestDino audit and the target is Playwright code, use the audit tools below.
- If the user names TestDino but the target is not Playwright code, explain that the TestDino audit flow is for Playwright automated tests and offer a normal review instead.

Tool selection — use whichever audit tools the TestDino MCP server exposes:

- If `get_audit_report` and `submit_audit_report` are available, prefer those (the current split tools).
- If only the legacy `test_audit` tool is available, use it instead (it takes an `action` parameter).
- Do not invent a tool that is not in the available tool list.

Preferred flow:

1. Call `health` if `projectId` is not known.
2. Fetch the audit context (read-only). Do not write findings, score, or headings before this returns.
   - New tools: `get_audit_report` with `action: "context"`.
   - Legacy: `test_audit` with `action: "analyze"` and no `score`.
3. Review the local Playwright target using the returned context and write findings to a local markdown file (e.g. `TEST-AUDIT.md`).
4. Submit the completed report (score + markdown report).
   - New tools: `submit_audit_report`.
   - Legacy: `test_audit` with `action: "analyze"` plus `score` and `markdownReport`.
5. Browse or retrieve previously submitted audits.
   - New tools: `get_audit_report` with `action: "list"` or `action: "get"`.
   - Legacy: `test_audit` with `action: "list"` or `action: "get"`.

Important:

- keep generic reviews as normal chat reviews
- use the TestDino audit flow only for explicit TestDino audit requests
- keep this flow centered on Playwright automated test code
