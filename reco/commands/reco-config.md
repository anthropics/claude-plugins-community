# /reco-config

Reconfigure or troubleshoot the Reco MCP server in Claude Code.

Run this command when: the domain needs to change, your API key expired, you're switching tenants, or previously working tools return errors.

---

## Troubleshooting steps

### 1. Check the config file

Find the active `.mcp.json`:
- **Project**: `.mcp.json` in your project root (takes precedence)
- **Global**: `~/.mcp.json`

Read the file and confirm the default value in `${RECO_MCP_DOMAIN:-<value>}` is correct. The expected format is `<tenant>.reco.ai`.

### 2. Change the domain

To point to a different tenant, replace only the default value:

Before:
```
${RECO_MCP_DOMAIN:-oldvalue}
```

After:
```
${RECO_MCP_DOMAIN:-yourcompany.reco.ai}
```

Restart Claude Code after saving.

### 3. Re-authenticate

If tools return 401:
1. Reco → **Settings** → **API Keys** → generate a new key
2. Delete the `mcp-remote` credential cache: `rm -rf ~/.mcp-remote/`
3. Restart Claude Code — `mcp-remote` will prompt for the new key

### 4. Verify

After any change:

> "List my apps with limit 1"

A response confirms the server is working correctly.
