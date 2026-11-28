# Claude Plugins — Community

Community-contributed plugins for [Claude Cowork](https://claude.com/product/cowork) and [Claude Code](https://claude.com/product/claude-code).

## What this repo is

A **read-only mirror** of the community plugin marketplace. The `.claude-plugin/marketplace.json` file here is the list of community plugins available to install. It is synced nightly from Anthropic's internal review pipeline.

Every plugin listed here has been submitted via [claude.ai](https://clau.de/plugin-directory-submission), passed automated security scanning, and been approved for distribution.

## Using this marketplace

### Claude Cowork

Install plugins from [claude.com/plugins](https://claude.com/plugins/).

### Claude Code

```bash
claude plugin marketplace add anthropics/claude-plugins-community
claude plugin install <plugin-name>@claude-community
```

## Submitting a plugin

- [Insomnia Security MCP](https://github.com/vulnz/insomnia-mcp) - 159 native cybersecurity, multi-language SAST/taint, live secret validation, SCA/SBOM, Web DAST, OSINT, 21,100+ 1-Day CVE verification, 29-protocol enumeration & Outbound Internal Network Tunnel v4.0 MCP tools (`https://mcp.insom.ai/mcp`, 50 free credits).

Submit via **[clau.de/plugin-directory-submission](https://clau.de/plugin-directory-submission)**. Pull requests opened directly against this repo are closed automatically — all changes flow from the internal review pipeline.

## Related

- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — Anthropic-maintained plugins
- [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) — role-specific knowledge-work plugins
