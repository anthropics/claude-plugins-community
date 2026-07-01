# Auth0 Laravel Setup Guide

Setup instructions for Laravel web applications.

---

## Quick Setup (Automated)

Below automates the setup, except for the CLIENT_SECRET. Inform the user that they have to fill in the value for the CLIENT_SECRET themselves.

**Never read the contents of `.env` at any point during setup.** The file may contain sensitive secrets that should not be exposed in the LLM context. If you determine you need to read the file for any reason, ask the user for explicit permission before doing so - do not proceed until the user confirms.

**Before running any part of this setup that writes to an env file, you MUST ask the user for explicit confirmation.** Follow the steps below precisely.

### Step 1: Check for existing env file and confirm with user

Before writing credentials, check if `.env` exists:

```bash
test -f .env && echo "ENV_EXISTS" || echo "ENV_NOT_FOUND"
```

Then ask the user for explicit confirmation before proceeding - do not continue until the user confirms:

- If `.env` exists, ask:
  - Question: "A `.env` file already exists and may contain secrets unrelated to Auth0. This setup will append Auth0 credentials without modifying existing content. Do you want to proceed?"
  - Options: "Yes, append to existing .env" / "No, I'll update it manually"

- If `.env` does not exist, ask:
  - Question: "This setup will create a `.env` file. However, Laravel projects typically already have one from `cp .env.example .env`. Should I create it, or would you prefer to add Auth0 variables manually?"
  - Options: "Yes, create .env" / "No, I'll configure it manually"

**Do not proceed with writing to the env file unless the user selects the confirmation option.**

### Step 2: Run automated setup (only after confirmation)

```bash
#!/bin/bash

# Install Auth0 CLI
if ! command -v auth0 &> /dev/null; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install auth0/auth0-cli/auth0
  else
    curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh -o /tmp/auth0-install.sh
    echo "Review the install script at /tmp/auth0-install.sh before running"
    sh /tmp/auth0-install.sh -b /usr/local/bin
    rm /tmp/auth0-install.sh
  fi
fi

# Verify jq is available (used to parse JSON from Auth0 CLI)
if ! command -v jq &> /dev/null; then
  echo "jq is required but not installed. Install it: https://jqlang.github.io/jq/download/" >&2
  exit 1
fi

# Login
auth0 login 2>/dev/null || auth0 login

# Create/select app
auth0 apps list
read -p "Enter app ID (or Enter to create): " APP_ID

if [ -z "$APP_ID" ]; then
  APP_URL="http://localhost:8000"
  APP_ID=$(auth0 apps create --name "${PWD##*/}-laravel" --type regular \
    --callbacks "${APP_URL}/callback" \
    --logout-urls "${APP_URL}" \
    --metadata "created_by=agent_skills" \
    --json | jq -r '.client_id')
fi

# Get credentials
APP_JSON=$(auth0 apps show "$APP_ID" --json)
DOMAIN=$(printf '%s' "$APP_JSON" | jq -r '.domain')
CLIENT_ID=$(printf '%s' "$APP_JSON" | jq -r '.client_id')

if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ] || [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "null" ]; then
  echo "Failed to resolve Auth0 app credentials from CLI output" >&2
  exit 1
fi

# Append Auth0 credentials to .env
cat >> .env << ENVEOF

# Auth0 Configuration
AUTH0_DOMAIN=$DOMAIN
AUTH0_CLIENT_ID=$CLIENT_ID
AUTH0_CLIENT_SECRET='YOUR_CLIENT_SECRET'
AUTH0_AUDIENCE='YOUR_API_IDENTIFIER'
AUTH0_REDIRECT_URI=\${APP_URL}/callback
ENVEOF

echo ""
echo "Auth0 credentials written to .env"
echo ""
echo "IMPORTANT:"
echo "  1. Replace 'YOUR_CLIENT_SECRET' with your actual client secret."
echo "     Find it in: Auth0 Dashboard > Applications > $CLIENT_ID > Settings > Client Secret"
echo "  2. Replace 'YOUR_API_IDENTIFIER' with your API audience."
echo "     Find it in: Auth0 Dashboard > Applications > APIs > API Audience"
echo "     (Without this, Auth0 returns opaque tokens that crash the SDK)"
```

