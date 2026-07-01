# Auth0 PHP API Setup Guide

Setup instructions for PHP API applications using `auth0/auth0-php` in API mode.

---

## Quick Setup (Automated)

Below automates the setup using the Auth0 CLI.

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
  - Question: "This setup will create a `.env` file containing Auth0 credentials (AUTH0_DOMAIN, AUTH0_AUDIENCE). Do you want to proceed?"
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

# Create API resource
API_JSON=$(auth0 apis create \
  --name "${PWD##*/}-api" \
  --identifier "https://${PWD##*/}.example.com" \
  --json)

AUDIENCE=$(printf '%s' "$API_JSON" | jq -r '.identifier')
if [ -z "$AUDIENCE" ] || [ "$AUDIENCE" = "null" ]; then
  echo "Failed to resolve API identifier from CLI output" >&2
  exit 1
fi

# Get domain
DOMAIN=$(auth0 tenants list --json | jq -r '.[0].name')
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
  echo "Failed to resolve Auth0 tenant domain" >&2
  exit 1
fi

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

# Auth0 API Configuration
AUTH0_DOMAIN=$DOMAIN
AUTH0_AUDIENCE=$AUDIENCE
ENVEOF

echo "Auth0 API credentials written to $TARGET_FILE"
```

---

## Manual Setup

### Install Packages

```bash
composer require auth0/auth0-php vlucas/phpdotenv guzzlehttp/guzzle guzzlehttp/psr7 "symfony/cache:^7.0"
```

**Package breakdown:**
- `auth0/auth0-php` - The Auth0 SDK (v8.x)
- `vlucas/phpdotenv` - Load `.env` files
- `guzzlehttp/guzzle` - PSR-18 HTTP client (required by the SDK for JWKS fetching)
- `guzzlehttp/psr7` - PSR-7 HTTP messages (required by the SDK)
- `symfony/cache` - PSR-6 cache adapter for JWKS key caching

### Create Auth0 API Resource

1. Go to Auth0 Dashboard -> Applications -> APIs
2. Click **Create API**
3. Set a **Name** and an **Identifier** (e.g., `https://my-api.example.com`)
4. Note the Identifier - this is your `Audience`

### Create .env

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_AUDIENCE=https://my-api.example.com
```

**Important:** Domain format is `your-tenant.us.auth0.com` - do NOT include `https://`.

### Get Auth0 Configuration

- **Domain:** Auth0 Dashboard -> Settings -> Domain (or `auth0 tenants list`)
- **Audience:** The identifier you set when creating the API resource

### Using Environment Variables in Production

For production/containers, export environment variables directly:

```bash
export AUTH0_DOMAIN=your-tenant.us.auth0.com
export AUTH0_AUDIENCE=https://my-api.example.com
```

---

## Getting a Test Token

### Via Auth0 Dashboard

1. Go to Auth0 Dashboard -> Applications -> APIs
2. Select your API
3. Click the **Test** tab
4. Click **Copy Token** to get a test access token

### Via Auth0 CLI

```bash
# Get access token for testing
auth0 test token \
  --audience https://my-api.example.com
```

### Via curl (Client Credentials Flow)

First, you need a Machine-to-Machine application authorized for your API:

1. Go to Auth0 Dashboard -> Applications -> APIs -> Your API -> Machine to Machine Applications
2. Authorize an existing M2M app or create a new one
3. Note the Client ID and Client Secret

```bash
curl -X POST https://your-tenant.us.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_M2M_CLIENT_ID",
    "client_secret": "YOUR_M2M_CLIENT_SECRET",
    "audience": "https://my-api.example.com",
    "grant_type": "client_credentials"
  }'
```

### Request Tokens with Specific Scopes

First, define permissions on your API resource (Dashboard -> APIs -> Permissions tab), then:

```bash
curl -X POST https://your-tenant.us.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_M2M_CLIENT_ID",
    "client_secret": "YOUR_M2M_CLIENT_SECRET",
    "audience": "https://my-api.example.com",
    "grant_type": "client_credentials",
    "scope": "read:messages write:messages"
  }'
```

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

**401 Unauthorized - "invalid_token":** Verify that `AUTH0_AUDIENCE` in `.env` exactly matches your API Identifier in Auth0 Dashboard.

**401 Unauthorized - "invalid_issuer":** Ensure `AUTH0_DOMAIN` does not include `https://` - use `your-tenant.us.auth0.com` format only.

**"No PSR-18 HTTP Client found":** Install `guzzlehttp/guzzle` or another PSR-18 compatible client.

**Token expired:** Test tokens from the Dashboard are short-lived. Request a fresh token.

**JWKS fetch fails:** Check that your server can make outbound HTTPS requests to `https://{domain}/.well-known/jwks.json`.

**"audience is required":** Ensure `audience` is passed as a non-empty array in `SdkConfiguration`.

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
