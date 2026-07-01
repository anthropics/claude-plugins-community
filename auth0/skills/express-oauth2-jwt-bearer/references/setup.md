# express-oauth2-jwt-bearer Setup Guide

## Auth0 Configuration

> **Agent instruction:**
>
> **Check if credentials are already provided in the user's prompt:** If the user's prompt already includes Auth0 Domain and API Audience (e.g. `your-tenant.us.auth0.com` and `https://api.example.com`), use them directly — skip to "Write the .env file" below. Do NOT call `AskUserQuestion` to re-confirm provided credentials, and do NOT run the bootstrap script.
>
> **Env var convention:** This skill uses the SDK-native variables `ISSUER_BASE_URL` (the full issuer URL, including `https://`) and `AUDIENCE`. `express-oauth2-jwt-bearer` reads them automatically, so `auth()` is called with no arguments.
>
> If credentials are NOT provided, offer setup choices:
>
> Use `AskUserQuestion` to ask the user:
> "How would you like to configure Auth0 for this project?"
> - Option A: **Automatic setup (recommended)** — runs the bootstrap script to create the Auth0 API automatically
> - Option B: **Manual setup** — provide Auth0 credentials manually
>
> **If Automatic Setup (Option A):**
>
> 1. **Pre-flight checks:**
>    - Verify Node.js 20+: `node --version`
>    - Verify Auth0 CLI installed: `auth0 --version`
>    - Verify logged in: `auth0 tenants list --csv --no-input`
>    - If any check fails, guide user to install/login, or fall back to Option B
>
> 2. **Run bootstrap script:**
>    ```bash
>    cd <skill-dir>/scripts && npm install && node bootstrap.mjs <project-path>
>    ```
>    The script will:
>    - Validate the project structure (detect `package.json` with Node.js API patterns)
>    - Discover existing Auth0 APIs
>    - Show a change plan (CREATE or SKIP)
>    - Create the Auth0 API (Resource Server) with the specified identifier
>    - Write the `.env` configuration file with Domain + Audience
>    - Print a summary
>
> **If Manual Setup (Option B):**
>
> Ask the user for:
> - **Auth0 Domain** (e.g., `your-tenant.us.auth0.com`)
> - **API Audience** — the API Identifier you set when creating the Auth0 API (e.g., `https://your-api.example.com`)
>
> Then write the `.env` file (see below). Prefix the domain with `https://` to form `ISSUER_BASE_URL`.
>
> **Write the .env file** (both paths):
> ```env
> ISSUER_BASE_URL=https://your-tenant.us.auth0.com
> AUDIENCE=https://your-api.example.com
> PORT=3000
> ```

### Auth0 API Registration (Resource Server)

The bootstrap script automatically runs `auth0 apis create` to register your API as a Resource Server. This produces the `AUDIENCE` value (the API Identifier) that your middleware uses for token validation.

**Auth0 CLI command (for reference):**
```bash
auth0 apis create \
  --name "My Node API" \
  --identifier "https://my-api.example.com" \
  --json --no-input
```

### Creating the Auth0 API manually (if not using bootstrap script)

1. Go to [Auth0 Dashboard → APIs](https://manage.auth0.com/#/apis)
2. Click **Create API**
3. Set:
   - **Name**: Your API name (e.g., "My Node API")
   - **Identifier**: A URL-like identifier (e.g., `https://my-api.example.com`) — this becomes `AUDIENCE`
   - **Signing Algorithm**: `RS256` (recommended)
4. Click **Create**
5. Note the **API Identifier** — this is your Audience value

### Enable RBAC (optional)

To use `claimIncludes('permissions', 'read:data')` with Auth0 RBAC:

1. Go to Auth0 Dashboard → APIs → your API → Settings
2. Enable **"Enable RBAC"**
3. Enable **"Add Permissions in the Access Token"**
4. Add permissions under the **Permissions** tab
5. Assign permissions to roles, and roles to users via Auth0 Dashboard

## Post-Setup Steps

After running the bootstrap script or manual setup:

1. **Verify domain and audience** are correct in `.env`
2. **Test the API is reachable**: `auth0 apis list --json --no-input | grep your-api`
3. **Confirm CORS is configured** before auth middleware in your server file (see integration.md)
4. **Request a test token** using M2M credentials or the Auth0 Dashboard test feature:
   - Go to Auth0 Dashboard → APIs → your API → Test tab
   - Click **Copy Token** to get a test access token

## SDK Installation

```bash
npm install express-oauth2-jwt-bearer
```

**With additional recommended packages:**
```bash
npm install express-oauth2-jwt-bearer dotenv cors helmet
npm install --save-dev @types/express @types/cors  # TypeScript projects
```

**package.json dependency:**
```json
{
  "dependencies": {
    "express-oauth2-jwt-bearer": "^1.7.4",
    "dotenv": "^16.0.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0"
  }
}
```

## Secret Management

`express-oauth2-jwt-bearer` requires only **Domain** and **Audience** — no Client Secret. The middleware validates tokens using the Auth0 JWKS (JSON Web Key Set) endpoint, which provides the public signing keys. This means:

- **No client secret needed** for token validation
- The JWKS endpoint is publicly accessible at `{ISSUER_BASE_URL}/.well-known/jwks.json`
- The middleware fetches and caches keys automatically

### .env file (development)

```env
# .env — Never commit to source control
ISSUER_BASE_URL=https://your-tenant.us.auth0.com
AUDIENCE=https://your-api.example.com
PORT=3000
```

### Production environment variables

Set these as environment variables in your hosting platform (not in `.env` files):

| Variable | Example Value |
|----------|--------------|
| `ISSUER_BASE_URL` | `https://your-tenant.us.auth0.com` |
| `AUDIENCE` | `https://your-api.example.com` |
| `PORT` | `3000` |

**Never commit `.env` to source control.** Add `.env` to `.gitignore`:
```bash
echo ".env" >> .gitignore
```

**Load `.env` in your entry file:**
```javascript
import 'dotenv/config'; // must be at the top
// or: require('dotenv').config();
```

## Verification

After setup, verify everything is working:

1. **Start the server:**
   ```bash
   node server.js
   # or: npm start
   ```

2. **Test public endpoint:**
   ```bash
   curl http://localhost:3000/api/public
   # Expected: 200 OK
   ```

3. **Test protected endpoint without token:**
   ```bash
   curl http://localhost:3000/api/private
   # Expected: 401 Unauthorized
   ```

4. **Get a test token** from Auth0 Dashboard → APIs → your API → Test tab, then:
   ```bash
   curl -H "Authorization: Bearer <your-test-token>" http://localhost:3000/api/private
   # Expected: 200 OK with payload data
   ```
