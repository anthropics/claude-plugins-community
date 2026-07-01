# Setup Guide — Auth0 Flutter Web

## Auth0 Configuration

> **Note:** For Single Page Applications, the Auth0 Domain and Client ID are **public configuration** (not secrets). A SPA uses PKCE with no client secret, and these values are served in the browser bundle. Pass them directly to `Auth0Web(domain, clientId)`.
>
> **Agent instruction:** Check whether Auth0 credentials (domain and client ID) are already provided in the user's prompt.
> - **If credentials are provided:** Use them directly in the `Auth0Web(...)` constructor and proceed to "Post-Setup Steps".
> - **If no credentials are provided:** Follow the Auth0 CLI steps below to create the application. Do NOT ask the user to create or configure the application in the Auth0 Dashboard manually — always use the CLI.

### Create the Auth0 Application (Auth0 CLI)

> **Agent instruction:** Run these preflight checks first. Do NOT run `auth0 login` from the agent — it is interactive and will hang.
>
> 1. **Check the Auth0 CLI is installed**: `command -v auth0`. If missing, install per platform — macOS: `brew install auth0/auth0-cli/auth0`; Linux: `curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh`. See https://github.com/auth0/auth0-cli.
> 2. **Check login / active tenant**: `auth0 tenants list --json --no-input`. If it fails or returns empty:
>    - Tell the user: _"Please run `auth0 login` in your terminal and let me know when done."_
>    - Wait for confirmation, then re-run. Retry up to 3 times before treating as a persistent failure.
> 3. **Confirm the active tenant**: select the tenant where `active` is `true` from the JSON output:
>
>    ```bash
>    auth0 tenants list --json --no-input | jq -r '.[] | select(.active) | .domain'
>    ```
>
>    Tell the user: _"Your active Auth0 tenant is `<domain>`. Is this correct?"_ If not, ask them to run `auth0 tenants use <tenant-domain>`, then re-check. This domain is the `domain` value for `Auth0Web(...)`.

**Step 1 — Create the Single Page Application.** This registers the callback URL, logout URL, and web origin in one command. Use the Flutter project name (from `pubspec.yaml`) for `--name`, and `http://localhost:3000` as the local dev URL:

```bash
auth0 apps create \
  --name "My Flutter Web App" \
  --type spa \
  --callbacks "http://localhost:3000" \
  --logout-urls "http://localhost:3000" \
  --web-origins "http://localhost:3000" \
  --no-input --json
```

The JSON output includes `client_id` — this is the `clientId` value for `Auth0Web(...)`. (Before creating, you can run `auth0 apps list --json --no-input` to check for an existing SPA of the same name and reuse it.)

**Step 2 — Ensure the database connection is enabled for the app.** Most tenants already have a `Username-Password-Authentication` connection. Enable it for the new application (replace `CLIENT_ID`):

```bash
auth0 api patch "connections/CONNECTION_ID" \
  --data '{"enabled_clients":["CLIENT_ID"]}' \
  --no-input
```

> **Agent instruction:** Find `CONNECTION_ID` with `auth0 api get connections --no-input` (match `name` = `Username-Password-Authentication`). Preserve any existing `enabled_clients` by appending `CLIENT_ID` to that list. If no such connection exists, create one:
>
> ```bash
> auth0 api post connections \
>   --data '{"name":"Username-Password-Authentication","strategy":"auth0","enabled_clients":["CLIENT_ID"]}' \
>   --no-input
> ```

