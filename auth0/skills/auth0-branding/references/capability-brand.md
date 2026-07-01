# Capability 1: Brand my tenant

End-to-end branding. The tenant's theme, logo, and typography are updated to match a single source. Invoked from SKILL.md when the user asks to brand a tenant from a website or brand assets.

Scope is intentionally narrow: **four brand values** (primary color, logo URL, font family, page background) plus the target tenant. Layout, voice rewriting, and locale handling are out of the default path; users opt in to them via `[edit]` on the review.

## Start: parse input, prompt only for what's missing

Parse the user's opening message first. Only ask when the skill needs something it can't infer.

Look for:
- **A URL** (http/https, non-Figma) → use Brandfetch; see "Extract brand tokens".
- **Inline brand values** (hex codes, logo URL, font URL, design tokens, Tailwind/CSS snippets, palette) → use directly.
- **A Figma URL** → see "Figma".
- **Nothing** → one prompt:
  ```text
  Paste a website URL, or drop your brand values (primary color, logo URL,
  font). I'll propose a branding you can review before anything changes.
  ```

Tool detection is silent. The only external dependency in the default path is Brandfetch (optional). There is no Playwright/browser step; if the user wants layout fidelity, they upload a screenshot via `[edit]`.

## Extract brand tokens

Four slots to fill: **primary color, logo URL, font family, page background**. Background defaults to white; the other three come from Brandfetch when available, from the user's inline values, or from a short ask.

### Source: URL

1. Check for a stored Brandfetch key at `${XDG_CONFIG_HOME:-$HOME/.config}/auth0-branding/brandfetch.key`. This follows the XDG Base Directory spec: honor `$XDG_CONFIG_HOME` when it's set, otherwise fall back to `~/.config/`. Saves and reads use the same resolved path.
2. If no key, one-time ask:
   ```text
   One-time setup: Brandfetch gives the cleanest colors, fonts, and logos
   for URL-based branding. Free tier covers 100 lookups/month.
     [paste key]  [sign up, ~30s]  [skip]
   (Saved locally; won't ask again.)
   ```
   If skipped, persist the decision so future runs don't re-ask. The user can paste a key later with "use this Brandfetch key: <key>".
