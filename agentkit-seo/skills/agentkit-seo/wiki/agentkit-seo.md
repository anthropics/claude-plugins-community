<!--
metadata:
  wiki: agentkit-seo
  module: agentkit-seo
  title: "AgentKit SEO"
  status: stable
  confidence: stable
  last_reviewed: 2026-05-27
  review_by: 2026-11-27
  source_status: repo
  agent_priority: high
-->

# AgentKit SEO

> AgentKit SEO is a portable skill bundle for agent-assisted professional discoverability work. It gives agents a context-first workflow, platform-specific methods, and provider-aware install layouts.

## 1. Load contract

Read this file when the user asks what AgentKit SEO is, what ACO means, how the skill system works, what the installer deploys, or how the repository's runtime architecture is organized.

If this file is unavailable in an older install, use `SKILL.md`, `references/installation-strategy.md`, and the installed `agentkit-seo-install.json` manifest when present. State that the wiki entry is unavailable before making architecture claims that depend on it.

## 2. Canonical definition

AgentKit SEO is an installable set of Markdown-first agent skills for improving public professional surfaces:

- Personal career context files
- LinkedIn profiles
- GitHub profiles and repositories
- CV and resume material for ATS-safe parsing
- Web portfolios
- X/Twitter profiles and posting surfaces

The package is distributed as `agentkit-seo` on npm. Its stable runtime unit is a folder containing `SKILL.md` plus supporting references. Provider adapters copy or wrap those shared skill folders for different agent environments.

## 3. Agent context optimization

Agent context optimization, or ACO, is the process of building and maintaining a private, structured Markdown source of truth for a person's professional facts.

The resulting personal career context file stores verified identity, education, experience, projects, achievements, links, target roles, growth direction, evidence boundaries, constraints, claims to avoid, and positioning notes. Platform skills use that file as factual and directional input. They should not invent missing credentials, metrics, projects, employers, testimonials, responsibilities, or mature expertise for a future direction that is only stated as intent.

The context file is private user material. Do not commit it to this repository or include it in public generated docs.

## 4. Runtime architecture

AgentKit SEO uses four runtime-facing layers:

- `hub/`: human-readable playbooks, examples, templates, and source notes.
- `.skills/agent-skill/`: canonical portable runtime skills.
- `.skills/providers/`: provider-specific install notes, manifests, command wrappers, and extension metadata.
- `.skills/export/`: CLI code for install, export, doctor, list, version, and template commands.

The root `skills/`, `commands/`, `GEMINI.md`, and `gemini-extension.json` files are distribution artifacts for Gemini-compatible installs and gallery discovery. They are not the primary source of runtime methodology.

## 5. Skill behavior

`SKILL.md` files define when a skill should be used, what workflow to follow, and which supporting files to read. They should stay concise.

Runtime `references/` files contain focused procedural guidance for a task. Runtime `wiki/` files contain durable definitions, constraints, confidence labels, and failure modes that the agent loads only when the task needs them.

Agents should route to one module by default. Cross-platform work should usually start with the agent-context-optimization skill so user facts are normalized before public outputs are rewritten.

Before loading detailed module files, agents should use this root wiki as the graph entrypoint:

1. Use this file to understand the repository and runtime layers.
2. Choose the relevant module from the linked module wiki indexes.
3. Read only that module's `wiki/index.md` before deciding whether `wiki/knowledge.md`, `references/`, or human hub files are needed.
4. Use `llms.txt` as the public package map and `llms-full.txt` as the full bundled wiki context when those files are available in the package checkout.
5. Use `.assets/docs/getting-started.md` for setup onboarding and `.assets/docs/end-to-end-workflows.md` for demo prompts, sample inputs, multimodal material, and expected deliverables.

## 6. Install behavior

The CLI installs or exports the same shared skills into provider-specific layouts. Supported providers include:

- Shared bundle
- Claude Code
- Codex
- Gemini CLI
- Antigravity CLI
- OpenCode

Provider behavior is not identical. Some environments use native skill loading. Some expose slash commands. Some require explicit skill names in the prompt. The shared skill folder names are the portable contract.

## 7. Boundaries

AgentKit SEO does not guarantee rankings, recruiter attention, ATS scores, rich results, snippets, indexing speed, AI citations, or platform distribution.

Agents using AgentKit SEO must separate:

- Verified facts from the user's supplied context
- Facts observed in public pages or local files
- Documented platform behavior
- Inference from those facts
- Disputed or unstable claims that need review

When a claim depends on current platform behavior, paid-tier behavior, provider support, or search and ranking systems, verify with current sources when tools allow it or mark the claim as source-dependent.

## 8. Shared evidence labels

Use these labels when source status could affect a recommendation:

- `Verified`: Observed directly in inspected public material, local files, rendered output, supplied screenshots, extracted text, or a supplied source-of-truth file.
- `From context`: Taken from the user's personal career context file.
- `From source`: Taken from supplied source material such as pasted text, exports, screenshots, public URLs, local files, or job descriptions.
- `Inference`: Reasoned from inspected evidence, but not directly observed as a fact.
- `Inaccessible`: Could not be inspected because the surface is private, login-gated, unavailable, blocked, or outside the task scope.
- `Needs evidence`: A claim that should not be reused publicly until the user supplies support or it is verified in source material.

Do not turn `Inference`, `Inaccessible`, or `Needs evidence` claims into confident public copy.

## 9. Graph navigation

The repository has two connected documentation branches:

- Human layer: `README.md` -> `hub/<module>/README.md` -> `hub/<module>/sources.md`.
- Runtime layer: this root wiki -> `agentkit-seo-<module>/SKILL.md` -> `wiki/index.md` -> `wiki/knowledge.md`.

Human hub files explain playbooks, examples, templates, and source ledgers. Runtime wiki files explain compact agent-loadable constraints, confidence labels, and failure modes. Prefer the runtime branch for installed-agent work, and use the human branch when the task asks for contributor docs, editorial playbooks, templates, examples, or source provenance.

## 10. See also

- [Agent context optimization wiki index](../../agentkit-seo-agent-context-optimization/wiki/index.md)
- [CV ATS wiki index](../../agentkit-seo-cv-ats/wiki/index.md)
- [GitHub wiki index](../../agentkit-seo-github/wiki/index.md)
- [LinkedIn wiki index](../../agentkit-seo-linkedin/wiki/index.md)
- [Web portfolio wiki index](../../agentkit-seo-web-portfolio/wiki/index.md)
- [X Twitter wiki index](../../agentkit-seo-x-twitter/wiki/index.md)
- [Getting started](../../../../.assets/docs/getting-started.md)
- [End-to-end demos](../../../../.assets/docs/end-to-end-workflows.md)
- [llms.txt](../../../../llms.txt)
- [llms-full.txt](../../../../llms-full.txt)
