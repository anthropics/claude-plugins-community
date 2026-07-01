---
name: auth0-branding
description: >
  Use when customizing the look of Auth0 Universal Login to match a brand — changing colors, logo, fonts, page layout, or login text. Also use when resetting branding to defaults or checking if branding is wired up end-to-end. Does not cover full custom UI screens — use acul-screen-generator for that.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
    requires:
      bins:
        - auth0
    os:
      - darwin
      - linux
    install:
      - id: brew
        kind: brew
        package: auth0/auth0-cli/auth0
        bins: [auth0]
        label: 'Install Auth0 CLI (brew)'
---

# Auth0 Branding

Style Auth0 Universal Login to match a brand. Covers the theme (colors, typography, borders, widget layout), tenant-level branding settings (logo, favicon, primary color), page templates (Liquid HTML that wraps the widget), and custom text per screen.

## Capabilities

When this skill is invoked **with a specific intent** in the opening message (e.g., "brand my tenant from ferrari.com", "reset the theme", "check if Universal Login is on"), parse the intent and route directly to the matching capability below. Do not show a picker.

When this skill is invoked **without intent** (bare `/auth0-branding`, or a vague "help me with branding"), show the table below and ask in one line: "Pick a number, name one, or describe what you want." Parse the reply — accept `1`, `"brand my tenant"`, or `"make it look like acme.com"` equivalently.

| # | Capability | What it does |
|---|---|---|
| 1 | **Brand my tenant** | Style Universal Login end-to-end from a website I own, brand assets I have, or manual input. Colors, logo, typography, page layout, and (optionally) login text voice, applied together |
| 2 | **Change specific settings** | Update individual pieces directly: a logo, color, font, corner radius, background, button label, or the page template. No URL extraction or asset parsing needed |
| 3 | **Match my brand voice** | Rewrite Universal Login text to sound like a source I provide: my website, sample copy, or a voice descriptor. Text only; doesn't touch colors or layout |
| 4 | **Rollback to Auth0 defaults** | Pick what to clear: tenant branding settings, the theme, the page template, or custom text on specific prompts |
| 5 | **Check my setup** | Verify that login, signup, password reset, and MFA are actually running Universal Login on my tenant and not Classic. Safe read-only starter |

The **Prerequisites** section applies to all capabilities.

## Prompt style

Prefer free-text prompts. The skill should parse natural replies, not force clicks. Use `AskUserQuestion` **only** when one of these applies:

