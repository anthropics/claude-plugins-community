# Claude Plugins — Community

> [!WARNING]
> **This marketplace is deprecated.** Plugins are now listed and served through the [Claude plugin directory](https://claude.ai/plugins), which you can also browse at [claude.com/marketplace](https://claude.com/marketplace).
>
> - **Submit or update a plugin:** use [claude.ai/directory/manage](https://claude.ai/directory/manage).
> - **Install a plugin:** use the directory. This marketplace is no longer synced, so its entries stay at the versions they were last pinned to.

Community-contributed plugins for [Claude Cowork](https://claude.com/product/cowork) and [Claude Code](https://claude.com/product/claude-code).

## What this repo is

A frozen copy of the community plugin marketplace. The `.claude-plugin/marketplace.json` file here is the list of community plugins from the last sync, minus entries that had no pinned commit. It is no longer synced.

## Using this marketplace

### Claude Cowork

Install plugins from [claude.com/plugins](https://claude.com/plugins/).

### Claude Code

This marketplace is deprecated, so prefer the [Claude plugin directory](https://claude.ai/plugins). To install from this repository anyway:

```bash
claude plugin marketplace add anthropics/claude-plugins-community
claude plugin install <plugin-name>@claude-community
```

## Submitting a plugin

Submit via **[claude.ai/directory/manage](https://claude.ai/directory/manage)**. Pull requests opened against this repo are not reviewed.

## Related

- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — Anthropic-maintained plugins (deprecated marketplace)
- [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) — role-specific knowledge-work plugins (deprecated marketplace)
