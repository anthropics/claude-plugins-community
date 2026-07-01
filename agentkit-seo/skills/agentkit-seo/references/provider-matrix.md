# Provider matrix

This matrix captures adapter assumptions as of April 28, 2026. Verify current provider docs before changing install behavior, command syntax, or marketplace guidance.

| Provider | Shared skill-bundle fit | Custom command fit | Best user-facing module trigger |
| --- | --- | --- | --- |
| Claude Code | Strong | Strong for plugins; local command directories do not create colon namespacing | Direct skill use or later plugin command such as `/agentkit-seo:linkedin` |
| Codex | Strong | Do not assume slash wrappers are the primary interface | Explicit skill selection such as `$agentkit-seo-linkedin` |
| Gemini CLI | Strong | Strong, with documented namespaced commands from nested paths | `/agentkit-seo:linkedin` |
| Antigravity CLI | Strong | Unknown at launch; imports Gemini extensions as plugins, but command names need live confirmation | Native plugin or skill discovery first; Gemini-style `/agentkit-seo:linkedin` remains TBD |
| OpenCode | Strong | Strong, with documented flat commands from Markdown filenames | Native skill loading or `/agentkit-seo-linkedin` |

## Policy

Do not force one command syntax across all providers. Keep the shared skill names stable and let adapters expose the cleanest native interface each provider actually supports.

## Packaging policy

The provider-facing artifact should be the self-contained shared skill bundle. Provider adapters may add wrapper commands, installer metadata, or export layout, but they should not become alternate knowledge bases.

## Current command wrapper status

| Provider | Shipped command wrappers | Notes |
| --- | --- | --- |
| Claude Code | No | Exact `/agentkit-seo:module` syntax should wait for a Claude plugin package. |
| Codex | No | Use installed skills directly. |
| Gemini CLI | Yes | Extension bundle installs namespaced wrappers under `commands/agentkit-seo/`. |
| Antigravity CLI | Yes | Plugin bundle installs Gemini-compatible wrappers under `commands/agentkit-seo/`, but imported command syntax is TBD until confirmed in `agy`. |
| OpenCode | Yes | Flat wrappers are copied to `.opencode/commands/` or `~/.config/opencode/commands/`. |
