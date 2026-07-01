# Auth0 FastAPI API - API Reference

Complete reference for `auth0-fastapi-api` configuration options and methods.

---

## Auth0FastAPI

Main class for protecting FastAPI API routes with Auth0 JWT validation.

```python
from fastapi_plugin import Auth0FastAPI
```

### Constructor

```python
Auth0FastAPI(
    domain=None,
    audience="",
    domains=None,
    client_id=None,
    client_secret=None,
    custom_fetch=None,
    dpop_enabled=True,
    dpop_required=False,
    dpop_iat_leeway=30,
    dpop_iat_offset=300,
    cache_adapter=None,
    cache_ttl_seconds=600,
    cache_max_entries=100,
)
```

### Constructor Parameters

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `domain` | `str` | `None` | Yes* | Auth0 tenant domain (e.g., `my-tenant.us.auth0.com`). No `https://` prefix. Required unless `domains` is provided. |
| `audience` | `str` | `""` | Yes | API identifier from Auth0 Dashboard. Must exactly match the API Identifier. |
| `domains` | `list[str]` or `Callable` | `None` | No | List of allowed domain strings or a callable resolver for multi-custom domain (MCD) mode. Optional if `domain` is provided. |
| `client_id` | `str` | `None` | No | Client ID for token exchange flows (e.g., `get_access_token_for_connection()`) |
| `client_secret` | `str` | `None` | No | Client secret for token exchange flows |
| `custom_fetch` | `Callable` | `None` | No | Optional HTTP fetch override. Signature: `async def custom_fetch(url, **kwargs)` |
| `dpop_enabled` | `bool` | `True` | No | Enable DPoP support. When `True`, accepts both Bearer and DPoP tokens (unless `dpop_required=True`). |
| `dpop_required` | `bool` | `False` | No | Require DPoP authentication and reject Bearer tokens. Only meaningful when `dpop_enabled=True`. |
| `dpop_iat_leeway` | `int` | `30` | No | Clock skew tolerance for DPoP proof `iat` claim in seconds. |
| `dpop_iat_offset` | `int` | `300` | No | Maximum DPoP proof age in seconds (5 minutes default). |
| `cache_adapter` | `CacheAdapter` | `None` | No | Custom cache backend. If `None`, uses `InMemoryCache`. |
| `cache_ttl_seconds` | `int` | `600` | No | Cache time-to-live in seconds (10 minutes default). |
| `cache_max_entries` | `int` | `100` | No | Maximum cache entries before LRU eviction. Ignored when `cache_adapter` is provided. |

**Raises:** `ValueError` if `audience` is empty or not provided.

---

## require_auth()

Returns a FastAPI dependency that validates the incoming request and returns decoded JWT claims.

```python
auth0.require_auth(scopes=None)
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scopes` | `str` or `list[str]` or `None` | `None` | Optional scope(s) to validate. All specified scopes must be present (AND logic). |

### Return Value

Returns an async FastAPI dependency function (`async def _dependency(request: Request) -> dict`).

On success, the dependency returns a `dict` containing the decoded JWT claims (payload).

### Usage

```python
# No scope check
Depends(auth0.require_auth())

# Single scope
Depends(auth0.require_auth(scopes="read:data"))

# Multiple scopes — all required
Depends(auth0.require_auth(scopes=["read:data", "write:data"]))

# As route dependency (no claims in handler)
@app.get("/api/protected", dependencies=[Depends(auth0.require_auth())])
async def protected():
    return {"message": "Protected"}
```

### Error Responses

| Status | Error Code | Cause |
|--------|------------|-------|
| 400 | `invalid_request` | Missing or malformed Authorization header, unsupported auth scheme |
| 400 | `invalid_dpop_proof` | DPoP proof validation failure (missing proof, wrong algorithm, expired, thumbprint mismatch) |
| 401 | `invalid_token` | Expired token, invalid signature, wrong issuer, wrong audience, DPoP binding mismatch |
| 403 | `insufficient_scope` | Valid token but missing required scopes |
| 500 | `internal_server_error` | Unexpected error during verification |

All errors return:

```json
{
    "detail": {
        "error": "<error_code>",
        "error_description": "<human-readable message>"
    }
}
```

Errors on 400/401 may include `WWW-Authenticate` response headers.

---

## DPoP Configuration

### DPoP Modes

