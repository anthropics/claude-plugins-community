# Auth0 Laravel API Setup Guide

Setup instructions for Laravel API applications using `auth0/login` with the `AuthorizationGuard`.

---

## Quick Setup (Automated)

Below automates the setup using the Auth0 CLI.

**Never read the contents of `.env` at any point during setup.** The file may contain sensitive secrets that should not be exposed in the LLM context.

**Before running any part of this setup that writes to an env file, you MUST ask the user for explicit confirmation.**

### Step 1: Check for existing env and confirm with user

```bash
test -f .env && echo "ENV_EXISTS" || echo "ENV_NOT_FOUND"
```

Ask the user for confirmation before proceeding:

- If `.env` exists, ask:
  - "A `.env` already exists. This setup will append Auth0 API credentials without modifying existing content. Do you want to proceed?"
  - Options: "Yes, append to existing `.env`" / "No, I'll update it manually"

- If `.env` doesn't exist, ask:
  - "This setup will add Auth0 credentials (AUTH0_DOMAIN, AUTH0_AUDIENCE) to your `.env`. Do you want to proceed?"
  - Options: "Yes, update .env" / "No, I'll configure it manually"

**Do not proceed unless the user confirms.**

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

# Verify jq is available
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

# Append Auth0 credentials to .env
cat >> .env << ENVEOF

# Auth0 API Configuration
AUTH0_DOMAIN=$DOMAIN
AUTH0_AUDIENCE=$AUDIENCE
ENVEOF

echo "Auth0 API credentials written to .env"
```

---

## Manual Setup

### Install Package

```bash
composer require auth0/login
```

If you don't already have a PSR-18 HTTP client:

```bash
composer require guzzlehttp/guzzle guzzlehttp/psr7
```

### Publish Configuration

```bash
php artisan vendor:publish --tag=auth0
```

### Create Auth0 API Resource

1. Go to Auth0 Dashboard -> Applications -> APIs
2. Click **Create API**
3. Set a **Name** and an **Identifier** (e.g., `https://my-api.example.com`)
4. Note the Identifier - this is your `Audience`

### Configure .env

Add to `.env`:

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_AUDIENCE=https://my-api.example.com
```

**Important:** Domain format is `your-tenant.us.auth0.com` - do NOT include `https://`.

### Get Auth0 Configuration

- **Domain:** Auth0 Dashboard -> Settings -> Domain (or `auth0 tenants list`)
- **Audience:** The identifier you set when creating the API resource

---

## Getting a Test Token

### Via Auth0 Dashboard

1. Go to Auth0 Dashboard -> Applications -> APIs
2. Select your API
3. Click the **Test** tab
4. Click **Copy Token** to get a test access token

### Via Auth0 CLI

```bash
auth0 test token \
  --audience https://my-api.example.com
```

### Via curl (Client Credentials Flow)

First, authorize a Machine-to-Machine application for your API:

1. Go to Auth0 Dashboard -> Applications -> APIs -> Your API -> Machine to Machine Applications
2. Authorize an existing M2M app or create a new one

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

Define permissions on your API (Dashboard -> APIs -> Permissions tab), then:

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

## Troubleshooting

**401 Unauthorized on all requests:** Verify `AUTH0_DOMAIN` and `AUTH0_AUDIENCE` in `.env` are correct. Run `php artisan config:clear` to clear cached config.

**"Driver [auth0.authorizer] not defined":** Ensure `auth0/login` is installed and the service provider is registered. Run `composer dump-autoload`.

**Token validation fails after deployment:** Run `php artisan config:clear` - Laravel may be using cached config with old values.

**"audience is required":** Ensure `AUTH0_AUDIENCE` is set in `.env` and `config/auth0.php` references it.

**CORS errors from SPA clients:** See [Integration Guide](integration.md#cors-configuration) for CORS middleware setup.

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
