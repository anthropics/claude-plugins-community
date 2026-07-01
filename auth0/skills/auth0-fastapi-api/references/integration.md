# Auth0 FastAPI API Integration Patterns

Advanced integration patterns for FastAPI API applications.

---

## Scope-Based Authorization

### Define Permissions in Auth0

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Click the **Permissions** tab
4. Add permissions matching the scopes you want to enforce (e.g., `read:messages`, `write:messages`)

### Protect Routes with Scopes

```python
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
)

# Single scope
@app.get("/api/messages")
async def get_messages(claims: dict = Depends(auth0.require_auth(scopes="read:messages"))):
    return {"messages": []}

# Multiple scopes — ALL must be present (AND logic)
@app.delete("/api/resource/{id}")
async def delete_resource(
    id: str,
    claims: dict = Depends(auth0.require_auth(scopes=["delete:data", "admin:access"]))
):
    return {"deleted": id}
```

### Request Tokens with Scopes

Clients must request tokens that include the required scopes:

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

## DPoP Support

DPoP (Demonstrating Proof of Possession, RFC 9449) binds tokens to a specific client key pair, preventing token theft and replay.

### DPoP Modes

| Mode | Configuration | Behavior |
|------|--------------|----------|
| Mixed (default) | `dpop_enabled=True, dpop_required=False` | Accept both DPoP and Bearer tokens |
| Required | `dpop_required=True` | Only accept DPoP tokens; reject Bearer |
| Disabled | `dpop_enabled=False` | Bearer tokens only; reject DPoP |

### Enable DPoP (Mixed Mode — Recommended for Migration)

```python
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
    dpop_enabled=True,      # default
    dpop_required=False,    # default — accepts both Bearer and DPoP
)
```

### DPoP Required Mode

To reject standard Bearer tokens and accept only DPoP-bound tokens:

```python
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
    dpop_required=True,     # rejects Bearer tokens
)
```

### Custom DPoP Timing

```python
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
    dpop_enabled=True,
    dpop_iat_leeway=60,     # Clock skew tolerance in seconds (default: 30)
    dpop_iat_offset=600,    # Maximum DPoP proof age in seconds (default: 300)
)
```

### Bearer-Only Mode

Disable DPoP support entirely:

```python
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
    dpop_enabled=False,     # Bearer tokens only
)
```

### Client Requirements

To use DPoP authentication, clients must:

1. Generate an **ES256 key pair** for DPoP proof signing
2. Include **two headers** in requests:
   - `Authorization: DPoP <access-token>` — The DPoP-bound access token
   - `DPoP: <proof-jwt>` — The DPoP proof JWT (ES256-signed)

```bash
# DPoP request example
curl -H "Authorization: DPoP YOUR_ACCESS_TOKEN" \
     -H "DPoP: YOUR_DPOP_PROOF_JWT" \
     http://localhost:8000/api/protected
```

### Enable DPoP on Auth0 API

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Enable DPoP binding requirement

### Migration Strategy

Use mixed mode for gradual migration:

```python
# Phase 1: Accept both Bearer and DPoP (default)
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
    dpop_enabled=True,
    dpop_required=False,
)

# Phase 2: Enforce DPoP-only after all clients have migrated
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
    dpop_required=True,
)
```

### DPoP Error Responses

DPoP-specific validation failures return **400** with error code `invalid_dpop_proof`:

- Missing DPoP proof header
- Wrong algorithm (must be ES256)
- Expired proof (older than `dpop_iat_offset`)
- Thumbprint mismatch between proof and token binding

DPoP access token binding mismatches return **401** with `invalid_token`.

---

## Reverse Proxy Support

When deploying behind a reverse proxy (nginx, AWS ALB, Cloudflare CDN), you **must** enable proxy trust for DPoP validation to work correctly.

### Configuration

```python
from fastapi import FastAPI
from fastapi_plugin import Auth0FastAPI

app = FastAPI()

# Enable proxy trust — REQUIRED when behind a reverse proxy
app.state.trust_proxy = True

auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
    dpop_enabled=True,
)
```

### Why This Matters

- DPoP validation requires matching the exact URL the client used
- Behind a proxy, your app sees internal URLs (e.g., `http://localhost:8000/api`)
- The client's DPoP proof contains the public URL (e.g., `https://api.example.com/api`)
- Without `trust_proxy=True`, DPoP validation will fail

### Supported Headers

When `trust_proxy=True`, the SDK reads:
- `X-Forwarded-Proto` — Overrides scheme (http/https)
- `X-Forwarded-Host` — Overrides host (handles comma-separated values for multiple proxies)
- `X-Forwarded-Prefix` — Prepends path prefix (with path traversal protection)

### Nginx Configuration Example

```nginx
location /api {
    proxy_pass http://backend:8000;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Prefix /api;
}
```

**Important:** Only enable `trust_proxy=True` when your app is actually behind a trusted reverse proxy. Never enable for direct internet-facing deployments — it allows header injection attacks.

---

## Accessing User Claims

### Standard Claims

```python
@app.get("/api/profile")
async def profile(claims: dict = Depends(auth0.require_auth())):
    return {
        "user_id": claims["sub"],
        "scopes": claims.get("scope", "").split(),
        "issuer": claims["iss"],
    }
```

### Custom Claims

If your tokens include custom claims (added via Auth0 Actions), access them directly:

