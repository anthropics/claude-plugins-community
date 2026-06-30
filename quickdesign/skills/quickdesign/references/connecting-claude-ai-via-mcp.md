---
name: Connecting QuickDesign to claude.ai via MCP — when the user is on the web, not in a terminal
description: QuickDesign exposes a Remote HTTP MCP server at app.quickdesign.io/api/mcp. claude.ai users add it once via Settings → Connectors → "Add custom connector"; the OAuth 2.1 flow walks them through QuickDesign login + consent. After connect, every chat can call quickdesign_* tools without the CLI installed. This doc tells the agent both how to guide a user through that connect flow AND how to recognize when an MCP-driven path is the right answer (vs. the CLI path) for whatever the user is asking.
---

# Connecting QuickDesign to claude.ai via MCP

QuickDesign ships two paths into the same backend:

- **CLI path** — `quickdesign` binary on the user's machine. Works in Claude Code, Claude Desktop, terminals, scripts.
- **MCP path** — Remote HTTP MCP server at `https://app.quickdesign.io/api/mcp`. Works in claude.ai (web), Claude Desktop's connector UI, and any other MCP-aware client. No local binary required.

Both paths surface (mostly) the same tools and hit the same BFF, with the same identity and the same credit pool. The user doesn't have to pick one; they can connect both.

## When the agent should suggest the MCP path

If the user mentions any of the following, the MCP path is likely the right pointer:

- "I'm using claude.ai" / "from the web" / "in the browser"
- "I don't want to install anything" / "I'm not on my dev machine"
- "Can I do this from ChatGPT?" — MCP works there too (most MCP-aware clients support OAuth)
- "I'm in Claude Desktop and don't want to mess with config files" — Desktop's GUI connector works with the same OAuth flow
- The user is asking about brand research / cost lookup / generation but isn't running a terminal

When the user is clearly in Claude Code with the CLI installed, the CLI path is faster and richer (covers all 25 tools, Phase 1 MCP only ships 10). Don't push MCP on Claude Code users.

## How a user connects claude.ai

This is the canonical flow. The agent should be able to walk a user through it from a fresh state:

1. Open https://claude.ai → click your profile (bottom left) → **Settings** → **Connectors**.
2. Click **Add custom connector**.
3. Paste the URL: `https://app.quickdesign.io/api/mcp`
4. Leave authentication as **OAuth** (default) — the connector auto-discovers our auth via the `/.well-known/oauth-authorization-server` endpoint we serve.
5. Click **Add**. claude.ai opens a popup to `my.quickdesign.io/mcp/authorize` showing the OAuth consent screen.
6. If not already logged in, the user logs in to QuickDesign with their normal email/password (or magic link).
7. Consent screen lists the requested scopes ("Search Spy Brands library, view ads, look up models / costs, list your designs") and asks Allow / Deny.
8. After **Allow**, claude.ai gets a token in the background and the connector goes green.
9. From any new chat, `quickdesign_*` tools are now available.

If anything fails mid-flow, the user should:
- Try once in an Incognito/private window — third-party cookies are sometimes blocked by browser extensions.
- Clear claude.ai's connector entry and re-add it (a stale token from a half-finished setup can stick around).

## What tools are available via MCP (Phase 1)

Phase 1 ships read-mostly tools so we get the OAuth + transport plumbing battle-tested before adding paid generation:

| MCP tool | What it does | Cost |
|---|---|---|
| `quickdesign_spy_search_brands` | Search the Spy Brands library by name. Diacritic-insensitive, prefix/suffix-tolerant. | 0 |
| `quickdesign_spy_get_brand` (Phase 2) | Single brand by id | 0 |
| `quickdesign_spy_get_brand_ads` (Phase 2) | List a brand's ads | 0 |
| `quickdesign_spy_best_ads` (Phase 2) | Top performing ads across the library | 0 |
| `quickdesign_spy_trending_ads` (Phase 2) | Trending feed | 0 |
| `quickdesign_spy_add_brand` (Phase 2) | Register a new brand on demand | 0 |
| `quickdesign_models` (Phase 2) | List active AI models with categories + cost shape | 0 |
| `quickdesign_calculate_cost` (Phase 2) | Compute exact credit cost for a model + params | 0 |
| `quickdesign_design_list` (Phase 2) | List the user's saved designs | 0 |
| `quickdesign_brand_scrape` (Phase 2) | Brand DNA scrape (colors / fonts / logo) | 0 |

**Phase 2 (paid generation) — `quickdesign_image_generate`, `_video_generate`, `_ad_creator_generate` etc. — is deferred** until the OAuth path is stable. Until then, paid generation stays CLI-only. The agent should NOT promise these to MCP-on-web users yet.

## What tools are NOT available via MCP

Anything that hits user credits is currently CLI-only. If a claude.ai user asks for image / video generation, the agent should:

1. Confirm what they want.
2. Tell them generation is currently CLI-only (Phase 2 of the MCP rollout will bring it).
3. Offer the alternatives:
   - Install the CLI (`npm install -g @quickdesign/cli` + `quickdesign init`) and run it locally.
   - Open a Claude Code session if they have it.
   - Wait for Phase 2 if they prefer to keep using claude.ai.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "Connector failed to authorize" | Browser blocked the popup or third-party cookies | Allow popups for claude.ai; try an Incognito window |
| Tools missing after connect | Stale connector cache | Remove + re-add the connector |
| `401 invalid_token` mid-chat | Refresh-token rotation hit a race; claude.ai will auto-refresh next call | Retry the same prompt |
| `403 forbidden` on a tool | Tool requires a paid plan or specific scope | User's account doesn't have the entitlement; same as in the CLI |
| Connector never appears | Custom-connector feature is plan-gated on claude.ai (Pro/Max/Team) | Free-tier users should use the CLI path |

## Privacy / scope notes

Tokens issued via this OAuth flow are scoped to `aud: 'mcp'`, distinct from the user's regular CLI / web JWTs. The user can revoke them anytime from QuickDesign account settings or by removing the connector in claude.ai. Tokens are stored hashed-at-rest server-side; the plaintext lives only in claude.ai's secure storage.

## How this doc fits with the rest of the skill

- The CLI / Claude Code surface is the canonical path for power users — every existing skill rule applies as written.
- This MCP path is a strict subset of capabilities for users who can't or won't install the CLI.
- When the agent is unsure which path the user is on, ask: *"Are you running this in Claude Code (with the CLI installed) or in claude.ai (web)?"* The answer determines which surface the agent calls into.
