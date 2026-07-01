# Auth0 Branding: API Reference

Complete Management API endpoints, CLI commands, configuration options, and error handling for Auth0 Branding.

## Management API Endpoints

### Branding Settings

| Method | Path | Description | Scopes |
|--------|------|-------------|--------|
| GET | `/api/v2/branding` | Get branding settings (logo, colors, favicon, font) | `read:branding` |
| PATCH | `/api/v2/branding` | Update branding settings | `update:branding` |

### Branding Themes

| Method | Path | Description | Scopes |
|--------|------|-------------|--------|
| POST | `/api/v2/branding/themes` | Create a new theme | `create:branding` |
| GET | `/api/v2/branding/themes/default` | Get the default theme | `read:branding` |
| GET | `/api/v2/branding/themes/{themeId}` | Get a specific theme | `read:branding` |
| PATCH | `/api/v2/branding/themes/{themeId}` | Update a theme | `update:branding` |
| DELETE | `/api/v2/branding/themes/{themeId}` | Delete a theme | `delete:branding` |

**Theme behavior notes:**
- `GET /branding/themes/default` returns 404 if no theme has been created yet. Create one with POST first.
- PATCH requires all top-level sections (`colors`, `fonts`, `borders`, `widget`, `page_background`). To update one field, GET the current theme, merge your change, then PATCH the full object.
- Each theme has a `displayName` string field (optional, used for identification).
- The response includes a `themeId` string used in subsequent PATCH/DELETE calls.

### Universal Login Templates

| Method | Path | Description | Scopes |
|--------|------|-------------|--------|
| GET | `/api/v2/branding/templates/universal-login` | Get page template | `read:branding` |
| PUT | `/api/v2/branding/templates/universal-login` | Set page template | `update:branding` |
| DELETE | `/api/v2/branding/templates/universal-login` | Delete page template | `delete:branding` |

### Custom Text (Prompts)

| Method | Path | Description | Scopes |
|--------|------|-------------|--------|
| GET | `/api/v2/prompts/<prompt>/custom-text/<language>` | Get custom text | `read:prompts` |
| PUT | `/api/v2/prompts/<prompt>/custom-text/<language>` | Set custom text (replaces all) | `update:prompts` |

## CLI Commands

### Branding Settings

```bash
# View current branding configuration
auth0 ul show
auth0 ul show --json

# Update branding (interactive)
auth0 ul update

# Update branding (non-interactive)
auth0 ul update --accent "#0059DB" --background "#FFFFFF" \
  --logo "https://example.com/logo.svg" \
  --favicon "https://example.com/favicon.ico" \
  --font "https://cdn.example.com/fonts/custom.woff"
```

### Page Templates

```bash
# View current page template
auth0 ul templates show

# Update page template from file
auth0 ul templates update --file login.liquid

# Update page template (interactive)
auth0 ul templates update
```

### Custom Text

```bash
# View custom text for a prompt
auth0 ul prompts show login
auth0 ul prompts show signup -l es

# Update custom text (interactive)
auth0 ul prompts update login
auth0 ul prompts update signup -l es
```

### Customization Editor

```bash
# Open the browser-based customization editor
auth0 ul customize

# Switch between standard and advanced rendering modes
auth0 ul switch
```

### Testing

```bash
# Test your login flow in a browser
auth0 test login

# Test with specific client
auth0 test login --client-id "{appClientId}"

# Test with organization context
auth0 test login --organization org_abc123
```

## Branding Settings Properties

| Property | Type | Description |
|----------|------|-------------|
| `colors.primary` | string | Primary accent color (hex, e.g., `#0059DB`) |
| `colors.page_background` | string | Page background color (hex) |
| `logo_url` | string | URL to brand logo (HTTPS required; SVG recommended) |
| `favicon_url` | string | URL to favicon (HTTPS required) |
| `font.url` | string | URL to custom WOFF font file (HTTPS, CORS-enabled host required) |

## Theme Configuration Properties

### Colors (20+ elements)

| Property | Description |
|----------|-------------|
| `primary_button` | Primary button fill color |
| `primary_button_label` | Primary button text color |
| `secondary_button_border` | Secondary button / input field border |
| `secondary_button_label` | Secondary button text color |
| `links_focused_components` | Link and focus indicator color |
| `base_focus_color` | Hover state color |
| `base_hover_color` | Click state color |
| `header` | Header text color |
| `body_text` | Body text color |
| `widget_background` | Widget background color |
| `widget_border` | Widget border color |
| `input_labels_placeholders` | Input label and placeholder text color |
| `input_filled_text` | Typed input text color |
| `input_border` | Input field border color |
| `input_background` | Input field background color |
| `icons` | Input field icon color |
| `error` | Error message color |
| `success` | Success message color |

### Fonts

`font_url` and `links_style` are required. Each font-size object (`title`, `subtitle`, `body_text`, `buttons_text`, `input_labels`, `links`) requires both `size` and `bold`.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `font_url` | string | Yes | WOFF file URL (CORS-enabled host); use `""` for system font |
| `links_style` | string | Yes | Link style: `"normal"` or `"italic"` |
| `reference_text_size` | number | Yes | Base text size in pixels |
| `title.size` | number | Yes | Title size (% of reference) |
| `title.bold` | boolean | Yes | Whether title is bold |
| `subtitle.size` | number | Yes | Subtitle size (% of reference) |
| `subtitle.bold` | boolean | Yes | Whether subtitle is bold |
| `body_text.size` | number | Yes | Body text size (% of reference) |
| `body_text.bold` | boolean | Yes | Whether body text is bold |
| `buttons_text.size` | number | Yes | Button text size (% of reference) |
| `buttons_text.bold` | boolean | Yes | Whether button text is bold |
| `input_labels.size` | number | Yes | Input label size (% of reference) |
| `input_labels.bold` | boolean | Yes | Whether input labels are bold |
| `links.size` | number | Yes | Link text size (% of reference) |
| `links.bold` | boolean | Yes | Whether links are bold |