```python
@app.get("/api/custom")
async def custom_claims(claims: dict = Depends(auth0.require_auth())):
    permissions = claims.get("permissions", [])
    role = claims.get("https://example.com/role")
    return {"permissions": permissions, "role": role}
```

Custom claims added via Auth0 Actions use namespaced keys, e.g., `https://your-domain.com/role`.

### Common JWT Claims

| Claim | Description |
|-------|-------------|
| `sub` | User ID (subject) |
| `scope` | Space-separated list of granted scopes |
| `aud` | Audience (your API identifier) |
| `iss` | Issuer (your Auth0 tenant URL) |
| `exp` | Expiration timestamp |
| `iat` | Issued-at timestamp |

---

## Error Handling

### Standard Error Responses

| Status | Error Code | Cause | Fix |
|--------|------------|-------|-----|
| 400 | `invalid_request` | Missing or malformed Authorization header | Include valid `Authorization: Bearer <token>` header |
| 400 | `invalid_dpop_proof` | Invalid DPoP proof JWT (wrong algorithm, expired, missing) | Generate a valid ES256-signed DPoP proof |
| 401 | `invalid_token` | Expired token, invalid signature, wrong issuer/audience | Request a fresh access token with correct audience |
| 403 | `insufficient_scope` | Token lacks required scopes | Request token with required scopes |
| 500 | `internal_server_error` | Unexpected server error | Check server logs |

### Response Format

All error responses follow this structure:

```json
{
    "detail": {
        "error": "invalid_token",
        "error_description": "Token has expired"
    }
}
```

Responses on 400/401 errors may include `WWW-Authenticate` headers with error details.

### Custom Error Handling

Wrap protected routes with try/except for application-level error handling:

```python
from fastapi import HTTPException
from fastapi.responses import JSONResponse

@app.exception_handler(HTTPException)
async def custom_http_exception_handler(request, exc):
    if exc.status_code in (401, 403):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": exc.detail.get("error", "unauthorized"),
                "message": exc.detail.get("error_description", "Authentication required"),
            },
            headers=exc.headers or {},
        )
    raise exc
```

---

## Mixed Public and Protected Endpoints

```python
from fastapi import FastAPI, Depends
from fastapi_plugin import Auth0FastAPI

app = FastAPI()
auth0 = Auth0FastAPI(
    domain=os.getenv("AUTH0_DOMAIN"),
    audience=os.getenv("AUTH0_AUDIENCE"),
)

# Public — no auth needed
@app.get("/api/public")
async def public():
    return {"message": "Public endpoint"}

# Protected — requires valid JWT
@app.get("/api/private")
async def private(claims: dict = Depends(auth0.require_auth())):
    return {"message": "Private endpoint", "user_id": claims["sub"]}

# Protected with scope
@app.get("/api/messages")
async def messages(claims: dict = Depends(auth0.require_auth(scopes="read:messages"))):
    return {"messages": []}
```

---

## CORS Configuration

When your API receives requests from a browser-based SPA, configure CORS:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-spa-domain.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type", "DPoP"],
)
```

---

## Testing

### Basic Testing with FastAPI TestClient

```python
from fastapi import FastAPI, Depends
from fastapi.testclient import TestClient
from fastapi_plugin import Auth0FastAPI

app = FastAPI()
auth0 = Auth0FastAPI(domain="my-tenant.us.auth0.com", audience="my-api")

@app.get("/public")
async def public():
    return {"message": "No token required"}

@app.get("/secure")
async def secure(claims: dict = Depends(auth0.require_auth())):
    return {"message": f"Hello {claims['sub']}"}

def test_public_route():
    client = TestClient(app)
    response = client.get("/public")
    assert response.status_code == 200

def test_protected_route_without_token():
    client = TestClient(app)
    response = client.get("/secure")
    assert response.status_code == 400  # Missing Authorization header
```

### Integration Testing with Real Tokens

```bash
# Get a test token via Auth0 CLI
auth0 test token --audience https://my-api.example.com
```

```python
def test_protected_route_with_token():
    client = TestClient(app)
    response = client.get(
        "/secure",
        headers={"Authorization": "Bearer YOUR_TEST_TOKEN"},
    )
    assert response.status_code == 200
```

### Mocking Authentication

For unit tests without hitting Auth0's JWKS endpoints, use `pytest-httpx` or mock the verification method:

```python
from unittest.mock import AsyncMock, patch

@patch.object(auth0.api_client, "verify_request", new_callable=AsyncMock)
async def test_with_mocked_auth(mock_verify):
    mock_verify.return_value = {"sub": "user123", "scope": "read:data"}
    client = TestClient(app)
    response = client.get(
        "/secure",
        headers={"Authorization": "Bearer mock-token"},
    )
    assert response.status_code == 200
```

---

## Security Considerations

- **Never hardcode Domain or Audience** — Always use environment variables or configuration files
- **Use HTTPS in production** — Auth0 requires HTTPS for token validation
- **Use minimal scopes** — Only request and enforce scopes your API actually needs
- **Keep packages updated** — Regularly update `auth0-fastapi-api` for security patches
- **Only enable `trust_proxy` behind trusted proxies** — Never for direct internet-facing deployments
- **Validate access tokens, not ID tokens** — ID tokens are for the client app, access tokens are for API authorization

---

## References

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