**Step 3 — Enable refresh token rotation** (so `offline_access` and silent renewal work) — see [Enable Refresh Token Rotation](#enable-refresh-token-rotation-recommended) below.

After these steps you have a `domain` and `client_id`. Pass them directly to `Auth0Web` (see "Using Credentials" below), then continue to the Post-Setup Steps.

### Using Credentials

Auth0 `domain` and `clientId` are **public identifiers** (not secrets) — a SPA has no client secret and these values ship in the browser bundle. Pass them directly to the `Auth0Web` constructor:

```dart
final auth0 = Auth0Web(
  'YOUR_AUTH0_DOMAIN',
  'YOUR_AUTH0_CLIENT_ID',
);
```

There is no config file (like `Auth0.plist` for iOS) and no client secret to manage.

---

## Post-Setup Steps

### Add Auth0 SPA JS to web/index.html (Required)

The `auth0_flutter` web platform depends on the Auth0 SPA JS library loaded in the browser. Add this script tag inside the `<head>` of `web/index.html`:

```html
<head>
  <!-- ... existing tags ... -->
  <script src="https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js" defer></script>
</head>
```

> **Agent instruction:**
> 1. Read `web/index.html`
> 2. Check if the Auth0 SPA JS script is already present
> 3. If not, add it inside `<head>` before the closing `</head>` tag
> 4. If `web/index.html` does not exist, check if web platform is enabled:
>    ```bash
>    flutter config --list | grep web
>    ```
>    If web is not enabled or the web directory doesn't exist:
>    ```bash
>    flutter create . --platforms=web
>    ```

### Configure Callback URLs in Auth0 Dashboard

For a Single Page Application, three URL fields must be configured:

| Field | Value | Purpose |
|-------|-------|---------|
| Allowed Callback URLs | `http://localhost:3000` | Where Auth0 redirects after login |
| Allowed Logout URLs | `http://localhost:3000` | Where Auth0 redirects after logout |
| Allowed Web Origins | `http://localhost:3000` | Required for silent token renewal via iframe |

> **Agent instruction:** Register these URLs using the Auth0 CLI:
> ```bash
> auth0 apps update CLIENT_ID \
>   --callbacks "http://localhost:3000" \
>   --logout-urls "http://localhost:3000" \
>   --web-origins "http://localhost:3000" \
>   --no-input
> ```
>
> For production, add production URLs (comma-separated):
> ```bash
> auth0 apps update CLIENT_ID \
>   --callbacks "http://localhost:3000,https://myapp.example.com" \
>   --logout-urls "http://localhost:3000,https://myapp.example.com" \
>   --web-origins "http://localhost:3000,https://myapp.example.com" \
>   --no-input
> ```

### Enable Refresh Token Rotation (Recommended)

To support `offline_access` scope and refresh tokens in SPAs:

> **Agent instruction:** Enable refresh token rotation via Auth0 CLI:
> ```bash
> auth0 api patch applications/CLIENT_ID \
>   --data '{"refresh_token":{"rotation_type":"rotating","expiration_type":"expiring","token_lifetime":2592000,"idle_token_lifetime":1296000}}' \
>   --no-input
> ```

---

## SDK Installation

> **Agent instruction:** Check the project directory for `pubspec.yaml`. If found, add the dependency:
> ```bash
> flutter pub add auth0_flutter
> ```
>
> If `pubspec.yaml` is not found, this is not a Flutter project. Ask the user for the correct project path.

### pubspec.yaml

```yaml
dependencies:
  auth0_flutter: ^2.1.0
```

After adding, run:
```bash
flutter pub get
```

### Verify Web Platform Support

Ensure the project has web platform enabled:

```bash
# Check if web directory exists
ls web/index.html

# If not, add web platform support
flutter create . --platforms=web
```

---

## Secret Management

Auth0 Flutter Web **does not use a client secret**. Single Page Applications use PKCE (Proof Key for Code Exchange) + authorization code flow, which is secure without a secret.

- `domain` and `clientId` passed to `Auth0Web()` are **not secrets** — they are public identifiers safe to commit to source control
- Access tokens and refresh tokens are stored in the **browser's in-memory cache** by the Auth0 SPA JS SDK
- No environment variables or `.env` files are needed for the Auth0 configuration
- **Never** store a client secret in frontend/web code

---

## Running the App

```bash
# Development (with consistent port for callback URLs)
flutter run -d chrome --web-port 3000

# Production build
flutter build web

# Serve production build locally for testing
cd build/web && python3 -m http.server 3000
```

> **Agent instruction:** Always use `--web-port 3000` during development to match the callback URLs registered in Auth0 Dashboard. If the user prefers a different port, update both the run command and the Auth0 Dashboard URLs.

---

## Verification

After completing setup, verify:

```bash
# 1. Build the project
flutter build web

# 2. Run locally
flutter run -d chrome --web-port 3000
```

- [ ] `auth0_flutter` is in `pubspec.yaml` dependencies
- [ ] Auth0 SPA JS script tag is in `web/index.html`
- [ ] `Auth0Web` is instantiated with your domain and client ID
- [ ] `onLoad()` is called on app startup
- [ ] Callback URLs are saved in Auth0 Dashboard
- [ ] Allowed Web Origins is configured in Auth0 Dashboard
- [ ] App builds without errors
- [ ] Login redirect works and returns to the app
