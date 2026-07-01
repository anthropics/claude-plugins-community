# Installation strategy

## Principle

Keep the methodology portable and the packaging thin.

## Shared source of truth

The reusable skill logic lives in:

- `.skills/agent-skill/agentkit-seo/`
- `.skills/agent-skill/agentkit-seo-*`

These shared skills should contain:

- the trigger description
- the workflow
- the local references the agent should read
- provider-agnostic guardrails

## Provider adapters

The provider directories in `.skills/` should only describe or generate:

- install targets
- wrapper commands
- provider-specific metadata

They should not become alternate copies of the platform methodology.

## Packaging recommendation

1. Keep editing the shared skills in-repo.
2. Keep each shared skill self-contained through `SKILL.md`, `references/`, and `agents/openai.yaml`.
3. Generate or copy provider-specific install artifacts from that shared source.
4. Ship the exact same shared skill names across providers whenever possible.
5. Use wrapper commands only to improve invocation ergonomics.

## Distribution recommendation

Treat the installable artifact as the shared skill bundle, not as the full repository. The full repo remains useful for authoring, review, and source traceability, but the runtime package should be able to travel with only the `.skills/agent-skill/` content plus the relevant provider adapter.

## CLI-wrapper recommendation

An `npx` installer can be useful as a convenience layer later, but it should be treated as a wrapper around provider-native install targets, not as the core standard. Provider-native skills, commands, extensions, or marketplace packages should remain the primary delivery model.
