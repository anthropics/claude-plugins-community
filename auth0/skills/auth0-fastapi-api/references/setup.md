# Auth0 FastAPI API Setup Guide

Setup instructions for FastAPI API applications.

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
  --name "My FastAPI API" \
  --identifier https://my-api.example.com \
  --json
```

Note the `identifier` value — this is your Audience.

### Step 2: Get your domain

```bash
# List tenants to get your domain
auth0 tenants list
```

### Step 3: Add configuration

Once you have your Domain and Audience, create a `.env` file:

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_AUDIENCE=https://my-api.example.com
```

Replace `your-tenant.us.auth0.com` with your Auth0 tenant domain and `https://my-api.example.com` with the identifier you used when creating the API resource.

> **Important:** Never read the contents of `.env` at any point during setup. The file may contain sensitive secrets that should not be exposed in the LLM context.

---

## Manual Setup

### Install Package

```bash
pip install auth0-fastapi-api python-dotenv
```

If you're using Poetry:

```bash
poetry add auth0-fastapi-api python-dotenv
```

### Create Auth0 API Resource

1. Go to Auth0 Dashboard → Applications → APIs
2. Click **Create API**
3. Set a **Name** and an **Identifier** (e.g., `https://my-api.example.com`)
4. Note the Identifier — this is your `Audience`

### Configure .env

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_AUDIENCE=https://my-api.example.com
```

**Important:** Domain format is `your-tenant.us.auth0.com` — do NOT include `https://`.

### Get Auth0 Configuration

- **Domain:** Auth0 Dashboard → Settings → Domain (or `auth0 tenants list`)
- **Audience:** The identifier you set when creating the API resource

### Using Environment Variables in Production

For production/containers, export environment variables directly:

```bash
export AUTH0_DOMAIN=your-tenant.us.auth0.com
export AUTH0_AUDIENCE=https://my-api.example.com
```

When using `os.environ[]` instead of `os.getenv()`, missing values will raise `KeyError` immediately — this is safer for production.

---

## Getting a Test Token

### Via Auth0 Dashboard

1. Go to Auth0 Dashboard → Applications → APIs
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

```bash
curl -X POST https://your-tenant.us.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://my-api.example.com",
    "grant_type": "client_credentials"
  }'
```

### Request Tokens with Specific Scopes

```bash
curl -X POST https://your-tenant.us.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://my-api.example.com",
    "grant_type": "client_credentials",
    "scope": "read:messages write:messages"
  }'
```

---

## Troubleshooting

**401 Unauthorized — "invalid_token":** Verify that the `AUTH0_AUDIENCE` in `.env` exactly matches your API Identifier in Auth0 Dashboard.

**401 Unauthorized — "invalid_issuer":** Ensure `AUTH0_DOMAIN` does not include `https://` — use `your-tenant.us.auth0.com` format only.

**`os.getenv()` returns `None`:** Ensure `python-dotenv` is installed and `load_dotenv()` is called before `Auth0FastAPI()` initialization. In production, use `os.environ[]` to fail fast on missing values.

**Token expired:** Test tokens from the Dashboard are short-lived. Request a fresh token.

**`ValueError: audience is required.`:** The `audience` parameter cannot be empty. Ensure your `.env` file is loaded and the value is set.

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
