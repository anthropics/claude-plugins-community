# Auth0 Next.js Setup Guide

Setup instructions for Next.js with App Router or Pages Router.

---

## Quick Setup (Automated)

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
  - Question: "This setup will create a `.env.local` file containing Auth0 credentials (AUTH0_CLIENT_ID, AUTH0_DOMAIN, AUTH0_SECRET) and a placeholder for AUTH0_CLIENT_SECRET that you will need to fill in manually. Do you want to proceed?"
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
if ! auth0 tenants list &> /dev/null; then
  echo "Visit https://auth0.com/signup if you need an account"
  auth0 login
fi

# Create/select app
auth0 apps list
read -p "Enter app ID (or Enter to create new): " APP_ID

if [ -z "$APP_ID" ]; then
  APP_ID=$(auth0 apps create \
    --name "${PWD##*/}-nextjs" \
    --type regular \
    --callbacks "http://localhost:3000/auth/callback" \
    --logout-urls "http://localhost:3000" \
    --metadata "created_by=agent_skills" \
    --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
fi

# Get credentials
AUTH0_DOMAIN=$(auth0 apps show "$APP_ID" --json | grep -o '"domain":"[^"]*' | cut -d'"' -f4)
AUTH0_CLIENT_ID=$(auth0 apps show "$APP_ID" --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)

# Generate secret
AUTH0_SECRET=$(openssl rand -hex 32)

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
AUTH0_SECRET=$AUTH0_SECRET
APP_BASE_URL=http://localhost:3000
AUTH0_DOMAIN=$AUTH0_DOMAIN
AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID
AUTH0_CLIENT_SECRET='YOUR_CLIENT_SECRET'
ENVEOF

echo "✅ Auth0 credentials written to $TARGET_FILE"
```

After the script runs, remind the user to:
1. Open the env file that was written and replace `YOUR_CLIENT_SECRET` with the actual client secret from Auth0.
2. Ensure the env file is listed in `.gitignore` to avoid accidentally committing secrets.

---

## Manual Setup

### Step 1: Install SDK

```bash
npm install @auth0/nextjs-auth0
```

### Step 2: Create .env.local

```bash
AUTH0_SECRET=<openssl-rand-hex-32>
APP_BASE_URL=http://localhost:3000
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
```

Generate `AUTH0_SECRET`:
```bash
openssl rand -hex 32
```

### Step 3: Configure Auth0 Application

Via CLI:
```bash
auth0 login
auth0 apps create --name "My Next.js App" --type regular \
  --callbacks "http://localhost:3000/auth/callback" \
  --logout-urls "http://localhost:3000"
```

Via Dashboard:
1. Create **Regular Web Application**
2. Configure:
   - Allowed Callback URLs: `http://localhost:3000/auth/callback`
   - Allowed Logout URLs: `http://localhost:3000`
3. Copy credentials to `.env.local`

---

## Troubleshooting

**"Invalid state" error:**
- Regenerate `AUTH0_SECRET`
- Clear cookies and restart dev server

**Client secret not working:**
- Next.js uses Regular Web Application (not SPA)
- Verify client secret copied correctly

**Callback URL mismatch:**
- Ensure `/auth/callback` is in Allowed Callback URLs
- Check `APP_BASE_URL` matches your domain

---

## Next Steps

- [Integration Guide](integration.md) - Implementation patterns
- [API Reference](api.md) - Complete SDK documentation
- [Main Skill](../SKILL.md) - Quick start
