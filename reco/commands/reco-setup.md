# /reco-setup

First-time setup for the Reco MCP server in Claude Code.

Run this command when: Reco is not yet configured, tools are missing, or you get a connection error on first use.

---

## Setup steps

### 1. Locate the MCP config

Check for `.mcp.json` in your project root or `~/.mcp.json` globally. It should contain a `reco` server entry with `https://${RECO_MCP_DOMAIN:-not-setup}/mcp`.

If it doesn't exist, copy `claude/.mcp.json` from the `reco-mcp-plugins` repo into your project root.

### 2. Apply your tenant domain

Ask the user: "What is your Reco tenant domain? It looks like `yourcompany.reco.ai`."

In the config file, replace the exact string `not-setup` with the domain:

Before:
```
${RECO_MCP_DOMAIN:-not-setup}
```

After (example):
```
${RECO_MCP_DOMAIN:-yourcompany.reco.ai}
```

Only change the default value — do not touch any other part of the file.

### 3. Generate an API key

In Reco: **Settings** → **API Keys** → **Generate API key**.

Copy the key — it is only shown once. `mcp-remote` will prompt for it on first connection.

### 4. Restart Claude Code

Restart Claude Code for the config change to take effect.

### 5. Verify

Confirm the `reco` MCP server appears as connected, then verify:

> "List my apps with limit 1"

If results return, you're connected. If not, run `/reco-config` to troubleshoot.