| Mode | `dpop_enabled` | `dpop_required` | Behavior |
|------|---------------|-----------------|----------|
| Mixed (default) | `True` | `False` | Accepts both Bearer and DPoP tokens |
| Required | `True` | `True` | Only DPoP tokens; rejects Bearer with 400 |
| Disabled | `False` | `False` | Bearer only; rejects DPoP tokens |

### DPoP Timing Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `dpop_iat_leeway` | `30` | Clock skew tolerance in seconds for DPoP proof `iat` claim |
| `dpop_iat_offset` | `300` | Maximum DPoP proof age in seconds (reject older proofs as potential replay) |

---

## Reverse Proxy Configuration

Enable `X-Forwarded-*` header trust for deployments behind reverse proxies:

```python
app.state.trust_proxy = True
```

| Setting | Default | Description |
|---------|---------|-------------|
| `app.state.trust_proxy` | `False` | When `True`, SDK uses `X-Forwarded-Proto`, `X-Forwarded-Host`, `X-Forwarded-Prefix` for URL reconstruction |

**Security:** Only enable when behind a trusted reverse proxy. The SDK includes path traversal protection for `X-Forwarded-Prefix`.

---

## Multiple Custom Domains (MCD)

### Static Allowlist

```python
auth0 = Auth0FastAPI(
    audience="<AUTH0_AUDIENCE>",
    domains=["brand1.auth.example.com", "brand2.auth.example.com"],
)
```

### Dynamic Domain Resolver

```python
from fastapi_plugin import DomainsResolverContext

def domains_resolver(context: DomainsResolverContext) -> list:
    request_url = context.get("request_url")
    # Map request to allowed issuer domains
    return ["brand1.auth.example.com"]

auth0 = Auth0FastAPI(
    audience="<AUTH0_AUDIENCE>",
    domains=domains_resolver,
)
```

The `DomainsResolverContext` dict contains:
- `request_url` — The reconstructed request URL
- `request_headers` — Request headers (lowercase keys)
- `unverified_iss` — Issuer from token before signature verification

### `domain` vs `domains`

- When both are set, `domains` is used exclusively for token verification
- `domain` is retained only for client flows (e.g., `get_access_token_for_connection()`)
- If `domains` is not set, `domain` is used for discovery and verification

---

## Cache Configuration

### Default Cache

The SDK uses an in-memory LRU cache with:
- `cache_ttl_seconds`: 600 (10 minutes)
- `cache_max_entries`: 100

### Custom In-Memory Cache

```python
auth0 = Auth0FastAPI(
    domain="<AUTH0_DOMAIN>",
    audience="<AUTH0_AUDIENCE>",
    cache_ttl_seconds=1200,     # 20 minutes
    cache_max_entries=200,
)
```

### Custom Cache Adapter

```python
from fastapi_plugin import CacheAdapter

class RedisCache(CacheAdapter):
    def __init__(self, redis_client):
        self.redis = redis_client

    def get(self, key: str):
        return self.redis.get(key)

    def set(self, key: str, value, ttl_seconds=None):
        self.redis.set(key, value, ex=ttl_seconds)

    def delete(self, key: str):
        self.redis.delete(key)

    def clear(self):
        self.redis.flushdb()

auth0 = Auth0FastAPI(
    domain="<AUTH0_DOMAIN>",
    audience="<AUTH0_AUDIENCE>",
    cache_adapter=RedisCache(redis_client),
    cache_ttl_seconds=1200,
)
```

---

## Exports

```python
from fastapi_plugin import (
    Auth0FastAPI,              # Main class
    CacheAdapter,              # Interface for custom cache implementations
    ConfigurationError,        # Raised when configuration is invalid
    DomainsResolver,           # Type alias for domain resolver functions
    DomainsResolverContext,    # Dict type for domain resolver context
    DomainsResolverError,      # Raised when domain resolver fails
    InMemoryCache,             # Default in-memory LRU cache
)
```

---

## api_client Property

The underlying `ApiClient` instance is accessible for advanced operations:

```python
# Token exchange for upstream IdP connections
connection_token = await auth0.api_client.get_access_token_for_connection({
    "connection": "my-connection",
    "access_token": user_access_token,
})
```

Requires `client_id` and `client_secret` to be set in the constructor.

---

## References

- [auth0-fastapi-api GitHub](https://github.com/auth0/auth0-fastapi-api)
- [auth0-fastapi-api on PyPI](https://pypi.org/project/auth0-fastapi-api/)
- [Integration Guide](integration.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