### Borders

| Property | Type | Description |
|----------|------|-------------|
| `button_border_weight` | number | Button border width (px) |
| `buttons_style` | string | `"sharp"`, `"rounded"`, or `"pill"` |
| `button_border_radius` | number | Button corner radius (rounded only) |
| `input_border_weight` | number | Input border width (px) |
| `inputs_style` | string | `"sharp"`, `"rounded"`, or `"pill"` |
| `input_border_radius` | number | Input corner radius (rounded only) |
| `widget_corner_radius` | number | Widget corner radius (px) |
| `widget_border_weight` | number | Widget border width (px) |
| `show_widget_shadow` | boolean | Enable widget shadow |

### Widget

`logo_url` is required (use `""` if no logo).

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `logo_position` | string | Yes | `"left"`, `"right"`, `"center"`, or `"none"` |
| `logo_url` | string | Yes | Logo URL (SVG recommended); use `""` for no logo |
| `logo_height` | number | Yes | Logo height in pixels |
| `header_text_alignment` | string | Yes | `"left"`, `"right"`, or `"center"` |
| `social_buttons_layout` | string | Yes | `"top"` or `"bottom"` |

### Page Background

`background_image_url` is required (use `""` if no background image).

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `background_color` | string | Yes | Background color (hex) |
| `background_image_url` | string | Yes | Background image URL (JPEG, min 2000px wide recommended); use `""` for no image |
| `page_layout` | string | Yes | Widget position: `"left"`, `"right"`, or `"center"` |

## Error Handling

| HTTP Status | Cause | Resolution |
|-------------|-------|------------|
| 400 | Invalid request body (bad hex color, invalid URL, missing required field) | Check request body against schema |
| 401 | Missing or expired access token | Refresh your Management API token |
| 403 | Token lacks required scope | Add the required scope to your token (e.g., `update:branding`) |
| 404 | Theme not found (invalid themeId) or no template set | Verify the themeId exists; use GET first |
| 409 | Template requires custom domain but none configured | Configure a custom domain before setting templates |
| 429 | Rate limited | Back off and retry; Management API has per-endpoint rate limits |

## URL Validation

Before writing any URL-valued branding field to the tenant, verify the URL resolves. Use a HEAD request so no content is downloaded:

```bash
curl -s -o /dev/null -w "%{http_code}" --max-time 5 -I "<url>"
```

**Pass**: 2xx or 3xx response → proceed with the write.
**Fail**: 4xx, 5xx, or connection timeout → block the write and tell the user which URL failed and what status was returned.

**Fields this applies to:**

| Field | API location |
|---|---|
| `logo_url` | `PATCH /branding` |
| `favicon_url` | `PATCH /branding` |
| `font.url` | `PATCH /branding` |
| `widget.logo_url` | theme PATCH |
| `fonts.font_url` | theme PATCH |
| `page_background.background_image_url` | theme PATCH |

**Exception — Brandfetch CDN URLs** (`cdn.brandfetch.io`): skip validation. These are browser hotlinks that may reject server-side HEAD requests even when valid. They are always written as-is.

## Extended gotchas

These complement the top-5 table in SKILL.md with longer-tail edge cases that tend to surface during real work.

| Gotcha | What to do |
|---|---|
| `GET /branding/themes/default` returns 404, or 200 with all fields null | 404 means the tenant has never had a theme. 200-with-nulls means a theme existed and was deleted. Treat either as "no theme applied." Inspect the response body; don't trust the status alone. Create or restore via `POST /branding/themes`, or PATCH the default once one exists |
| Omitting required fields on theme create (`fonts.font_url`, `fonts.links_style`, each font element's `bold`, `widget.logo_url`, `page_background.background_image_url`) | Use `""` for URL fields when no custom value is needed; set `bold: false` on each font element. All top-level sections (colors, fonts, borders, widget, page_background) must be present |
| Targeting CSS class names in page templates | Auth0 regenerates class names on each build; custom CSS keyed off internal classes will break. Use the theme API or no-code editor for styling, and page templates only for structure around the widget |
| Assuming there is a per-client toggle for Classic login | There isn't. Classic vs Universal is tenant-wide for every flow. Login/signup is driven by `GET /prompts` → `universal_login_experience` (new/classic); password reset by `change_password.enabled` on tenant settings; MFA by `guardian_mfa_page.enabled`. All three apply to every client in the tenant |
| Extracting brand only from the homepage in Capability 1 | Homepage gives brand identity; the login page gives layout. Follow the login link before capturing layout; see `references/capability-brand.md` Stage 1 |
| Fetching Brandfetch logos server-side | Violates Brandfetch ToS. Use the hotlink pattern `https://cdn.brandfetch.io/<domain>?c=<client-id>` in `widget.logo_url`; the browser fetches at render time |
| `PUT` template uses key `template`; `GET` template returns key `body` | Expected API asymmetry. When round-tripping (GET → edit → PUT), remap before the PUT |
