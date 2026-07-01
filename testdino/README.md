[![Docs](https://img.shields.io/badge/docs-testdino.com-2563eb)](https://docs.testdino.com)
[![MCP](https://img.shields.io/badge/MCP-remote-6366f1)](https://docs.testdino.com/mcp/remote)
[![Playwright](https://img.shields.io/badge/Playwright-ready-2EAD33?logo=playwright)](https://playwright.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

# TestDino Plugins

Official plugins and integrations for [TestDino](https://app.testdino.com) — connect Playwright, CI/CD, and AI coding agents to your test data through the TestDino MCP server. Inspect runs, debug flaky tests, and manage manual testing in natural language.

> **Who is this for?** Teams running Playwright (or other automated suites) who want their CI results, flaky-test history, and manual test assets reachable from AI agents like Claude Code, Cursor, and Codex — without leaving the editor.

## Quick Start

Add the hosted remote MCP server to your AI agent's MCP config:

```json
{
  "mcpServers": {
    "testdino": {
      "url": "https://mcp.testdino.com"
    }
  }
}
```

Reload the client, start a **new chat**, then verify access:

```text
Use the TestDino connector. Call health and tell me which projects I have access to.
```

You should get back your identity, connector scope, and the `projectId` values you can use in follow-up prompts.

## Install in Claude Code

TestDino is packaged as a Claude Code plugin. Add the marketplace and install it:

```text
/plugin marketplace add testdino-hq/TestDino-Plugins
/plugin install testdino@testdino-plugins
```

This loads the TestDino skills and the remote MCP server. Start a **new chat**, sign in when prompted, and the TestDino tools become available.

## Plugins & Integrations

| Integration  | Description                                  | Repository                                                              | Status |
| ------------ | -------------------------------------------- | ----------------------------------------------------------------------- | ------ |
| testdino-mcp | Remote MCP server for AI coding agents       | [testdino-hq/testdino-mcp](https://github.com/testdino-hq/testdino-mcp) | Stable |

## What You Can Do

- **Connection & access** — validate access, discover organizations and projects
- **Test run analysis** — list runs and review failures by branch, commit, author, environment, and time range
- **Test case debugging** — inspect details, historical failures, retries, and artifacts
- **Manual testing** — create and update manual test cases, suites, and runs (including per-case results)
- **Releases** — list, inspect, create, and update releases or milestones
- **Exploratory sessions** — create and track exploratory testing sessions
- **Audits** — run the TestDino audit flow on Playwright test code

## Supported Integrations

- Playwright
- GitHub Actions / CI/CD pipelines
- MCP-compatible AI agents (Claude Code, Cursor, Codex)

## Compatibility

| Component             | Requirement                                  |
| --------------------- | -------------------------------------------- |
| AI agent              | Any MCP-compatible client                    |
| TestDino account      | Workspace access with a project              |
| Transport             | Remote MCP over HTTPS (`mcp.testdino.com`)   |
| Authentication        | OAuth 2.1 (sign in with your TestDino account) |

## Usage Examples

```text
Show test runs from the last hour
List failed test cases from the latest run
Find flaky tests in TestDino from the last 3 days
Debug the failing test case "visual.spec.js" in TestDino
Create a manual test case in TestDino for checkout
List releases in TestDino for project xyz
Mark TC-156 as passed in RUN-12
Assign TC-156 in RUN-12 to alice@example.com
Run a TestDino audit on this Playwright spec
```

## Ecosystem

- **Product** — [app.testdino.com](https://app.testdino.com)
- **Docs** — [docs.testdino.com](https://docs.testdino.com)
- **Remote MCP guide** — [docs.testdino.com/mcp/remote](https://docs.testdino.com/mcp/remote)
- **MCP server source** — [github.com/testdino-hq/testdino-mcp](https://github.com/testdino-hq/testdino-mcp)

## Troubleshooting

- **Authorization fails** — sign in with the correct TestDino account.
- **Server connects but no tools appear** — start a new chat; some clients attach MCP tools only at chat creation.
- **Project access missing** — reconnect with a token that has the correct scope.

## Contributing

1. Open an issue describing the change or bug.
2. Fork, branch, and submit a pull request against `main`.
3. Link related TestDino ecosystem repos in the PR description.

## Support

- Email — [support@testdino.com](mailto:support@testdino.com)
- Docs — [docs.testdino.com](https://docs.testdino.com)
