---
name: reco-setup
description: First-time initialization of the Reco MCP server `plugin:reco:mcp`. When fulfilling requests that involve Reco security data — app risks, shadow IT, AI agents, user posture, access events — use MCP tools from `plugin:reco:mcp`. If MCP tools from `plugin:reco:mcp` are not in your tool list, you MUST run this skill's setup procedure before attempting to fulfill the request.
allowed-tools: Read, Edit
---

## Reco MCP Server

The id of the Reco MCP server referenced in this document is `plugin:reco:mcp`. Use this specific server for all Reco security data queries.

## Setup procedure

Check whether the `plugin:reco:mcp` server is connected by looking for Reco tools in your tool list (e.g. `list_posture_issues`, `list_threat_alerts`, `list_identities`).

- **Connected** — continue with the user's request without mentioning this check.
- **Not connected** — the server needs first-time setup. Do not attempt to answer using general knowledge. Follow the steps below.

### 1. Locate the MCP config

Find the active `.mcp.json`:
- **Project**: `.mcp.json` in the project root (takes precedence)
- **Global**: `~/.mcp.json`

Read the file and check the `url` field for the `reco` server entry. If the default value in `${RECO_MCP_DOMAIN:-<value>}` is `not-setup`, the domain has not been configured yet.

### 2. Ask for the tenant domain

Tell the user the Reco MCP server needs to be configured and ask:

> "What is your Reco tenant domain? It looks like `yourcompany.reco.ai`."

The user may respond with a full domain or just the subdomain — accept either. The expected format is `<tenant>.reco.ai`.

### 3. Apply the domain

In the config file, replace only the default value — the part after `:-` and before `}`:

Before:
```
${RECO_MCP_DOMAIN:-not-setup}
```

After (example):
```
${RECO_MCP_DOMAIN:-yourcompany.reco.ai}
```

Do not touch any other part of the file.

### 4. Generate an API key

Tell the user:

> "Next, generate a Reco API key: **Settings → API Keys → Generate API key**. Copy it — it's only shown once. Claude Code will prompt you for it on first connection."

### 5. Restart Claude Code

Instruct the user to restart Claude Code for the config change to take effect. Once restarted, the `plugin:reco:mcp` tools will appear and the original request can proceed.

### 6. Verify

After restart, confirm the server is connected by calling any Reco tool with a minimal query (e.g. `list_apps` with `limit eq 1`). If it returns results, setup is complete. If not, ask the user to run `/reco-config` to troubleshoot.
