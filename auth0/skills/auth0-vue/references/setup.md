# Auth0 Vue Setup Guide

Complete setup instructions with automated scripts and manual configuration options.

---

## Quick Setup (Automated)

**Never read the contents of `.env` at any point during setup.** The file may contain sensitive secrets that should not be exposed in the LLM context. If you determine you need to read the file for any reason, ask the user for explicit permission before doing so — do not proceed until the user confirms.

**Before running any part of this setup that writes to `.env`, you MUST ask the user for explicit confirmation.** Follow the steps below precisely.

### Step 1: Check for existing .env and confirm with user

Before writing to `.env`, check whether the file already exists:

```bash
test -f .env && echo "EXISTS" || echo "NOT_FOUND"
```

Then ask the user for explicit confirmation before proceeding — do not continue until the user confirms:

- If `.env` does **not** exist, ask:
  - Question: "This setup will create a `.env` file containing Auth0 credentials (domain and client ID). Do you want to proceed?"
  - Options: "Yes, create .env" / "No, I'll configure it manually"

- If `.env` **already exists**, ask:
  - Question: "A `.env` file already exists and may contain secrets unrelated to Auth0. This setup will append Auth0 credentials to it without modifying existing content. Do you want to proceed?"
  - Options: "Yes, append to existing .env" / "No, I'll update it manually"

**Do not proceed with writing to `.env` unless the user selects the confirmation option.**

### Step 2: Run automated setup (only after confirmation)

#### Bash Script (macOS/Linux)

Run this script to automatically set up everything:

```bash
#!/bin/bash

# Detect OS and install Auth0 CLI if needed
if ! command -v auth0 &> /dev/null; then
  echo "Installing Auth0 CLI..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install auth0/auth0-cli/auth0
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Download and review the install script before executing
    curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh -o /tmp/auth0-install.sh
    echo "⚠️  Review the install script at /tmp/auth0-install.sh before running"
    sh /tmp/auth0-install.sh -b /usr/local/bin
    rm /tmp/auth0-install.sh
  fi
fi

# Check if logged in to Auth0
if ! auth0 tenants list &> /dev/null; then
  echo "======================================"
  echo "Auth0 Login Required"
  echo "======================================"
  read -p "Do you have an Auth0 account? (y/n): " HAS_ACCOUNT

  if [[ "$HAS_ACCOUNT" != "y" ]]; then
    echo "Let's create your free Auth0 account!"
    echo "1. Visit: https://auth0.com/signup"
    echo "2. Sign up with your email or GitHub"
    echo "3. Choose a tenant domain"
    read -p "Press Enter when you've created your account..."
  fi

  auth0 login
fi

# List apps and prompt for selection
echo "Your Auth0 applications:"
auth0 apps list

read -p "Enter your Auth0 app ID (or press Enter to create new): " APP_ID

if [ -z "$APP_ID" ]; then
  echo "Creating new Auth0 SPA application..."
  APP_NAME="${PWD##*/}-vue-app"
  APP_ID=$(auth0 apps create \
    --name "$APP_NAME" \
    --type spa \
    --auth-method None \
    --callbacks "http://localhost:5173,http://localhost:3000" \
    --logout-urls "http://localhost:5173,http://localhost:3000" \
    --origins "http://localhost:5173,http://localhost:3000" \
    --web-origins "http://localhost:5173,http://localhost:3000" \
    --metadata "created_by=agent_skills" \
    --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
  echo "Created app with ID: $APP_ID"
fi

# Get app details and create .env file
echo "Fetching Auth0 credentials..."
AUTH0_DOMAIN=$(auth0 apps show "$APP_ID" --json | grep -o '"domain":"[^"]*' | cut -d'"' -f4)
AUTH0_CLIENT_ID=$(auth0 apps show "$APP_ID" --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)

# Append Auth0 credentials to .env
cat >> .env << EOF
VITE_AUTH0_DOMAIN=$AUTH0_DOMAIN
VITE_AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID
EOF

echo "✅ Auth0 configuration complete!"
echo "Appended to .env:"
echo "  VITE_AUTH0_DOMAIN=$AUTH0_DOMAIN"
echo "  VITE_AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID"
```

#### PowerShell Script (Windows)

