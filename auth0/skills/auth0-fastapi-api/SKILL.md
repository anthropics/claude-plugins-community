---
name: auth0-fastapi-api
description: >
  Use when protecting FastAPI endpoints with JWT Bearer token validation, scope checks, or DPoP binding. Integrates auth0-fastapi-api for stateless APIs receiving access tokens — use even if the user says "secure my FastAPI endpoints" or "validate tokens in FastAPI".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 FastAPI API Integration

Protect FastAPI API endpoints with JWT access token validation using `auth0-fastapi-api`.

> **Note:** This SDK is currently in beta. The API surface may change before the stable 1.0 release. Check [PyPI](https://pypi.org/project/auth0-fastapi-api/) for the latest version. Requires Python >= 3.9 and FastAPI >= 0.115.11.

---

## Prerequisites

- FastAPI application (Python 3.9+)
- Auth0 API resource configured (not an Application — must be an API)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Server-rendered web applications** — Use a session-based login/logout flow instead
- **Single Page Applications** — Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Mobile applications** — Use `auth0-react-native` or `auth0-android`
- **Issuing tokens** — This skill is for *validating* access tokens, not issuing them

---

## Quick Start Workflow

### 1. Install SDK

```bash
pip install auth0-fastapi-api python-dotenv
```

### 2. Create Auth0 API

You need an **API** (not Application) in Auth0.

> **STOP — ask the user before proceeding.**
>
> Ask exactly this question and wait for their answer before doing anything else:
>
> > "How would you like to create the Auth0 API resource?
> > 1. **Automated** — I'll run Auth0 CLI scripts that create the resource and write the exact values to your `.env` automatically.
> > 2. **Manual** — You create the API yourself in the Auth0 Dashboard (or via `auth0 apis create`) and provide me the Domain and Audience.
> >
> > Which do you prefer? (1 = Automated / 2 = Manual)"
>
> Do NOT proceed to any setup steps until the user has answered. Do NOT default to manual.

**If the user chose Automated**, follow the [Setup Guide](references/setup.md) for complete CLI scripts. The automated path writes `.env` for you — skip Step 3 below and proceed directly to Step 4.

**If the user chose Manual**, follow the [Setup Guide](references/setup.md) (Manual Setup section) for full instructions. Then continue with Step 3 below.

Quick reference for manual API creation:

```bash
# Using Auth0 CLI
auth0 apis create \
  --name "My FastAPI API" \
  --identifier https://my-api.example.com
```

Or create manually in Auth0 Dashboard → Applications → APIs

### 3. Configure Environment

Create `.env`:

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_AUDIENCE=https://your-api.example.com
```

`AUTH0_DOMAIN` is your Auth0 tenant domain (without `https://`). `AUTH0_AUDIENCE` is the API identifier you set when creating the API resource in Auth0.

### 4. Initialize Auth0

```python
import os
from fastapi import FastAPI, Depends
from fastapi_plugin import Auth0FastAPI
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
)
```

Create one `Auth0FastAPI` instance per application and reuse it across routes. Never hardcode the domain or audience — always use environment variables.

### 5. Protect Routes

```python
# Require any valid access token
@app.get("/api/private")
async def private(claims: dict = Depends(auth0.require_auth())):
    return {"user": claims["sub"]}

# No authentication required
@app.get("/api/public")
async def public():
    return {"message": "Public endpoint"}
```

The `require_auth()` dependency validates the Bearer token, verifies the issuer and audience, and returns the decoded JWT claims.

Error responses:
- **400** `invalid_request` — Missing or malformed Authorization header
- **401** `invalid_token` — Expired token, invalid signature, wrong issuer/audience
- **403** `insufficient_scope` — Valid token but missing required scopes
- **500** `internal_server_error` — Unexpected errors

Response body format: `{"detail": {"error": "...", "error_description": "..."}}`

### 6. Protect Routes with Scope Checks

```python
# Requires the read:messages scope
@app.get("/api/messages")
async def get_messages(claims: dict = Depends(auth0.require_auth(scopes="read:messages"))):
    return {"messages": []}

# Requires both read:data and write:data scopes
@app.post("/api/data")
async def write_data(claims: dict = Depends(auth0.require_auth(scopes=["read:data", "write:data"]))):
    return {"created": True}
```

`require_auth(scopes=...)` checks the `scope` claim in the JWT. All specified scopes must be present (AND logic). Missing scopes return **403**.

### 7. Access Token Claims

The decoded JWT claims are returned directly from the dependency:

```python
@app.get("/api/profile")
async def profile(claims: dict = Depends(auth0.require_auth())):
    return {
        "sub": claims["sub"],       # user ID
        "scope": claims.get("scope"),  # granted scopes
    }
```

Key claims:
- `claims["sub"]` — user/client ID
- `claims["scope"]` — space-separated granted scopes
- `claims["iss"]` — issuer (your Auth0 domain URL)
- `claims["aud"]` — audience
- `claims["exp"]` — expiration timestamp
- `claims["iat"]` — issued-at timestamp

### 8. Protect Routes Without Needing Claims

```python
@app.get("/api/protected", dependencies=[Depends(auth0.require_auth())])
async def protected():
    return {"message": "You need a valid access token to see this."}
```

### 9. Test the API

```bash
# No token — expect 401
curl http://localhost:8000/api/private

# With a valid access token
curl http://localhost:8000/api/private \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Get a test token via Client Credentials flow or Auth0 Dashboard → APIs → Test tab.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hardcoding `domain` or `audience` in source | Always read from environment variables — never embed credentials in code |
| Using `python-jose` or `PyJWT` directly | Not needed; `auth0-fastapi-api` handles all validation via JWKS |
| Manually parsing `Authorization` header | The SDK extracts and validates the token automatically |
| Calling `jwt.decode()` manually | The SDK verifies tokens against the JWKS endpoint — do not verify yourself |
| Using `fastapi-users` for Auth0 JWT validation | That package is for user management, not Auth0 JWT verification |
| Created an Application instead of an API in Auth0 | Must create an **API** resource (Applications → APIs) — an Application doesn't issue access tokens with the right audience |
| Passing `domain` as full URL with `https://` | `domain` should be the bare domain, e.g. `my-tenant.us.auth0.com`, not `https://my-tenant.us.auth0.com` |
| Using an ID token instead of an access token | Must use the **access token** for API auth — ID tokens are for the client app, not for API authorization |
| Not configuring CORS for SPA clients | Add `CORSMiddleware` to allow requests from your frontend origin |
| `os.getenv()` returns `None` silently | Ensure `python-dotenv` is installed and `load_dotenv()` is called before `Auth0FastAPI()` initialization — or use `os.environ[]` to fail fast |

---

## DPoP Support

Built-in proof-of-possession token binding per RFC 9449. DPoP is enabled by default in mixed mode (accepts both Bearer and DPoP tokens). See [Integration Guide](references/integration.md#dpop-support) for configuration.

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup and framework detection
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Auth0FastAPI configuration:**
```python
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),       # required (or use domains)
    audience=os.getenv("AUTH0_AUDIENCE"),    # required
    dpop_enabled=True,                       # default; set False for Bearer-only
    dpop_required=False,                     # default; set True to reject Bearer tokens
)
```

**Route protection:**
```python
Depends(auth0.require_auth())                    # any valid token
Depends(auth0.require_auth(scopes="read:res"))   # single scope
Depends(auth0.require_auth(scopes=["r", "w"]))   # all scopes required
```

**Accessing claims:**
```python
claims["sub"]           # user/client ID
claims["scope"]         # space-separated scopes
```

**Environment variables:**
- `AUTH0_DOMAIN` — your Auth0 tenant domain (e.g. `tenant.us.auth0.com`)
- `AUTH0_AUDIENCE` — your API identifier (e.g. `https://api.example.com`)

**Common Use Cases:**
- Protect routes → `Depends(auth0.require_auth())` (see Step 5)
- Scope enforcement → `Depends(auth0.require_auth(scopes="..."))` (see Step 6)
- DPoP token binding → [Integration Guide](references/integration.md#dpop-support)
- Reverse proxy setup → [Integration Guide](references/integration.md#reverse-proxy-support)
- Advanced configuration → [API Reference](references/api.md)

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** — Auth0 CLI setup, environment configuration, getting test tokens
- **[Integration Guide](references/integration.md)** — DPoP, scopes, error handling, reverse proxy, testing
- **[API Reference](references/api.md)** — Complete constructor options, method signatures, error codes

---

## References

- [auth0-fastapi-api GitHub](https://github.com/auth0/auth0-fastapi-api)
- [auth0-fastapi-api on PyPI](https://pypi.org/project/auth0-fastapi-api/)
- [Auth0 FastAPI API Quickstart](https://auth0.com/docs/quickstart/backend/fastapi)
- [FastAPI Dependency Injection](https://fastapi.tiangolo.com/tutorial/dependencies/)
- [Access Tokens Guide](https://auth0.com/docs/secure/tokens/access-tokens)
