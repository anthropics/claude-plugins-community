# Auth0 Branding: API Examples

Management API examples for configuring branding, themes, page templates, and text customization, plus patterns for CI/CD deployment and tenant migration. Auth0 Branding has no SDK-side code; all configuration is through the Management API.

## Prerequisites

- Management API access token with appropriate scopes (see `api.md` for per-endpoint scopes)
- For page templates: a custom domain configured on your tenant

## cURL examples

### Get branding settings

```bash
curl --request GET \
  --url 'https://{yourDomain}/api/v2/branding' \
  --header 'authorization: Bearer {yourMgmtApiAccessToken}'
```

### Update branding settings

```bash
curl --request PATCH \
  --url 'https://{yourDomain}/api/v2/branding' \
  --header 'authorization: Bearer {yourMgmtApiAccessToken}' \
  --header 'content-type: application/json' \
  --data '{
    "colors": {
      "primary": "#0059DB",
      "page_background": "#FFFFFF"
    },
    "logo_url": "https://example.com/logo.svg",
    "favicon_url": "https://example.com/favicon.ico",
    "font": {
      "url": "https://cdn.example.com/fonts/custom.woff"
    }
  }'
```

### Get default theme

```bash
curl --request GET \
  --url 'https://{yourDomain}/api/v2/branding/themes/default' \
  --header 'authorization: Bearer {yourMgmtApiAccessToken}'
```

### Create a theme

All top-level sections are required. Within `fonts`, `font_url` and `links_style` are required, and each font-size object requires a `bold` boolean. Within `widget`, `logo_url` is required (use `""` if no logo). Within `page_background`, `background_image_url` is required (use `""` if no image).

```bash
curl --request POST \
  --url 'https://{yourDomain}/api/v2/branding/themes' \
  --header 'authorization: Bearer {yourMgmtApiAccessToken}' \
  --header 'content-type: application/json' \
  --data '{
    "displayName": "My Theme",
    "colors": {
      "primary_button": "#0059DB",
      "primary_button_label": "#FFFFFF",
      "secondary_button_border": "#C9CACE",
      "secondary_button_label": "#1E212A",
      "base_focus_color": "#0059DB",
      "base_hover_color": "#004DB7",
      "links_focused_components": "#0059DB",
      "header": "#1E212A",
      "body_text": "#1E212A",
      "widget_background": "#FFFFFF",
      "widget_border": "#C9CACE",
      "input_labels_placeholders": "#65676E",
      "input_filled_text": "#1E212A",
      "input_border": "#C9CACE",
      "input_background": "#FFFFFF",
      "icons": "#65676E",
      "error": "#D03C38",
      "success": "#13A688"
    },
    "fonts": {
      "font_url": "",
      "links_style": "normal",
      "reference_text_size": 16,
      "title": { "size": 150, "bold": false },
      "subtitle": { "size": 87.5, "bold": false },
      "body_text": { "size": 87.5, "bold": false },
      "buttons_text": { "size": 100, "bold": false },
      "input_labels": { "size": 100, "bold": false },
      "links": { "size": 87.5, "bold": false }
    },
    "borders": {
      "button_border_weight": 1,
      "buttons_style": "rounded",
      "button_border_radius": 3,
      "input_border_weight": 1,
      "inputs_style": "rounded",
      "input_border_radius": 3,
      "widget_corner_radius": 5,
      "widget_border_weight": 0,
      "show_widget_shadow": true
    },
    "widget": {
      "logo_position": "center",
      "logo_url": "https://example.com/logo.svg",
      "logo_height": 52,
      "header_text_alignment": "center",
      "social_buttons_layout": "bottom"
    },
    "page_background": {
      "background_color": "#000000",
      "background_image_url": "",
      "page_layout": "center"
    }
  }'
```

### Update a theme

PATCH requires all top-level sections (colors, fonts, borders, widget, page_background). To change only colors, GET the current theme first, merge your changes, then PATCH the full object.

```bash
# Get current theme, then patch with full body
THEME=$(curl --request GET \
  --url 'https://{yourDomain}/api/v2/branding/themes/default' \
  --header 'authorization: Bearer {yourMgmtApiAccessToken}')

# Merge your color change into $THEME, then:
curl --request PATCH \
  --url 'https://{yourDomain}/api/v2/branding/themes/{themeId}' \
  --header 'authorization: Bearer {yourMgmtApiAccessToken}' \
  --header 'content-type: application/json' \
  --data '{
    "colors": { "primary_button": "#FF4F40", ...all other color fields... },
    "fonts": { ...all font fields... },
    "borders": { ...all border fields... },
    "widget": { ...all widget fields... },
    "page_background": { ...all page_background fields... }
  }'
```

