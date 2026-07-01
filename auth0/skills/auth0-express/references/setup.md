# Auth0 Express Setup Guide

Setup instructions for Express.js applications.

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
  - Question: "This setup will create a `.env.local` file containing Auth0 credentials (CLIENT_ID, ISSUER_BASE_URL, SECRET) and a placeholder for CLIENT_SECRET. Do you want to proceed?"
  - Options: "Yes, create .env.local" / "No, I'll configure it manually"

**Do not proceed with writing to any env file unless the user selects the confirmation option.**

### Step 2: Run automated setup (only after confirmation)

```bash
#!/bin/bash

# Install Auth0 CLI
if ! command -v auth0 &> /dev/null; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install auth0/auth0-cli/auth0
  else
    # Download and review the install script before executing
    curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh -o /tmp/auth0-install.sh
    echo "⚠️  Review the install script at /tmp/auth0-install.sh before running"
    sh /tmp/auth0-install.sh -b /usr/local/bin
    rm /tmp/auth0-install.sh
  fi
fi

# Login
auth0 login 2>/dev/null || auth0 login

# Create/select app
auth0 apps list
read -p "Enter app ID (or Enter to create): " APP_ID

if [ -z "$APP_ID" ]; then
  APP_ID=$(auth0 apps create --name "${PWD##*/}-express" --type regular \
    --callbacks "http://localhost:3000/callback" \
    --logout-urls "http://localhost:3000" \
    --metadata "created_by=agent_skills" \
    --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
fi

# Get credentials
DOMAIN=$(auth0 apps show "$APP_ID" --json | grep -o '"domain":"[^"]*' | cut -d'"' -f4)
CLIENT_ID=$(auth0 apps show "$APP_ID" --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
SECRET=$(openssl rand -hex 32)

# Determine target env file
if [ -f .env.local ]; then
  TARGET_FILE=".env.local"
elif [ -f .env ]; then
  TARGET_FILE=".env"
else
  TARGET_FILE=".env.local"
fi

# Append Auth0 credentials
cat >> "$TARGET_FILE" << ENVEOF
SECRET=$SECRET
BASE_URL=http://localhost:3000
CLIENT_ID=$CLIENT_ID
CLIENT_SECRET='YOUR_CLIENT_SECRET'
ISSUER_BASE_URL=https://$DOMAIN
ENVEOF

echo "✅ Auth0 credentials written to $TARGET_FILE"
```

After the script runs, remind the user to:
1. Open the env file that was written and replace `YOUR_CLIENT_SECRET` with the actual client secret from Auth0.
2. Ensure the env file is listed in `.gitignore` to avoid accidentally committing secrets.

---

## Manual Setup

### Install Packages

```bash
npm install express-openid-connect dotenv
```

### Create .env

```bash
SECRET=<openssl-rand-hex-32>
BASE_URL=http://localhost:3000
CLIENT_ID=your-client-id
CLIENT_SECRET=your-client-secret
ISSUER_BASE_URL=https://your-tenant.auth0.com
```

### Get Auth0 Credentials

CLI: `auth0 apps show <app-id> --reveal-secrets`

Dashboard: Create Regular Web Application, copy credentials

---

## Troubleshooting

**"Invalid state" error:** Regenerate `SECRET`

**Client secret required:** Express uses Regular Web Application type

**Callback URL mismatch:** Add `/callback` to Allowed Callback URLs

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
