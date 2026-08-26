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

See the [plugin development docs](https://code.claude.com/docs/en/plugins) for how to structure a plugin that will pass validation.

## Review process

Every submission is reviewed and scanned before listing. Because scanning and safety review are ongoing processes, **additional time may be required** before a submission appears here. Review status and feedback are posted to your submissions list inside the Claude product where you submitted (claude.ai or Console) — check there for updates. Listing is at Anthropic's sole discretion.

### How listings stay current

- **Plugins are pinned to a specific commit SHA** that has passed safety scanning. Installing a plugin from this marketplace always resolves to that scanned SHA, not the tip of the source repo.
- **Scans refresh nightly.** Each night the pipeline re-scans source repos and advances the pinned SHA to the latest commit that passes. Push fixes or improvements to your repo and they will be picked up automatically once they clear the scan.
- **Listings that stop passing are removed.** If a plugin fails formatting validation or safety scanning — at submission time or during any nightly refresh — it is removed from the marketplace **without notice**. The same applies if the source repository becomes private, is deleted, or goes stale. Fix the issue upstream and it will be re-listed on the next passing scan.

## Disclaimer

Plugins in this marketplace are **community-contributed and community-maintained**. Anthropic runs automated safety scanning but does not author, audit line-by-line, or provide support for these plugins. Installing a community plugin may introduce new risks to your environment, data, or workflows. Review the source repository before installing.

### Support & reporting

- **Getting help** — community plugins are supported by their authors, not Anthropic. For usage questions or feature requests, use the plugin's source repository.
- **Bugs or quality issues** — open an issue on the plugin's source repository.
- **Security vulnerabilities** — report via Anthropic's [Responsible Disclosure Policy](https://www.anthropic.com/responsible-disclosure-policy). Do not open a public issue for security-sensitive reports.

## License

Each plugin is distributed under its own license. See the plugin's source repository for terms.

## Related

- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — Anthropic-verified & reviewed plugins for claude code
- [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) — Anthropic-verified & reviewed knowledge-work plugins for cowork