```powershell
# Install Auth0 CLI if not present
if (!(Get-Command auth0 -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Auth0 CLI..."
  scoop install auth0
}

# Check if logged in
try {
  auth0 tenants list | Out-Null
} catch {
  Write-Host "======================================"
  Write-Host "Auth0 Login Required"
  Write-Host "======================================"

  $hasAccount = Read-Host "Do you have an Auth0 account? (y/n)"

  if ($hasAccount -ne "y") {
    Write-Host "Let's create your free Auth0 account!"
    Write-Host "1. Visit: https://auth0.com/signup"
    Write-Host "2. Sign up with your email or GitHub"
    Read-Host "Press Enter when you've created your account"
  }

  auth0 login
}

# List and select app
Write-Host "Your Auth0 applications:"
auth0 apps list

$appId = Read-Host "Enter your Auth0 app ID (or press Enter to create new)"

if ([string]::IsNullOrEmpty($appId)) {
  $appName = Split-Path -Leaf (Get-Location)
  Write-Host "Creating new Auth0 SPA application..."
  $appJson = auth0 apps create --name "$appName-vue-app" --type spa `
    --auth-method None `
    --callbacks "http://localhost:5173,http://localhost:3000" `
    --logout-urls "http://localhost:5173,http://localhost:3000" `
    --origins "http://localhost:5173,http://localhost:3000" `
    --web-origins "http://localhost:5173,http://localhost:3000" `
    --metadata "created_by=agent_skills" --json

  $appId = ($appJson | ConvertFrom-Json).client_id
  Write-Host "Created app with ID: $appId"
}

# Get credentials and create .env
Write-Host "Fetching Auth0 credentials..."
$appDetails = auth0 apps show $appId --json | ConvertFrom-Json

@"
VITE_AUTH0_DOMAIN=$($appDetails.domain)
VITE_AUTH0_CLIENT_ID=$($appDetails.client_id)
"@ | Out-File -FilePath .env -Encoding UTF8 -Append

Write-Host "✅ Auth0 configuration complete!"
Write-Host "Appended to .env:"
Write-Host "  VITE_AUTH0_DOMAIN=$($appDetails.domain)"
Write-Host "  VITE_AUTH0_CLIENT_ID=$($appDetails.client_id)"
```

---

## Manual Setup

### Step 1: Install SDK

```bash
npm install @auth0/auth0-vue
```

### Step 2: Install Auth0 CLI

**macOS:**
```bash
brew install auth0/auth0-cli/auth0
```

**Linux (review script before executing):**
```bash
curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh -o /tmp/auth0-install.sh
# Review the script before running: cat /tmp/auth0-install.sh
sh /tmp/auth0-install.sh
rm /tmp/auth0-install.sh
```

**Windows:**
```powershell
scoop install auth0
```

### Step 3: Get Credentials

```bash
# Login to Auth0
auth0 login

# List your apps
auth0 apps list

# Get app details
auth0 apps show <app-id>
```

### Step 4: Create .env File

```bash
VITE_AUTH0_DOMAIN=<your-tenant>.auth0.com
VITE_AUTH0_CLIENT_ID=<your-client-id>
```

---

## Creating Auth0 Application via Dashboard

1. Go to [Auth0 Dashboard](https://manage.auth0.com)
2. Navigate to **Applications** → **Applications**
3. Click **Create Application**
4. Choose **Single Page Web Applications**
5. Configure:
   - **Allowed Callback URLs**: `http://localhost:5173, http://localhost:3000`
   - **Allowed Logout URLs**: `http://localhost:5173, http://localhost:3000`
   - **Allowed Web Origins**: `http://localhost:5173, http://localhost:3000`
   - **Allowed Origins (CORS)**: `http://localhost:5173, http://localhost:3000`
6. Copy your **Domain** and **Client ID**
7. Create `.env` file as shown above

---

## Troubleshooting

### Environment Variables Not Loading

**Issue**: Variables not available in app

**Solution:**
- Ensure variables start with `VITE_` prefix
- Restart dev server after creating `.env`
- Check file is named exactly `.env` (not `.env.local`)
- Vite only loads variables at build time, not runtime

### Auth0 CLI Issues

**Browser doesn't open:**
```bash
auth0 login --no-browser
```

**"Not logged in" error:**
```bash
auth0 login --force
```

### CORS Errors

**Issue**: CORS errors when logging in

**Solution:**
- Add your app URL to "Allowed Web Origins" in Auth0 Dashboard
- Ensure callback URLs include protocol (`http://` or `https://`)
- For local dev, use `http://localhost:5173` (Vite default)

---

## Next Steps

After setup is complete:
1. Return to [main skill guide](../SKILL.md) for integration steps
2. See [Integration Guide](integration.md) for advanced patterns
3. Check [API Reference](api.md) for complete SDK documentation
