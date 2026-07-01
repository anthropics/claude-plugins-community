# Auth0 ASP.NET Core Web API Setup Guide

Setup instructions for ASP.NET Core Web API applications.

---

## Quick Setup (Automated)

Below uses the Auth0 CLI to create an Auth0 API resource and retrieve your credentials.

### Step 1: Install Auth0 CLI and create API resource

```bash
# Install Auth0 CLI (macOS)
brew install auth0/auth0-cli/auth0

# Login
auth0 login --no-input

# Create an Auth0 API resource
auth0 apis create \
  --name "My ASP.NET Core API" \
  --identifier https://my-api.example.com \
  --json
```

Note the `identifier` value - this is your Audience.

### Step 2: Add configuration

Once you have your Domain and Audience, add the following to `appsettings.json`:

```json
{
  "Auth0": {
    "Domain": "your-tenant.auth0.com",
    "Audience": "https://my-api.example.com"
  }
}
```

Replace `your-tenant.auth0.com` with your Auth0 tenant domain and `https://my-api.example.com` with the identifier you used when creating the API resource.

---

## Manual Setup

### Install Package

```bash
dotnet add package Auth0.AspNetCore.Authentication.Api
```

### Create Auth0 API Resource

1. Go to Auth0 Dashboard → Applications → APIs
2. Click **Create API**
3. Set a **Name** and an **Identifier** (e.g., `https://my-api.example.com`)
4. Note the Identifier - this is your `Audience`

### Configure appsettings.json

```json
{
  "Auth0": {
    "Domain": "your-tenant.auth0.com",
    "Audience": "https://my-api.example.com"
  }
}
```

**Important:** Domain format is `your-tenant.auth0.com` - do NOT include `https://`.

### Get Auth0 Configuration

- **Domain:** Auth0 Dashboard → Settings → Domain (or `auth0 tenants list`)
- **Audience:** The identifier you set when creating the API resource

### Using Environment Variables

For production/containers, set environment variables (these override appsettings.json):

```bash
export Auth0__Domain=your-tenant.auth0.com
export Auth0__Audience=https://my-api.example.com
```

Note the double underscore `__` separator for nested config in environment variables.

---

## Getting a Test Token

### Via Auth0 Dashboard

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Click the **Test** tab
4. Click **Copy Token** to get a test access token

### Via Auth0 CLI (Client Credentials)

```bash
# Get access token for testing
auth0 test token \
  --audience https://my-api.example.com
```

### Via curl (Client Credentials Flow)

```bash
curl -X POST https://your-tenant.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://my-api.example.com",
    "grant_type": "client_credentials"
  }'
```

---

## Troubleshooting

**401 Unauthorized - "invalid_token":** Verify that the `Audience` in config exactly matches your API Identifier in Auth0 Dashboard.

**401 Unauthorized - "invalid_issuer":** Ensure `Domain` does not include `https://` - use `your-tenant.auth0.com` format only.

**HTTPS certificate errors locally:** Run `dotnet dev-certs https --trust` to trust the development certificate.

**Token expired:** Test tokens from the Dashboard are short-lived. Request a fresh token.

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
