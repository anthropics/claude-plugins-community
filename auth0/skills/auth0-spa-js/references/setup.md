# Auth0 SPA JS Setup Guide

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

```bash
#!/bin/bash

# Install Auth0 CLI if needed
if ! command -v auth0 &> /dev/null; then
  echo "Installing Auth0 CLI..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install auth0/auth0-cli/auth0
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh -s -- -b /usr/local/bin
  else
    echo "Please install Auth0 CLI: https://github.com/auth0/auth0-cli#installation"
    exit 1
  fi
fi

# Check if logged in to Auth0
if ! auth0 tenants list &> /dev/null; then
  echo ""
  echo "======================================"
  echo "Auth0 Login Required"
  echo "======================================"
  read -p "Do you have an Auth0 account? (y/n): " HAS_ACCOUNT

  if [[ "$HAS_ACCOUNT" != "y" ]]; then
    echo ""
    echo "Create a free account at: https://auth0.com/signup"
    read -p "Press Enter when you've created your account..."
  fi

  auth0 login
  if ! auth0 tenants list &> /dev/null; then
    echo "❌ Login failed. Please try again."
    exit 1
  fi
  echo "✅ Successfully logged in to Auth0!"
fi

# Detect env var prefix from project
if grep -q '"vite"' package.json 2>/dev/null; then
  PREFIX="VITE_AUTH0"
elif grep -q '"react-scripts"' package.json 2>/dev/null; then
  PREFIX="REACT_APP_AUTH0"
else
  PREFIX="VITE_AUTH0"  # Default to Vite
fi

# List apps and prompt for selection
echo "Your Auth0 applications:"
auth0 apps list

read -p "Enter your Auth0 app ID (or press Enter to create a new one): " APP_ID

if [ -z "$APP_ID" ]; then
  echo "Creating new Auth0 SPA application..."
  APP_NAME="${PWD##*/}-spa"
  APP_ID=$(auth0 apps create \
    --name "$APP_NAME" \
    --type spa \
    --auth-method None \
    --callbacks "http://localhost:3000,http://localhost:5173" \
    --logout-urls "http://localhost:3000,http://localhost:5173" \
    --origins "http://localhost:3000,http://localhost:5173" \
    --web-origins "http://localhost:3000,http://localhost:5173" \
    --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
  echo "Created SPA app with ID: $APP_ID"
fi

# Get app details
AUTH0_DOMAIN=$(auth0 apps show "$APP_ID" --json | grep -o '"domain":"[^"]*' | cut -d'"' -f4)
AUTH0_CLIENT_ID=$(auth0 apps show "$APP_ID" --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)

# Append to .env
cat >> .env << EOF
${PREFIX}_DOMAIN=$AUTH0_DOMAIN
${PREFIX}_CLIENT_ID=$AUTH0_CLIENT_ID
EOF

echo "✅ Auth0 configuration complete!"
echo "Appended to .env:"
echo "  ${PREFIX}_DOMAIN=$AUTH0_DOMAIN"
echo "  ${PREFIX}_CLIENT_ID=$AUTH0_CLIENT_ID"
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
  Write-Host "Auth0 Login Required"
  $hasAccount = Read-Host "Do you have an Auth0 account? (y/n)"

  if ($hasAccount -ne "y") {
    Write-Host "Create a free account at: https://auth0.com/signup"
    Read-Host "Press Enter when you've created your account"
  }

  auth0 login
  Write-Host "✅ Successfully logged in to Auth0!"
}

# Detect env var prefix
$prefix = if (Select-String -Path "package.json" -Pattern '"vite"' -Quiet) { "VITE_AUTH0" }
          elseif (Select-String -Path "package.json" -Pattern '"react-scripts"' -Quiet) { "REACT_APP_AUTH0" }
          else { "VITE_AUTH0" }

# List and select app
Write-Host "Your Auth0 applications:"
auth0 apps list

$appId = Read-Host "Enter your Auth0 app ID (or press Enter to create new)"

if ([string]::IsNullOrEmpty($appId)) {
  $appName = Split-Path -Leaf (Get-Location)
  Write-Host "Creating new Auth0 SPA application..."
  $appJson = auth0 apps create --name "$appName-spa" --type spa `
    --auth-method None `
    --callbacks "http://localhost:3000,http://localhost:5173" `
    --logout-urls "http://localhost:3000,http://localhost:5173" `
    --origins "http://localhost:3000,http://localhost:5173" `
    --web-origins "http://localhost:3000,http://localhost:5173" `
    --json

  $appId = ($appJson | ConvertFrom-Json).client_id
  Write-Host "Created app with ID: $appId"
}

# Get credentials
$appDetails = auth0 apps show $appId --json | ConvertFrom-Json

@"
${prefix}_DOMAIN=$($appDetails.domain)
${prefix}_CLIENT_ID=$($appDetails.client_id)
"@ | Out-File -FilePath .env -Encoding UTF8 -Append

Write-Host "✅ Auth0 configuration complete!"
Write-Host "  ${prefix}_DOMAIN=$($appDetails.domain)"
Write-Host "  ${prefix}_CLIENT_ID=$($appDetails.client_id)"
```

