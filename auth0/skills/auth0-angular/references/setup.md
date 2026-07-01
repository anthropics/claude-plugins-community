# Auth0 Angular Setup Guide

Complete setup instructions for Angular applications.

---

## Quick Setup (Automated)

### Bash Script

```bash
#!/bin/bash

# Install Auth0 CLI
if ! command -v auth0 &> /dev/null; then
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

# Login to Auth0
if ! auth0 tenants list &> /dev/null; then
  echo "Auth0 Login Required"
  read -p "Do you have an Auth0 account? (y/n): " HAS_ACCOUNT
  if [[ "$HAS_ACCOUNT" != "y" ]]; then
    echo "Visit https://auth0.com/signup to create an account"
    read -p "Press Enter when ready..."
  fi
  auth0 login
fi

# Create or select app
auth0 apps list
read -p "Enter your Auth0 app ID (or press Enter to create new): " APP_ID

if [ -z "$APP_ID" ]; then
  APP_NAME="${PWD##*/}-angular-app"
  APP_ID=$(auth0 apps create \
    --name "$APP_NAME" \
    --type spa \
    --auth-method None \
    --callbacks "http://localhost:4200" \
    --logout-urls "http://localhost:4200" \
    --origins "http://localhost:4200" \
    --web-origins "http://localhost:4200" \
    --metadata "created_by=agent_skills" \
    --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)
fi

# Get credentials
AUTH0_DOMAIN=$(auth0 apps show "$APP_ID" --json | grep -o '"domain":"[^"]*' | cut -d'"' -f4)
AUTH0_CLIENT_ID=$(auth0 apps show "$APP_ID" --json | grep -o '"client_id":"[^"]*' | cut -d'"' -f4)

echo "✅ Configuration complete!"
echo "Update src/environments/environment.ts with:"
echo "  domain: '$AUTH0_DOMAIN'"
echo "  clientId: '$AUTH0_CLIENT_ID'"
```

---

## Manual Setup

### Step 1: Install SDK

```bash
npm install @auth0/auth0-angular
```

### Step 2: Configure Environment

Create or update `src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  auth0: {
    domain: 'your-tenant.auth0.com',
    clientId: 'your-client-id',
    authorizationParams: {
      redirect_uri: window.location.origin
    }
  }
};
```

For production (`src/environments/environment.prod.ts`):

```typescript
export const environment = {
  production: true,
  auth0: {
    domain: 'your-tenant.auth0.com',
    clientId: 'your-client-id',
    authorizationParams: {
      redirect_uri: 'https://your-production-domain.com'
    }
  }
};
```

### Step 3: Get Auth0 Credentials

Using Auth0 CLI:

```bash
auth0 login
auth0 apps list
auth0 apps show <app-id>
```

Or via [Auth0 Dashboard](https://manage.auth0.com):
1. Create Single Page Application
2. Configure callback URLs: `http://localhost:4200`
3. Copy domain and client ID

---

## Troubleshooting

**Module not found errors:**
- Ensure @auth0/auth0-angular is in package.json
- Run `npm install`

**CORS errors:**
- Add `http://localhost:4200` to "Allowed Web Origins" in Auth0 Dashboard

**Environment variables not working:**
- Angular uses environment files, not .env
- Rebuild app after changing environment files

---

## Next Steps

- [Integration Guide](integration.md) - Implementation patterns
- [API Reference](api.md) - Complete SDK documentation
- [Main Skill](../SKILL.md) - Quick start guide