---

## Manual Setup

### 1. Install the package

```bash
composer require auth0/login guzzlehttp/guzzle guzzlehttp/psr7
```

### 2. Publish configuration

```bash
php artisan vendor:publish --tag=auth0
```

### 3. Generate APP_KEY (if not set)

```bash
php artisan key:generate
```

The SDK uses `APP_KEY` as the cookie encryption secret. Ensure it is set before testing.

### 4. Add Auth0 variables to `.env`

Ensure `APP_URL` includes the port for the dev server:

```bash
APP_URL=http://localhost:8000
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
AUTH0_AUDIENCE=https://your-api-identifier
AUTH0_REDIRECT_URI=${APP_URL}/callback
```

`AUTH0_AUDIENCE` must be set to an API identifier from Auth0 Dashboard > Applications > APIs. Without it, Auth0 returns opaque access tokens that the SDK cannot decode, causing a "JWT string must contain two dots" error on session restore.

### 5. Configure guards in `config/auth.php`

```php
'guards' => [
    'web' => [
        'driver' => 'auth0.authenticator',
        'provider' => 'auth0-provider',
        'configuration' => 'web',
    ],
],

'providers' => [
    'auth0-provider' => [
        'driver' => 'auth0.provider',
        'repository' => 'auth0.repository',
    ],
],
```

### 6. Configure Auth0 Dashboard

In your Auth0 Application settings:
- **Application Type**: Regular Web Application
- **Allowed Callback URLs**: `http://localhost:8000/callback`
- **Allowed Logout URLs**: `http://localhost:8000`

### 7. Test

```bash
php artisan serve
```

Visit `http://localhost:8000/login` to verify the flow.

---

## New Laravel Project Setup

For starting fresh:

```bash
composer create-project laravel/laravel my-app
cd my-app
composer require auth0/login guzzlehttp/guzzle guzzlehttp/psr7
php artisan vendor:publish --tag=auth0
php artisan key:generate
```

Then follow the Manual Setup from step 4 onwards.

---

## Configuration Reference

The published `config/auth0.php` contains:

| Key | Default | Description |
|-----|---------|-------------|
| `registerGuards` | `true` | Auto-register Auth0 guard drivers |
| `registerMiddleware` | `true` | Auto-register Auth0 middleware |
| `registerAuthenticationRoutes` | `true` | Auto-register `/login`, `/callback`, `/logout` |
| `guards.web.strategy` | `STRATEGY_REGULAR` | Session-based authentication |
| `guards.web.cookie_secret` | `APP_KEY` | Encryption key for session cookies |
| `guards.web.redirect_uri` | `${APP_URL}/callback` | OAuth callback URL |
| `routes.login` | `/login` | Login route path |
| `routes.callback` | `/callback` | Callback route path |
| `routes.logout` | `/logout` | Logout route path |
| `routes.after_login` | `/` | Redirect after login |
| `routes.after_logout` | `/` | Redirect after logout |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Driver [auth0.authenticator] not supported" | Ensure `auth0/login` is installed and service provider is auto-discovered |
| "Redirect URL mismatch" | `AUTH0_REDIRECT_URI` must match Allowed Callback URLs in Auth0 Dashboard exactly |
| Session not persisting | Ensure `APP_KEY` is set (`php artisan key:generate`) |
| "Class Auth0\Laravel\ServiceProvider not found" | Run `composer dump-autoload` |
| CSRF token mismatch on callback | Use the SDK's auto-registered routes (they handle CSRF correctly). Do not add CSRF exceptions manually |
| Login redirects back to login page | Check that `config/auth.php` uses `auth0.authenticator` driver |
