# Auth0 Flask Setup Guide

Setup instructions for Flask applications.

---

## Quick Setup (Automated)

Below automates the setup, except for the CLIENT_SECRET. Inform the user that they have to fill in the value for the CLIENT_SECRET themselves.

**Never read the contents of `.env.local` or `.env` at any point during setup.** The file may contain sensitive secrets that should not be exposed in the LLM context. If you determine you need to read the file for any reason, ask the user for explicit permission before doing so — do not proceed until the user confirms.

**Before running any part of this setup that writes to an env file, you MUST ask the user for explicit confirmation.** Follow the steps below precisely.

### Step 1: Check for existing env files and confirm with user

Before writing credentials, check which env files exist:

```bash
test -f .env.local && echo "ENV_LOCAL_EXISTS" || echo "ENV_LOCAL_NOT_FOUND"
test -f .env && echo "ENV_EXISTS" || echo "ENV_NOT_FOUND"
```

Then ask the user for explicit confirmation before proceeding — do not continue until the user confirms:

- If `.env.local` exists, ask:
  - Question: "A `.env.local` file already exists and may contain secrets unrelated to Auth0. This setup will append Auth0 credentials to it without modifying existing content. Do you want to proceed?"
  - Options: "Yes, append to existing .env.local" / "No, I'll update it manually"

- If `.env.local` does **not** exist but `.env` exists, ask:
  - Question: "A `.env` file already exists and may contain secrets unrelated to Auth0. This setup will append Auth0 credentials to it without modifying existing content. Do you want to proceed?"
  - Options: "Yes, append to existing .env" / "No, I'll update it manually"

- If neither exists, ask:
  - Question: "This setup will create a `.env` file containing Auth0 credentials (AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_SECRET) and a placeholder for AUTH0_CLIENT_SECRET. Do you want to proceed?"
  - Options: "Yes, create .env" / "No, I'll configure it manually"

**Do not proceed with writing to any env file unless the user selects the confirmation option.**

### Step 2: Run automated setup (only after confirmation)

```bash
#!/bin/bash

# Install Auth0 CLI
if ! command -v auth0 &> /dev/null; then
  [[ "$OSTYPE" == "darwin"* ]] && brew install auth0/auth0-cli/auth0 || \
  curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh -s -- -b /usr/local/bin
fi

# Login
auth0 login 2>/dev/null || auth0 login

# Create/select app
auth0 apps list
read -p "Enter app ID (or Enter to create): " APP_ID

if [ -z "$APP_ID" ]; then
  APP_ID=$(auth0 apps create --name "${PWD##*/}-flask" --type regular \
    --callbacks "http://localhost:5000/callback" \
    --logout-urls "http://localhost:5000" \
    --metadata "created_by=agent_skills" \
    --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
fi

# Get credentials
DOMAIN=$(auth0 apps show "$APP_ID" --json | grep -o '"domain":"[^"]*' | cut -d'"' -f4)
CLIENT_ID=$(auth0 apps show "$APP_ID" --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
SECRET=$(openssl rand -hex 64)

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
AUTH0_DOMAIN=$DOMAIN
AUTH0_CLIENT_ID=$CLIENT_ID
AUTH0_CLIENT_SECRET='YOUR_CLIENT_SECRET'
AUTH0_SECRET=$SECRET
AUTH0_REDIRECT_URI=http://localhost:5000/callback
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
pip install auth0-server-python "flask[async]" python-dotenv
```

**Critical:** You must install `flask[async]` (not just `flask`). The `[async]` extra installs `asgiref` which is required for Flask 2.0+ to support `async def` route handlers.

### Create .env

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
AUTH0_SECRET=<openssl-rand-hex-64>
AUTH0_REDIRECT_URI=http://localhost:5000/callback
```

Generate secret: `openssl rand -hex 64`

### Get Auth0 Credentials

CLI: `auth0 apps show <app-id> --reveal-secrets`

Dashboard: Create Regular Web Application, copy credentials

### Configure Auth0 Dashboard

In your Auth0 Application settings:
- **Allowed Callback URLs**: `http://localhost:5000/callback`
- **Allowed Logout URLs**: `http://localhost:5000`

---

## Troubleshooting

**"Missing AUTH0_SECRET" error:** Ensure `AUTH0_SECRET` is set and at least 32 characters long. Generate with `openssl rand -hex 64`.

**"Invalid redirect_uri" error:** Add `http://localhost:5000/callback` to Allowed Callback URLs in Auth0 Dashboard.

**Callback URL mismatch:** URL must match exactly between `AUTH0_REDIRECT_URI` in `.env` and the Allowed Callback URLs in Auth0 Dashboard.

**Client secret required:** Flask uses Regular Web Application type — ensure the app was created as `--type regular`, not SPA or Native.

**Async routes not working:** Ensure you installed `flask[async]` (not just `flask`). Without the `[async]` extra, async route handlers silently fail.

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
