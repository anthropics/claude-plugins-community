# Capability 4: Rollback to Auth0 defaults

Clear one or more branding surfaces and restore Auth0's defaults. Reset is per-surface, not all-or-nothing. Destructive; always confirm before writing.

## Scope pre-check (before asking anything)

If the user selected **Theme** or **Page template** to reset, those operations require the `delete:branding` scope. Check for it immediately — before backup, before confirm — by attempting a benign scoped call:

```bash
auth0 api get "branding/themes/default"
```

- If the call returns a theme: a `DELETE` will be needed. Verify scope by making a deliberate no-op `DELETE` attempt on a known-nonexistent themeId (e.g., `branding/themes/scope-check-probe`) — a `403` with `"access token lacks scope: delete:branding"` confirms the scope is missing; a `404` ("not found") confirms the scope is present.
- If the call returns 404: no theme to delete; scope check is moot for theme. Repeat the same probe for page template if that surface was selected.

> **Why probe instead of decoding the JWT:** Management API tokens issued to the CLI aren't always JWTs the skill can decode locally (opaque tokens are valid too), and scope claims in a decoded JWT can lag the tenant's actual grants. The probe tests the live gate. Caveats: the 403 check matches on error message text; if Auth0 ever changes the wording, update the substring here. The probe id (`scope-check-probe`) is reserved-looking on purpose, but if a real theme with that id ever exists the probe will succeed and the scope check will falsely report "present" — swap to a random UUID if that becomes a concern.

**If the scope is missing**, surface a clear warning before doing anything else:

> "Your current token is missing the `delete:branding` scope, which is required to delete the theme/page template. To avoid a mid-run failure, re-authenticate first:
>
> `auth0 login --scopes delete:branding`
>
> Run that command (prefix with `!` in Claude Code), then re-invoke this capability."

Stop and do not proceed until the scope issue is resolved. Do not fall through to backup or confirm steps with a known-failing scope.

## Ask what to reset

Use two sequential `AskUserQuestion` calls. Do not render a text checklist.

**Call 1 — surfaces to reset** (`multiSelect: true`):
- `question`: "Which pieces should I reset to Auth0 defaults?"
- `header`: "Reset"
- options:

| label | description |
|---|---|
| Tenant branding settings | logo, favicon, primary color, page background |
| Theme | colors, fonts, borders, widget layout, page backgrounds |
| Page template | HTML/Liquid |
| Custom text on prompts | I'll ask which prompts to clear after you confirm |

**Call 2 — backup** (single select):
- `question`: "Save a backup of the selected surfaces before resetting?"
- `header`: "Backup"
- options:

| label | description |
|---|---|
| Yes, save a backup first (Recommended) | I'll write current state to a local JSON file you can restore from manually |
| No, reset without a backup | One-way; Auth0 does not retain prior versions |

For custom text, after the user picks the surfaces, list prompts that currently have overrides and ask which to clear (or "all"). Show the locales those overrides cover so the user knows the scope.

Reset is destructive and one-way. Auth0 does not maintain prior versions of themes, templates, or custom text, so the "save to a file" option is the only way to keep a copy of current state before reset.

## Confirm

Show the concrete plan, including the target tenant (per the "CLI Tenant Context" prerequisite in SKILL.md):

```text
Target tenant: acme-prod  (active in the Auth0 CLI)

I'll reset the following:
  • Theme (current themeId abc123 → deleted; Universal Login will fall back to Auth0's defaults)
  • Custom text on prompts: login, signup-id (locales: en, fr)

Tenant branding settings, page template, and other prompts will be left alone.

Backup: I'll save the current state of the selected surfaces to:
  ~/auth0-branding-backup-<tenant>-<YYYY-MM-DD_HHMMSS>.json
(Override the path or cancel the backup?)

Proceed?
  [y] Yes
  [n] Cancel
```

If the user opted in to save-to-file, ask for a path or accept the default (`~/auth0-branding-backup-<tenant>-<timestamp>.json`). Confirm the path is writable before proceeding. If the user skipped the backup option, omit that block and surface a brief warning that this is one-way.

In production environments, require explicit confirmation before any write.

## Execute (only for surfaces the user selected)

0. **Save backup (if opted in)**: before any writes, fetch the current state of every selected surface and serialize to a single JSON file at the path the user confirmed.
   - Theme: `GET /branding/themes/default` (full theme object)
   - Page template: `GET /branding/templates/universal-login`
   - Custom text: for each selected prompt + locale, `GET /prompts/{prompt}/custom-text/{lang}`
   - Tenant branding: `GET /branding`
   - Write the combined object as pretty-printed JSON with a top-level `tenant`, `timestamp`, and `surfaces` map. Refuse to proceed with reset if the write fails.
1. **Theme**: `DELETE /api/v2/branding/themes/{themeId}`. After delete, `GET /branding/themes/default` returns 404 and Universal Login renders Auth0's built-in defaults.
2. **Page template**: `DELETE /api/v2/branding/templates/universal-login`.
3. **Custom text**: for each selected prompt + locale, `PUT /api/v2/prompts/{prompt}/custom-text/{lang}` with `{}` (empty object) to clear overrides.
4. **Tenant branding settings**: `PATCH /api/v2/branding` with nulls/defaults for only the fields reset (don't clobber anything the user didn't select).

Report what was reset, what was left alone, and (if saved) the full path to the backup file so the user can find it later.

After the report, run the "Verify in browser (post-apply)" step from SKILL.md. In the rollback case, the browser should render Auth0 built-in defaults; that's the verification.
