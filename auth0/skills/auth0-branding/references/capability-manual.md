# Capability 2: Change specific settings

Manual branding update driven by the user's natural-language intent. The user says what they want to change ("make the primary button orange", "change the signup headline to 'Welcome in'", "bump the corner radius to 8px", "use Inter as the font"); the skill resolves that to specific fields across theme / tenant branding settings / page template / custom text, asks a targeted disambiguation question only when the target is genuinely ambiguous, stages the change, and applies once the user is done. No URL extraction or asset parsing.

The user never needs to know the API field names or which surface a setting lives on.

## Flow

1. Load current tenant state once at the start of the session: theme (`GET /branding/themes/default`), tenant branding (`GET /branding`), and (lazily) current page template + custom text when the request targets them. Cache for the session so disambiguation prompts can show current values.
2. Ask: **"What do you want to change?"**
3. Parse the user's request and resolve it to one or more specific fields using the **Intent mapping** table below.
4. Disambiguate only when needed. If the mapped target is unique, skip ahead. If multiple fields are plausible, ask one question and show current values so the user can see what they'd be changing:
   > "'button color'; which one?
   > [a] Primary button fill (currently `#533AFD`)
   > [b] Primary button label/text (currently `#FFFFFF`)
   > [c] Secondary button border (currently `#CCCCCC`)"
5. Restate the concrete change in plain language ("change primary button fill from `#533AFD` to `#FF5733`") and confirm.
6. Stage the change in an in-memory bundle. Do not write to the tenant yet.
7. Ask **"anything else?"**; loop to step 2 if yes.
8. Show the consolidated diff of all staged changes vs current tenant state.
9. Apply as a batch; see **Apply** below.

## Intent mapping

Map freeform phrasing to the underlying surface + field. This is a starting table; cover these cases, then fall back to asking "can you describe what you see today and what you want it to look like?" if nothing matches.

| User says | Likely target |
|---|---|
| "logo" | `widget.logo_url` (theme) and `logo_url` (tenant branding). If both are set, ask which; if only one, update that one. Offer to set both if only one is set today |
| "favicon" | `favicon_url` (tenant branding) |
| "primary color" / "brand color" | Ask: theme primary button fill, tenant `colors.primary` (used on Classic pages), or both? Default to updating both if the user says "everywhere" |
| "button color" | Disambiguate fill vs label/text. If the user means a specific button (secondary, tertiary), map to the matching theme field |
| "page background" / "background color" | `colors.page_background` (solid) or `page_background.background_image_url` (image). Ask if ambiguous |
| "widget background" / "card background" | `colors.widget_background` |
| "text color" / "body text" | `colors.body_text`; disambiguate from widget title / input label if needed |
| "corner radius" / "rounded corners" / "sharper corners" | Ask which element: buttons (`borders.button_border_radius`), inputs (`borders.input_border_radius`), widget (`borders.widget_corner_radius`). If the user says "everywhere", update all three |
| "font" | `fonts.font_url` + `fonts.reference_text_size` family. Resolve the family name to a Google Fonts URL if possible (see per-surface mechanics) |
| "headline" / "title on the [login/signup/reset/...] screen" | Custom text: `{prompt}.title` on the specified screen. Confirm the prompt + screen + language |
| "description" / "subtitle on [screen]" | Custom text: `{prompt}.description` |
| "button label on [screen]" | Custom text: `{prompt}.buttonText` (or the screen-specific label key) |
| "error message for X" | Custom text: the specific error key on the relevant prompt. GET the current custom text to find the exact key name |
| "the template" / "the HTML" / "the Liquid" | Page template (`PUT /branding/templates/universal-login`) |

When the phrasing is close but not exact (e.g., "accent color", "link color", "highlight"), pick the best candidate and restate it in the confirmation step so the user can correct.

## Discoverability

If the user asks "what can I change?" or doesn't know where to start, show the surface list as a prompt, not as a required picker:

- Logo / favicon
- Colors (buttons, text, backgrounds, links)
- Fonts
- Corner radius / border style
- Page background (color or image)
- Text on a specific screen (title, description, button labels, error messages)
- Page template (HTML/Liquid)

The user can still respond in natural language from there.

## Per-surface write mechanics

Once the target is resolved, these are the mechanics for writing each surface. The user does not see these details; they're for this skill's execution.

Before staging any URL-valued field (`logo_url`, `favicon_url`, `font.url`, `widget.logo_url`, `fonts.font_url`, `page_background.background_image_url`), validate the URL resolves using the HEAD request check in `references/api.md#url-validation`. Block staging for URLs that fail. Skip validation for `cdn.brandfetch.io` URLs.

- **Logo**: Auth0 does not host uploaded assets. Ask the user for an HTTPS URL where the logo is already hosted. For theme logo: GET default theme, replace `widget.logo_url`, PATCH back. For tenant logo: `PATCH /branding` with `logo_url`. If the user only has a file, pause and ask them to host it first (their CDN, an S3 bucket, GitHub raw content, etc.).
- **Favicon**: URL only, same constraint as logo. `PATCH /branding` with `favicon_url`.
- **Color**: validate hex. Run a WCAG AA contrast check against the natural counterpart (button vs button-label, body text vs widget background, etc.). If it fails, surface the warning clearly and ask for confirmation before staging. Never block the change; accessibility is the customer's choice.
- **Font**: URL only. Resolve the family name to a Google Fonts URL if possible. If the family isn't on Google Fonts, ask the user for a reachable WOFF URL; do not silently fall back to a default.
- **Border radius / style**: plain numeric or enum update on the relevant `borders.*` field.
- **Page background**: solid color → `colors.page_background`; image → `page_background.background_image_url` (URL only, same asset-hosting constraint as logo). Clear the other if switching modes.
- **Text on a screen**: GET existing custom text for that prompt + language, merge the user's edit, PUT. Never PUT without merging; PUT replaces the full object for that prompt/language.
- **Page template**: GET current template, apply the edit, validate `auth0:head` and `auth0:widget` are still present, PUT. Refuse the write if either tag is missing.
- **Tenant branding setting**: `PATCH /branding` with just the changed keys.

## Apply

After the user finishes staging changes, batch the writes by surface:

1. All theme field changes → one `GET /branding/themes/default` + one `PATCH /branding/themes/{themeId}` with the merged full object.
2. All tenant-level branding setting changes → one `PATCH /api/v2/branding` with the merged body.
3. Page template change (if any) → one `PUT /api/v2/branding/templates/universal-login` after verifying `auth0:head` and `auth0:widget` are present.
4. Per-screen text changes → one `PUT /api/v2/prompts/{prompt}/custom-text/{lang}` per affected prompt/language (GET-merge-PUT; do not overwrite other screens in that prompt).

Before writing, show the consolidated diff **and the target tenant name** (per the "CLI Tenant Context" prerequisite in SKILL.md). Require explicit confirmation for the whole batch. Auth0 does not retain prior versions, so there is no automatic rollback; suggest the user export current state locally first if they want a backup.

After the batch completes, run the "Verify in browser (post-apply)" step from SKILL.md.

## Guardrails

- WCAG AA contrast check for any color change with a visible counterpart. Always fail-warn (never fail-block), including in production. If the color fails the contrast check, show the warning and require confirmation before staging; do not override the user's choice.
- Warn if the new font isn't on a known CDN.
- Validate page template still has `auth0:head` and `auth0:widget` after edit; refuse the PUT if either is missing. (Page-template validity IS a fail-block because the page won't render otherwise; WCAG is not.)
