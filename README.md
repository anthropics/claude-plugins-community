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

Submit via **[clau.de/plugin-directory-submission](https://clau.de/plugin-directory-submission)**. Pull requests opened directly against this repo are closed automatically — all changes flow from the internal review pipeline.

## Maintaining an approved plugin

This repository is a mirror, so approved plugin authors cannot update
`.claude-plugin/marketplace.json` by opening a pull request here. Until the
submission flow exposes a self-service update path, use a GitHub issue for
maintenance requests that need Anthropic review:

- **SHA bump**: include the plugin name, source repository, current pinned SHA,
  requested 40-character SHA, and a short summary of what changed.
- **Listing update**: include the plugin name, requested description or homepage
  change, and confirmation that the source repository is still controlled by the
  approved author or organization.
- **Deprecation or replacement**: include the plugin name, whether it should be
  marked deprecated, and the replacement plugin name if users should migrate.

Requests that change `source.url`, transfer ownership, or replace a repository
may require the full submission review path again.

## Related

- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — Anthropic-maintained plugins
- [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) — role-specific knowledge-work plugins
