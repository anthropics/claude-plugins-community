# Auth0 PHP Setup Guide

Setup instructions for PHP web applications.

---

## Quick Setup (Automated)

Below automates the setup, except for the CLIENT_SECRET. Inform the user that they have to fill in the value for the CLIENT_SECRET themselves.

**Never read the contents of `.env.local` or `.env` at any point during setup.** The file may contain sensitive secrets that should not be exposed in the LLM context. If you determine you need to read the file for any reason, ask the user for explicit permission before doing so - do not proceed until the user confirms.

**Before running any part of this setup that writes to an env file, you MUST ask the user for explicit confirmation.** Follow the steps below precisely.

### Step 1: Check for existing env files and confirm with user

Before writing credentials, check which env files exist:

```bash
test -f .env.local && echo "ENV_LOCAL_EXISTS" || echo "ENV_LOCAL_NOT_FOUND"
test -f .env && echo "ENV_EXISTS" || echo "ENV_NOT_FOUND"
```

Then determine the target file using this precedence: `.env.local` (if present), otherwise `.env`. Ask the user for explicit confirmation before proceeding - do not continue until the user confirms:

- If the target file (`.env.local` or `.env`) exists, ask:
  - Question: "A `<target file>` already exists and may contain secrets unrelated to Auth0. This setup will append Auth0 credentials without modifying existing content. Do you want to proceed?"
  - Options: "Yes, append to existing `<target file>`" / "No, I'll update it manually"

- If neither file exists, ask:
  - Question: "This setup will create a `.env` file containing Auth0 credentials (AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_COOKIE_SECRET, AUTH0_REDIRECT_URI) and a placeholder for AUTH0_CLIENT_SECRET. Do you want to proceed?"
  - Options: "Yes, create .env" / "No, I'll configure it manually"

**Do not proceed with writing to any env file unless the user selects the confirmation option.**

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
  APP_ID=$(auth0 apps create --name "${PWD##*/}-php" --type regular \
    --callbacks "http://localhost:3000/callback" \
    --logout-urls "http://localhost:3000" \
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
COOKIE_SECRET=$(openssl rand -hex 32)

# Determine target env file
if [ -f .env.local ]; then
  TARGET_FILE=".env.local"
elif [ -f .env ]; then
  TARGET_FILE=".env"
else
  TARGET_FILE=".env"
fi

# Append Auth0 credentials
cat >> "$TARGET_FILE" << ENVEOF

# Auth0 Configuration
AUTH0_DOMAIN=$DOMAIN
AUTH0_CLIENT_ID=$CLIENT_ID
AUTH0_CLIENT_SECRET='YOUR_CLIENT_SECRET'
AUTH0_COOKIE_SECRET=$COOKIE_SECRET
AUTH0_REDIRECT_URI=http://localhost:3000/callback
ENVEOF

echo "Auth0 credentials written to $TARGET_FILE"
```

After the script runs, remind the user to:
1. Open the env file that was written and replace `YOUR_CLIENT_SECRET` with the actual client secret from Auth0.
2. Ensure the env file is listed in `.gitignore` to avoid accidentally committing secrets.

---

## Manual Setup

### Install Packages

```bash
composer require auth0/auth0-php vlucas/phpdotenv guzzlehttp/guzzle guzzlehttp/psr7
```

**Package breakdown:**
- `auth0/auth0-php` - The Auth0 SDK
- `vlucas/phpdotenv` - Load `.env` files
- `guzzlehttp/guzzle` - PSR-18 HTTP client (required by the SDK)
- `guzzlehttp/psr7` - PSR-7 HTTP messages (required by the SDK)

### Create .env

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
AUTH0_COOKIE_SECRET=<openssl-rand-hex-32>
AUTH0_REDIRECT_URI=http://localhost:3000/callback
```

### Get Auth0 Credentials

CLI: `auth0 apps show <app-id> --reveal-secrets`

Dashboard: Applications > Your App > Settings, copy Domain, Client ID, Client Secret

---

## PHP Version Requirements

- PHP 8.2 or higher
- Required extensions: `mbstring`, `openssl`, `json`
- Verify with: `php -v && php -m | grep -E "mbstring|openssl|json"`

---

## PSR Dependencies

The SDK uses PSR auto-discovery (`psr-discovery/all`) to find compatible HTTP implementations. If you install `guzzlehttp/guzzle`, it satisfies all PSR requirements automatically.

If you prefer a different HTTP client:
- **Symfony HTTP Client**: `composer require symfony/http-client nyholm/psr7`
- **PHP-HTTP Curl**: `composer require php-http/curl-client nyholm/psr7`

---

## Troubleshooting

**"No PSR-18 HTTP Client found":** Install `guzzlehttp/guzzle` or another PSR-18 compatible client.

**"Invalid state" error:** Regenerate `AUTH0_COOKIE_SECRET` with `openssl rand -hex 32`

**"Client secret required":** Ensure you created a Regular Web Application (not SPA) in Auth0.

**Callback URL mismatch:** Add `http://localhost:3000/callback` to Allowed Callback URLs in Auth0 Dashboard.

**Cookie not persisting:** Ensure `cookieSecure` is `false` for local development (HTTP). Set to `true` only in production with HTTPS.

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