---

## Manual Setup

If you prefer manual setup or the scripts don't work:

### Step 1: Install SDK

```bash
npm install @auth0/auth0-spa-js
```

### Step 2: Install Auth0 CLI

**macOS:**
```bash
brew install auth0/auth0-cli/auth0
```

**Linux:**
```bash
curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh
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

# Get app details (replace <app-id>)
auth0 apps show <app-id>
```

### Step 4: Create .env File

**For Vite-based projects:**
```bash
VITE_AUTH0_DOMAIN=your-tenant.auth0.com
VITE_AUTH0_CLIENT_ID=your-client-id
```

**For Create React App:**
```bash
REACT_APP_AUTH0_DOMAIN=your-tenant.auth0.com
REACT_APP_AUTH0_CLIENT_ID=your-client-id
```

**For Webpack / plain HTML:**
```bash
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
```

---

## Creating an Auth0 Application via Dashboard

1. Go to [Auth0 Dashboard](https://manage.auth0.com)
2. Navigate to **Applications** → **Applications**
3. Click **Create Application**
4. Choose:
   - Name: Your app name
   - Type: **Single Page Web Applications**
5. Configure in the **Settings** tab:
   - **Allowed Callback URLs**: `http://localhost:5173, http://localhost:3000`
   - **Allowed Logout URLs**: `http://localhost:5173, http://localhost:3000`
   - **Allowed Web Origins**: `http://localhost:5173, http://localhost:3000`
   - **Allowed Origins (CORS)**: `http://localhost:5173, http://localhost:3000`
6. Click **Save Changes**
7. Copy your **Domain** and **Client ID**

> **Important:** The **Allowed Web Origins** field is required for `getTokenSilently()` (silent authentication). Without it, users will be logged out on every page refresh.

---

## Secret Management

SPAs do **not** use a `client_secret`. The Auth0 SPA application type explicitly sets the Token Endpoint Authentication Method to `None`. If you see a client secret anywhere in your code, remove it immediately.

Your `.env` file contains only:
- `AUTH0_DOMAIN` / `VITE_AUTH0_DOMAIN` — Not a secret (public)
- `AUTH0_CLIENT_ID` / `VITE_AUTH0_CLIENT_ID` — Not a secret (public)

Still, follow these practices:
- Add `.env` to `.gitignore` (to avoid accidental commits with other sensitive env vars)
- Use `.env.local` for Vite projects (auto-ignored by Vite's default `.gitignore`)
- Never commit credential files to version control

---

## Troubleshooting Setup

### Environment Variables Not Loading

**Vite:**
- Ensure variables start with `VITE_`
- Restart the dev server after creating/editing `.env`
- Use `import.meta.env.VITE_AUTH0_DOMAIN` (not `process.env`)

**Create React App:**
- Ensure variables start with `REACT_APP_`
- Restart dev server after changes

### Auth0 CLI Issues

**Browser doesn't open for login:**
```bash
auth0 login --no-browser
```

**"Not logged in" error:**
```bash
auth0 login --force
```

---

## Next Steps

After setup is complete:
1. Return to [main skill guide](../SKILL.md) for integration steps
2. See [Integration Guide](integration.md) for advanced patterns
3. Check [API Reference](api.md) for complete SDK documentation
