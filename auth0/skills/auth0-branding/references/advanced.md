# Auth0 Branding: Page Templates and Text Customization

Advanced branding customization using Liquid page templates and per-screen text overrides.

## Page Templates

Page templates let you control the HTML structure around the Universal Login widget. They use the [Liquid template language](https://shopify.github.io/liquid/).

### Requirements

- A **custom domain** must be configured on your tenant
- Templates can only be set via the **Management API** or **CLI** (not the Dashboard)
- Every template must include `auth0:head` and `auth0:widget` tags

**API key asymmetry:** `PUT` uses the `template` key in the request body. `GET` returns the template under the `body` key. This is expected API behavior.

### Minimal Template

```html
<!DOCTYPE html>
{% assign resolved_dir = dir | default: "auto" %}
<html lang="{{locale}}" dir="{{resolved_dir}}">
  <head>
    {%- auth0:head -%}
  </head>
  <body class="_widget-auto-layout">
    {%- auth0:widget -%}
  </body>
</html>
```

Add `class="_widget-auto-layout"` on `<body>` to center the widget. Omit it to position the widget manually.

### Template with Custom Layout

```html
<!DOCTYPE html>
{% assign resolved_dir = dir | default: "auto" %}
<html lang="{{locale}}" dir="{{resolved_dir}}">
  <head>
    {%- auth0:head -%}
    <style>
      .custom-container {
        display: flex;
        min-height: 100vh;
      }
      .brand-panel {
        flex: 1;
        background: {{ branding.colors.primary }};
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        padding: 2rem;
      }
      .login-panel {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
      }
    </style>
  </head>
  <body>
    <div class="custom-container">
      <div class="brand-panel">
        <div>
          <img src="{{ branding.logo_url }}" alt="{{ tenant.friendly_name }}" />
          <h1>Welcome to {{ tenant.friendly_name }}</h1>
          {% if organization.display_name %}
            <p>Signing in as {{ organization.display_name }}</p>
          {% endif %}
        </div>
      </div>
      <div class="login-panel">
        {%- auth0:widget -%}
      </div>
    </div>
  </body>
</html>
```

### Available Template Variables

#### Application

| Variable | Description | Example |
|----------|-------------|---------|
| `application.id` | Client ID | `XXXXXXXXXXXXXXXXX` |
| `application.name` | Application name | `My Application` |
| `application.logo_url` | Application logo URL | `https://example.com/logo.png` |
| `application.metadata` | Application metadata object | `{"key": "value"}` |

#### Branding

| Variable | Description | Example |
|----------|-------------|---------|
| `branding.logo_url` | Tenant logo URL | `https://example.com/logo.png` |
| `branding.colors.primary` | Primary branding color | `#0059DB` |
| `branding.colors.page_background` | Page background color | `#FFFFFF` |

#### Tenant

| Variable | Description | Example |
|----------|-------------|---------|
| `tenant.friendly_name` | Tenant display name | `My Tenant` |
| `tenant.support_email` | Support email | `support@example.com` |
| `tenant.support_url` | Support page URL | `https://example.com/support` |
| `tenant.enabled_locales` | Enabled locale codes | `en, es` |

#### Organization (B2B)

| Variable | Description | Example |
|----------|-------------|---------|
| `organization.id` | Organization ID | `org_XXXXXXX` |
| `organization.display_name` | Display name | `Acme Corp` |
| `organization.name` | Internal name | `acme-corp` |
| `organization.branding.logo_url` | Org-specific logo | `https://acme.com/logo.png` |
| `organization.branding.colors.primary` | Org primary color | `#FF0000` |
| `organization.branding.colors.page_background` | Org background | `#FAFAFA` |

#### Current User (post-authentication screens only)

| Variable | Description |
|----------|-------------|
| `user.user_id` | User profile ID |
| `user.email` | Email address |
| `user.name` | Full name |
| `user.picture` | Profile picture URL |
| `user.email_verified` | Boolean verification status |

#### Screen Context

| Variable | Description | Example |
|----------|-------------|---------|
| `locale` | Current locale | `en-US` |
| `dir` | Text direction | `auto`, `rtl`, `ltr` |
| `prompt.name` | Current prompt | `login`, `mfa` |
| `prompt.screen.name` | Current screen | `login`, `mfa-login-options` |
| `prompt.screen.texts` | Localized screen text | `{"pageTitle": "Log In"}` |

### Template Limitations

- **CSS class names change on each Auth0 build.** Do not target internal class names; they will break.
- **HTML structure may change.** Avoid customizations that depend on the widget's internal DOM.
- **Storybook rendering**: `<script>` tags break Storybook. Workaround: `<scr` + `ipt>code</scr` + `ipt>`

## Text Customization

### Supported Prompts

Common prompts you can customize (not an exhaustive list; Auth0 supports additional prompts for MFA methods, passkeys, and other flows):

| Prompt | Screens |
|--------|---------|
| `login` | `login` |
| `login-id` | `login-id` |
| `login-password` | `login-password` |
| `signup` | `signup` |
| `signup-id` | `signup-id` |
| `signup-password` | `signup-password` |
| `consent` | `consent` |
| `mfa` | `mfa-enroll-options`, `mfa-login-options`, `mfa-otp-challenge` |
| `reset-password` | `reset-password-request`, `reset-password-email` |
| `device-flow` | `device-code-activation`, `device-code-confirmation` |

### API Behavior

The `PUT /api/v2/prompts/<prompt>/custom-text/<language>` endpoint **replaces** all custom text for that prompt and language. To update one screen without losing others, first GET the current text, merge your changes, then PUT the full object back.

`GET` returns only the keys you have explicitly set, not the full set of Auth0 default strings. An empty object (`{}`) means no custom text is set and Auth0's defaults are used.

```bash
# Get current text, modify, then set
CURRENT=$(auth0 api get "prompts/login/custom-text/en")
# Merge changes into $CURRENT
auth0 api put "prompts/login/custom-text/en" --data "$UPDATED"
```

### Delete Custom Text

Send an empty object to remove all custom text for a prompt:

```bash
auth0 api put "prompts/login/custom-text/en" --data '{}'
```