1. **Multi-select of non-obvious options** where seeing the full list helps the user (e.g., Capability 3's flow categories — user won't remember the full set off the top of their head).
2. **Destructive-path safety gate** (e.g., Capability 4's "save a backup before reset?" yes/no).
3. **Disambiguation between 3+ distinct paths with meaningful trade-offs** the user wouldn't know by heart.

Everything else is free text. Specifically:

- **Review prompts** ("proceed? apply / edit / cancel, or tell me what to change") are free text. Parse the reply. If the reply names specific changes, apply them inline and re-render the proposal; don't make the user click through an edit submenu.
- **"Paste a value"** asks (hex code, URL, font name) are free text. Don't wrap single-field input in a picker.
- **Capability routing at entry** is free text. See the paragraph above the capabilities table.

Discoverability cue: every proposal must list the editable knobs inline, including **"off by default"** ones (voice rewriting, page template, layout override). Users can't ask to edit what they don't know exists. The "Also available" block under the main proposal in Capability 1 is the canonical pattern.

Don't auto-run optional steps (e.g., voice-flow detection, Brandfetch lookup on an unverified domain). Ask first whether the user wants to list, detect, or pick.

## Plan mode

When Claude Code is in plan mode, the skill's writes — PATCH/PUT/DELETE/POST against the Management API, plus local file writes (backup JSON, Brandfetch key) — are held until the plan is approved.

**What's allowed:**
- GETs against the Management API (loading current theme, branding, custom text, prompts, connections, tenant settings). These drive the proposal and diagnostics.
- LLM-only work: voice classification, translation generation, proposal rendering.
- Capability 5 runs unchanged; it's already read-only.

**What's deferred:**
- All Management API writes (no PATCH/PUT/DELETE/POST).
- Local file writes: Capability 4 backup JSON, Capability 1 Brandfetch-key save.
- `auth0 test login` (it starts an auth flow in a browser — not a tenant mutation, but a side effect; defer it along with the writes).

**Still do the interactive asks.** The Brandfetch-key prompt in Capability 1, the source/screens/locale prompts in Capability 3, the surface/backup prompts in Capability 4 — all still happen. Plan mode defers *execution*, not *intent gathering*. For any ask whose answer triggers a write (e.g., "paste a Brandfetch key"), collect the answer and note in the plan "will save to `${XDG_CONFIG_HOME:-$HOME/.config}/auth0-branding/brandfetch.key` on approval."

**Plan contents.** Produce a complete plan covering:
- Target tenant (from `auth0 tenants list`) and the active-tenant confirmation.
- Every concrete API call the skill will make, in order: method, path, and a summary of the body (full payloads for small objects like `PATCH /branding`; key names + change counts for large ones like the merged theme object or custom-text PUTs).
- Every local file write, with absolute path.
- Scope pre-check outcome for Capability 4, so scope failures surface before approval.
- The post-apply `auth0 test login` step, if applicable.

Then call `ExitPlanMode`.

**After approval.** Normal execution resumes. All existing gates still apply: active-tenant confirmation, production-write confirmation, WCAG contrast warnings, template-tag validation, merge-before-PUT for custom text, scope checks for destructive operations.

## Verify in browser (post-apply)

After **any capability writes to the tenant** (capabilities 1–4), offer to open the live Universal Login page so the user can see the result immediately. Free-text prompt, not a picker:

> Open the login page in a browser to verify? (yes / no)

If **yes**: run `auth0 test login` on the active tenant. The CLI starts an authorization code flow against the default app and opens the browser. If the environment is headless or the browser fails to open, the CLI prints the authorize URL to stdout — capture it and pass it to the user to open manually.

If **no**: end with the summary of what was written.

Notes:
- This applies to Capability 1 (Brand my tenant), Capability 2 (Change specific settings), Capability 3 (Match my brand voice), and Capability 4 (Rollback to Auth0 defaults). In the rollback case, the browser page should render Auth0's built-in defaults — that's the verification.
- Capability 5 (Check my setup) is read-only; skip this step.
- If the user has a preferred client they test against, they'll mention it; `auth0 test login --client-id <id>` targets a specific app. Otherwise use the default.

## Key Concepts

| Concept | Description |
|---|---|
| Theme | Visual settings (colors, fonts, borders, widget layout, backgrounds) applied to Universal Login. Auth0 currently renders only the default theme; additional themes can be created via the API but are not used by Universal Login |
| Branding Settings | Tenant-level logo, favicon, primary color, and page background color |
| Page Template | Custom HTML using Liquid syntax that wraps the login widget; requires a custom domain |
| Text Customization | Per-prompt, per-screen, per-language text overrides on Universal Login pages |
| Custom Text Variables | Customer-defined keys (prefixed `var-`) in the Custom Text API, referenced from templates and partials as camelCase |
| Custom Domain | Required for page templates; maps your domain to Auth0's login pages |
| Universal Login vs Classic | Tenants can render each flow (login/signup, password reset, MFA) in either experience. Theme, template, and no-code editor only apply to flows running Universal Login |

## Prerequisites

These apply to any capability that writes to the tenant. "Check my setup" is read-only and can be run first to verify these are in place.

### CLI Tenant Context (if using the `auth0` CLI)

The Auth0 CLI is authenticated to **one tenant at a time**. All `auth0 ...` commands run against whichever tenant the CLI is currently logged into:

```bash
auth0 tenants list       # shows all tenants; the active one is marked with →
auth0 tenants use <name> # switch active tenant; prompts for browser login if not already authenticated
```

**Before any write operation in any capability, run `auth0 tenants list`, show the active tenant to the user, and get explicit confirmation to proceed.** If it's the wrong tenant, stop. Tell the user to run `auth0 tenants use <name>` (or `auth0 login` if the target isn't in the list) themselves and re-invoke the skill. Do not try to switch tenants on the user's behalf.

For non-interactive or multi-tenant automation, skip the CLI and call the **Management API** directly with an explicit domain + bearer token per call. See `references/examples.md`.

### Universal Login Active for the Flows You Want to Brand

Themes and templates only apply to flows actually running in Universal Login. Tenants can run in hybrid mode where some flows are Classic. Run Capability 5 ("Check my setup") to diagnose which flows will and won't be affected. See `references/capability-check.md` for the Classic-toggle mechanics.

### Custom Domain (only if working with page templates)