### Set page template

```bash
curl --request PUT \
  --url 'https://{yourDomain}/api/v2/branding/templates/universal-login' \
  --header 'authorization: Bearer {yourMgmtApiAccessToken}' \
  --header 'content-type: application/json' \
  --data '{
    "template": "<!DOCTYPE html>{% assign resolved_dir = dir | default: \"auto\" %}<html lang=\"{{locale}}\" dir=\"{{resolved_dir}}\"><head>{%- auth0:head -%}</head><body class=\"_widget-auto-layout\">{%- auth0:widget -%}</body></html>"
  }'
```

### Set custom text

```bash
curl --request PUT \
  --url 'https://{yourDomain}/api/v2/prompts/login/custom-text/en' \
  --header 'authorization: Bearer {yourMgmtApiAccessToken}' \
  --header 'content-type: application/json' \
  --data '{
    "login": {
      "title": "Welcome back",
      "description": "Log in to continue to My App"
    }
  }'
```

## Deployment and migration patterns

### Export and version control

Store branding configuration in version control and deploy as part of your release pipeline.

```bash
# Export current branding settings
auth0 ul show --json > branding-settings.json

# Export current page template
auth0 ul templates show > login-template.liquid

# Export custom text for prompts you've customized
auth0 api get "prompts/login/custom-text/en" > text-login-en.json
auth0 api get "prompts/signup/custom-text/en" > text-signup-en.json
```

### Deploy branding in a pipeline

```bash
#!/bin/bash
# deploy-branding.sh
# Requires: AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET

auth0 login --client-id "$AUTH0_CLIENT_ID" \
  --client-secret "$AUTH0_CLIENT_SECRET" \
  --domain "$AUTH0_DOMAIN" --no-input

auth0 ul update \
  --logo "https://cdn.example.com/logo.svg" \
  --accent "#0059DB" \
  --background "#FFFFFF" \
  --favicon "https://cdn.example.com/favicon.ico" \
  --no-input

auth0 ul templates update --file ./branding/login-template.liquid --no-input

auth0 api put "prompts/login/custom-text/en" --data @./branding/text-login-en.json
auth0 api put "prompts/signup/custom-text/en" --data @./branding/text-signup-en.json
```

### Multi-environment layout

Keep environment-specific branding in separate config files:

```text
branding/
  base/
    theme.json          # shared theme structure
    login-template.liquid
  environments/
    dev/
      settings.json
      text-login-en.json
    staging/
      settings.json
      text-login-en.json
    production/
      settings.json
      text-login-en.json
```

### Copy branding between tenants

```bash
# Export from source tenant
AUTH0_TENANT=source-tenant.auth0.com

BRANDING=$(auth0 api get "branding" --json)
THEME=$(auth0 api get "branding/themes/default" --json 2>/dev/null)
TEMPLATE=$(auth0 api get "branding/templates/universal-login" --json 2>/dev/null)
LOGIN_TEXT=$(auth0 api get "prompts/login/custom-text/en" --json 2>/dev/null)

# Import to target tenant
AUTH0_TENANT=target-tenant.auth0.com

echo "$BRANDING" | auth0 api patch "branding" --data @-

if [ -n "$THEME" ]; then
  echo "$THEME" | auth0 api post "branding/themes" --data @-
fi

if [ -n "$TEMPLATE" ]; then
  echo "$TEMPLATE" | auth0 api put "branding/templates/universal-login" --data @-
fi

if [ -n "$LOGIN_TEXT" ]; then
  echo "$LOGIN_TEXT" | auth0 api put "prompts/login/custom-text/en" --data @-
fi
```

### Verify branding changes

```bash
# Open a test login flow in your browser
auth0 test login

# Test with a specific application
auth0 test login --client-id "{yourAppClientId}"

# Test with organization context (for B2B branding)
auth0 test login --organization org_abc123

# Verify via API
auth0 api get "branding" --json | jq '.colors'
auth0 api get "branding/themes/default" --json | jq '.colors.primary_button'
auth0 api get "branding/templates/universal-login" --json | jq '.template' | head -1
```