3. If a key is available: `GET https://api.brandfetch.io/v2/brands/<domain>` with `Authorization: Bearer <key>`. Map the response:
   - **Primary color**: first `colors[].type == "accent"`, else `"dark"`.
   - **Logo URL**: light-theme SVG from `logos[]` (hotlink; don't fetch server-side per Brandfetch ToS).
   - **Font family**: `fonts[].type == "body"` or `"title"`, combined with Auth0's standard fallback stack (e.g. `"<brand font>", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`).
4. If Brandfetch was skipped, unreachable, or returned an incomplete response, fall through to "ask for missing values".

### Source: inline values

Parse whatever the user pasted. Any of these is fine:
- Raw hex codes (`#0051BA` → primary color)
- A palette list (map first hex to primary)
- CSS variable snippet (`--primary: #0051BA`)
- Design tokens JSON (W3C or Figma export)
- Tailwind config fragment
- Logo URL
- Font URL (Google Fonts stylesheet or a WOFF file) or CSS font name

User-supplied values always override Brandfetch.

### Figma

Figma pages don't render server-side; a URL alone can't be scraped. If the user pastes a Figma URL:

1. **Figma MCP detected silently** (Claude Code has the server connected) → read tokens, variables, and styles directly.
2. **No Figma MCP** → one prompt:
   ```text
   I need the Figma MCP server to read a Figma file. Set it up here:
   https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Figma-MCP-server

   Or paste the brand values directly:
     primary color hex
     logo URL (hosted)
     font name
   ```

Figma typically covers colors and typography; it does not cover a hostable logo URL. The user supplies that separately.

### Ask for missing values

After all available sources have been tried, if any of the four slots is still empty, ask once in a consolidated prompt:

```text
I need a few brand values to finish the proposal (paste hex codes / URLs,
or type "skip" for any to use the Auth0 default):

  Primary color     (hex, e.g. #0051BA)
  Logo URL          (must be hosted; Auth0 does not host uploaded files)
  Font family       (CSS name, e.g. "Inter", or a Google Fonts URL)
```

Omit rows for slots that are already filled. Parse the reply in any reasonable format.

## Defaults (not extracted; not asked)

These are held constant unless the user opts in to changing them via `[edit]`:

- **Layout**: Auth0's centered single-column widget.
- **Secondary colors** (border, link, muted text): derived from the primary using standard contrast rules, or left at Auth0 defaults.
- **Voice / text**: not rewritten. Users who want text to match their brand voice run Capability 3 ("Match my brand voice") as a separate step.
- **Locales**: existing enabled locales are unaffected.

## Propose

Single proposal, single free-text review prompt. Always include the "Also available" block so users can see what else is editable.

```text
Proposed branding for ikea.com:

  Primary color      #0051BA      (from Brandfetch)
  Button label       #FFFFFF      (derived from primary contrast)
  Page background    #FFFFFF
  Body text          #111111      (Auth0 default)
  Typography         Noto IKEA, Noto Sans, system-ui
                                  (from Brandfetch; browser loads
                                   Noto Sans as the hostable fallback)
  Logo               https://cdn.brandfetch.io/...

  Layout             centered single-column  (Auth0 default)

Also available (off unless you ask):
  Page template      off           (paste HTML/Liquid; needs a custom domain)
  Layout override    off           (upload a screenshot for a vision-based pass)
  Voice rewriting    off           (rewrite login text in the brand's voice after apply)

Target tenant: acme-prod (active in Auth0 CLI)
```
> Proceed? (apply / edit / cancel, or tell me what to change.)

Show provenance inline (`(from Brandfetch)`, `(you supplied)`, `(Auth0 default)`) so the user can tell at a glance what came from where.

### Parsing the review reply

The review reply is free text. Handle these cases:

- **Clear apply** (`"apply"`, `"y"`, `"yes"`, `"go"`, `"ship it"`) → jump to "Confirm target tenant".
- **Clear cancel** (`"cancel"`, `"n"`, `"no"`, `"stop"`) → abort; no writes.
- **Bare "edit"** with no specifics → print the list of editable knobs (everything in the proposal plus the "Also available" items) and wait for the next reply.
- **Named edits** (`"change primary to #181818"`, `"enable voice rewriting"`, `"use Inter as the font and dark background"`, `"paste this template: ..."`) → update the relevant slots, re-render the proposal, ask `Proceed?` again.
- **Ambiguous** ("make it darker", "looks fine but the logo is wrong") → ask one short clarifying question in free text; don't kick back to a picker.

Editable knobs and what each reply means:

| Reply pattern | Slot to update |
|---|---|
| `primary color <hex>`, `brand color <hex>`, `make the primary <hex>` | `colors.primary_button` (theme) and `colors.primary` (tenant branding) |
| `logo <url>`, `use this logo <url>` | `widget.logo_url` (theme) and `logo_url` (tenant branding) |
| `font <name>` or `font <google-fonts-url>` | `fonts.font_url` (theme) after resolving family |
| `background <hex>` | `colors.page_background` (tenant branding) and `page_background.background_color` (theme) |
| Uploaded screenshot + "match this layout" | Layout override: run vision pass, map to theme knobs (widget position, page background, border style) |
| Pasted HTML/Liquid block | Page template override: verify `auth0:head` and `auth0:widget` are present, stage for apply. Requires a custom domain — warn if none is configured. |
| `enable voice rewriting`, `rewrite the copy too`, `also match the voice` | Set voice flag on. After apply, delegate to `capability-voice.md`. If the tenant has more than one enabled locale, that capability asks whether to rewrite all locales or English only. |

## Confirm target tenant

Before any write, run `auth0 tenants list` and present the active tenant:

```text
Target tenant: acme-prod  (active in the Auth0 CLI)

  [y] apply to acme-prod
  [n] cancel
```

If it's the wrong tenant, cancel. Tell the user to run `auth0 tenants use <name>` (or `auth0 login`) themselves and re-invoke the skill. Do not try to switch tenants on the user's behalf.

For non-interactive / multi-tenant workflows, accept an explicit tenant domain + bearer token inline instead of the CLI; see `references/examples.md`.

## Apply

Execute based on what the user approved in the review:

Before writing, validate any URL-valued fields (logo, favicon, font, background image) using the HEAD request check in `references/api.md#url-validation`. Block writes for URLs that fail. Skip validation for `cdn.brandfetch.io` URLs.

1. **Tenant branding settings** (logo, favicon, primary color, page background): `PATCH /api/v2/branding`.
2. **Theme** (colors, fonts, widget): `GET /branding/themes/default` → merge → `PATCH /branding/themes/{themeId}` with the full object. Partial PATCH is not supported; always send the full theme.
3. **Page template** (only if the user pasted one via `[edit]` AND the tenant has a custom domain): `PUT /api/v2/branding/templates/universal-login`. Refuse the PUT if the template is missing `auth0:head` or `auth0:widget`.
4. **Voice rewrites** (only if `[edit] → voice rewriting` was enabled): hand off to `capability-voice.md` with the primary-color/font context so it doesn't re-ask.

Before writing, diff the proposed changes against current tenant state. In production environments, require explicit confirmation. Auth0 does not retain prior theme/template/text versions; if the user wants a backup, suggest exporting current state locally before applying (see the backup flow in `capability-rollback.md`).

Report what was written and what was skipped (for example, "page template skipped — no custom domain configured"). If voice rewriting was opted in, chain into Capability 3 after the theme write succeeds.

After reporting (and after voice rewriting chains complete, if enabled), run the "Verify in browser (post-apply)" step from SKILL.md.