Page templates require a custom domain on the tenant. Branding settings, theme, and text customization do not. If the task involves page templates and no custom domain is configured, use the `auth0-custom-domains` skill to set one up.

## Capability 1: Brand my tenant

End-to-end branding from a website URL, inline brand values, or a short ask — fills primary color, logo, font, and page background, shows one proposal, and applies the theme.

**See `references/capability-brand.md`.**

## Capability 2: Change specific settings

Manual branding update driven by the user's natural-language intent — the skill resolves the phrase to specific fields, stages changes, and applies as a batch.

**See `references/capability-manual.md`.**

## Capability 3: Match my brand voice

Rewrite Universal Login text to match a source the user provides (website, sample copy, or voice descriptor); doesn't touch colors, layout, or logo.

**See `references/capability-voice.md`. See `references/screens.md` for the category → prompts → screens map.**

## Capability 4: Rollback to Auth0 defaults

Clear one or more branding surfaces and restore Auth0's defaults, per-surface. Destructive; always confirms before writing.

**See `references/capability-rollback.md`.**

## Capability 5: Check my setup

Read-only diagnosis. Answers "will theme changes actually show up on the flows I care about?" Safe to run first when diagnosing "why doesn't my theme show up?"

**See `references/capability-check.md`.**

## Common Mistakes

| Mistake | What to Do Instead |
|---|---|
| Creating additional themes via `POST /branding/themes` (Universal Login only renders the default theme; POSTed themes exist but never apply) | Always update the default theme: `GET /branding/themes/default`, then PATCH by its `themeId` |
| Sending a partial PATCH on a theme (PATCH requires all top-level sections) | GET the theme, apply your changes, then PATCH with the full object |
| Theme or page template changes do not appear on login/reset/MFA (a tenant-wide toggle is forcing that flow into Classic) | Run "Check my setup". Fix the offending tenant toggle: `universal_login_experience: classic` (login/signup), `change_password.enabled: true` (reset), or `guardian_mfa_page.enabled: true` (MFA) |
| Missing `auth0:head` or `auth0:widget` in templates (both are required; the page will not render without them) | Always include both; refuse the PUT otherwise |
| Using PUT for custom text without merging (PUT replaces all text for that prompt/language) | GET current text first, merge, then PUT the full object |

For the extended list (theme field requirements, Brandfetch ToS, homepage-only extraction gaps, CSS class names, CLI tenant context), see `references/api.md`.

## References

In-skill (progressive disclosure):

- `references/capability-brand.md`: "Brand my tenant" flow; extraction pipeline, source priority, Apply step
- `references/capability-manual.md`: "Change specific settings" flow; intent mapping, per-surface write mechanics, Apply/Guardrails
- `references/capability-voice.md`: "Match my brand voice" flow; source prompt, category checklist, opt-in detection, locale handling, generate-and-apply
- `references/capability-rollback.md`: "Rollback to Auth0 defaults" flow; scope pre-check, surface selection, backup, execute
- `references/capability-check.md`: "Check my setup" flow; Classic-toggle background, checks, output format
- `references/screens.md`: category → prompts → screens map for "Match my brand voice" (starting point; Auth0 adds new screens over time)
- `references/api.md`: Management API endpoints, theme/branding schema, CLI commands, error codes
- `references/examples.md`: cURL code samples plus CI/CD deployment and tenant migration patterns
- `references/advanced.md`: Page template creation with Liquid syntax, template variables, text customization details

Related skills:

- **auth0-custom-domains**: Configure custom domains (required for page templates)
- **auth0-organizations**: Organization-specific branding for B2B multi-tenancy
- **auth0-actions**: Custom logic in login flows via Auth0 Actions
- **acul-screen-generator**: Advanced Customizations for Universal Login (ACUL) — build fully custom screens beyond what theme + template can do

External:

- [Customize Universal Login](https://auth0.com/docs/customize/login-pages/universal-login)
- [Customize Themes](https://auth0.com/docs/customize/login-pages/universal-login/customize-themes)
- [Customize Page Templates](https://auth0.com/docs/customize/login-pages/universal-login/customize-templates)
- [Customize Text Elements](https://auth0.com/docs/customize/login-pages/universal-login/customize-text-elements)
- [Branding API Reference](https://auth0.com/docs/api/management/v2/branding)
- [Brandfetch Brand API](https://docs.brandfetch.com/brand-api/overview)
- [Brandfetch Logo API Guidelines](https://docs.brandfetch.com/logo-api/guidelines)
