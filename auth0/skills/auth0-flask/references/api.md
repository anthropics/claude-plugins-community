# Auth0 Flask API Reference

Complete configuration and API reference for Flask authentication.

---

## ServerClient Configuration

### Complete Configuration Options

```python
from auth0_server_python.auth_server.server_client import ServerClient

secret = os.getenv("AUTH0_SECRET")

auth0 = ServerClient(
    domain=os.getenv("AUTH0_DOMAIN"),                    # required: tenant domain (without https://)
    client_id=os.getenv("AUTH0_CLIENT_ID"),              # required: app client ID
    client_secret=os.getenv("AUTH0_CLIENT_SECRET"),      # required: app client secret
    secret=secret,                                       # required: encryption secret (min 32 chars)
    redirect_uri=os.getenv("AUTH0_REDIRECT_URI"),        # required: callback URL
    state_store=FlaskSessionStateStore(secret=secret),   # required: state persistence
    transaction_store=FlaskSessionTransactionStore(secret=secret),  # required: transaction persistence
    authorization_params={                                # optional: OAuth params
        "scope": "openid profile email",
        "audience": "https://your-api-identifier",
    },
)
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `domain` | Yes | Auth0 tenant domain (e.g., `tenant.us.auth0.com`) — without `https://` |
| `client_id` | Yes | Application client ID from Auth0 Dashboard |
| `client_secret` | Yes | Application client secret from Auth0 Dashboard |
| `secret` | Yes | Encryption secret for JWE — generate with `openssl rand -hex 64` |
| `redirect_uri` | Yes | Callback URL (e.g., `http://localhost:5000/callback`) |
| `state_store` | Yes | Store implementation for session state |
| `transaction_store` | Yes | Store implementation for OAuth transaction data |
| `authorization_params` | No | Default OAuth parameters (scope, audience, connection) |

---

## Flask Session Configuration

### Cookie-Based Sessions (Stateless)

```python
app = Flask(__name__)
app.secret_key = os.getenv("AUTH0_SECRET")
app.config.update(
    SESSION_COOKIE_SECURE=False,       # Set to True in production (requires HTTPS)
    SESSION_COOKIE_HTTPONLY=True,       # Prevents JavaScript access to cookie
    SESSION_COOKIE_SAMESITE="Lax",     # CSRF protection
)
```

| Option | Default | Description |
|--------|---------|-------------|
| `SESSION_COOKIE_SECURE` | `False` | Only send cookie over HTTPS — **must be `True` in production** |
| `SESSION_COOKIE_HTTPONLY` | `True` | Prevent JavaScript access to session cookie |
| `SESSION_COOKIE_SAMESITE` | `None` | CSRF protection — use `"Lax"` for auth flows |
| `PERMANENT_SESSION_LIFETIME` | 31 days | Session expiration (accepts `timedelta`) |

Cookie size limit: ~4KB. Sufficient for most apps with `openid profile email` scopes.

### Redis-Based Sessions (Stateful)

```python
from flask_session import Session

app = Flask(__name__)
app.secret_key = os.getenv("AUTH0_SECRET")
app.config.update(
    SESSION_TYPE="redis",
    SESSION_PERMANENT=True,
    SESSION_KEY_PREFIX="auth0:",
    SESSION_COOKIE_SECURE=False,       # Set to True in production
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
)
Session(app)
```

No store code changes needed — Flask-Session transparently switches the `flask.session` backend from cookies to Redis. The same `FlaskSessionStateStore` and `FlaskSessionTransactionStore` work without modification.

---

## ServerClient Methods

All methods are async and must be called with `await`.

### start_interactive_login()

Initiates the OAuth login flow and returns an authorization URL.

```python
authorization_url = await auth0.start_interactive_login()
return redirect(authorization_url)
```

**Returns:** URL string — must wrap in `redirect()`.

**With options:**

```python
from auth0_server_python.auth_types import StartInteractiveLoginOptions

authorization_url = await auth0.start_interactive_login(
    options=StartInteractiveLoginOptions(
        authorization_params={
            "connection": "google-oauth2",
            "screen_hint": "signup",
        }
    )
)
```

### complete_interactive_login(url)

Processes the callback URL, exchanges the authorization code for tokens, and stores session state.

```python
await auth0.complete_interactive_login(str(request.url))
```

**Parameters:**
- `url` (string): Full callback URL including query parameters

**Raises:** Exception on state mismatch (CSRF), missing parameters, or token exchange failures.

### get_user()

Retrieves the current authenticated user from the session.

```python
user = await auth0.get_user()
```

**Returns:** User dict or `None` if not authenticated.

**User dict keys:**
- `sub` — Auth0 user ID (e.g., `google-oauth2|123456`)
- `name` — Display name
- `email` — Email address
- `picture` — Avatar URL
- `email_verified` — Boolean

### get_access_token()

Retrieves the access token for calling external APIs. Handles token refresh automatically if a refresh token is available and the access token is expired.

```python
access_token = await auth0.get_access_token()
```

**Returns:** Access token string. **Raises** on failure (e.g. expired token without refresh token).

**Requires:** `audience` parameter in `authorization_params` during ServerClient initialization.

### logout()

Clears the session and returns the Auth0 logout URL.

```python
url = await auth0.logout()
return redirect(url)
```

**Returns:** Auth0 logout URL string — must wrap in `redirect()`.

**With options:**

```python
from auth0_server_python.auth_types import LogoutOptions

url = await auth0.logout(
    options=LogoutOptions(return_to="http://localhost:5000/goodbye")
)
```

---

## Store Implementation

Both stores use Flask's built-in `session` object. Since `flask.session` is a context-local available during any request, the stores don't need `store_options` — they access the session directly.

### FlaskSessionStateStore

Stores OAuth state (user profile, tokens) in Flask session, encrypted with JWE.

```python
from flask import session as flask_session
from auth0_server_python.auth_types import StateData
from auth0_server_python.store import StateStore


class FlaskSessionStateStore(StateStore):
    """State store that uses Flask's session for persistence."""

    def __init__(self, secret: str):
        super().__init__({"secret": secret})

    async def set(self, identifier, state, remove_if_expires=False, options=None):
        data = state.dict() if hasattr(state, "dict") else state
        flask_session[identifier] = self.encrypt(identifier, data)

    async def get(self, identifier, options=None):
        data = flask_session.get(identifier)
        if data is None:
            return None
        decrypted = self.decrypt(identifier, data)
        return StateData(**decrypted) if isinstance(decrypted, dict) else decrypted

    async def delete(self, identifier, options=None):
        flask_session.pop(identifier, None)

    async def delete_by_logout_token(self, claims, options=None):
        pass  # Not supported with stateless cookie sessions
```

### FlaskSessionTransactionStore

Stores transaction data (PKCE code_verifier, nonce, state) during the login flow, encrypted with JWE.

```python
from flask import session as flask_session
from auth0_server_python.auth_types import TransactionData
from auth0_server_python.store import TransactionStore


class FlaskSessionTransactionStore(TransactionStore):
    """Transaction store that uses Flask's session for persistence."""

    def __init__(self, secret: str):
        super().__init__({"secret": secret})

    async def set(self, identifier, state, remove_if_expires=False, options=None):
        data = state.dict() if hasattr(state, "dict") else state
        flask_session[identifier] = self.encrypt(identifier, data)

    async def get(self, identifier, options=None):
        data = flask_session.get(identifier)
        if data is None:
            return None
        decrypted = self.decrypt(identifier, data)
        return TransactionData(**decrypted) if isinstance(decrypted, dict) else decrypted

    async def delete(self, identifier, options=None):
        flask_session.pop(identifier, None)
```

**Why no `store_options`:** The SDK passes `store_options` (typically `{"request": request, "response": response}`) to store methods. Since Flask's `session` is a context-local that's automatically available during any request, the stores don't need request/response objects passed in — they access `flask_session` directly. The SDK passes `None` through without error.

---

## Security Considerations

### SESSION_COOKIE_SECURE

```python
# Development (localhost HTTP)
SESSION_COOKIE_SECURE=False

# Production (HTTPS required)
SESSION_COOKIE_SECURE=True
```

Setting `SESSION_COOKIE_SECURE=False` in production is a security risk — session cookies will be sent over unencrypted HTTP connections, exposing them to interception.

### Backchannel Logout Limitation

Backchannel logout (Auth0 sending a server-to-server logout token) is **not supported** with Flask session stores. The `delete_by_logout_token` method is a no-op because there is no server-side session store to query and delete from — session data lives in the user's browser cookie.

**Impact:** If a user logs out from another application in the same Auth0 tenant, their Flask session will not be automatically revoked. The session persists until the user makes a new request and the app clears it, or the cookie expires.

**Workaround:** For enterprise scenarios requiring federated logout, switch to Redis-backed sessions where you can implement `delete_by_logout_token` to scan and delete matching sessions.

### Cookie Size Limits

Stateless cookie sessions are limited to ~4KB by browsers. The SDK encrypts tokens and user profile with JWE before storing in the session. For typical apps with `openid profile email` scopes, this is well within limits.

**When it breaks:** Large custom claims, multiple audience tokens, or extensive user metadata can exceed the limit. The browser silently truncates or rejects the cookie, causing mysterious session loss.

**Fix:** Switch to Redis-backed sessions (see [Flask Session Configuration](#redis-based-sessions-stateful)).

### Best Practices

- **Keep secrets secure** — Never commit `.env` to version control
- **Use HTTPS in production** — `SESSION_COOKIE_SECURE=True` requires HTTPS
- **Rotate secrets regularly** — Update `AUTH0_SECRET` periodically
- **Validate audience** — For API calls, always configure `audience` parameter
- **Handle errors** — Always wrap `complete_interactive_login` in try/except

---

## Testing

### Local Testing

1. Start your app: `flask run`
2. Visit `http://localhost:5000/login`
3. Complete Auth0 login flow
4. Verify redirect to callback and session established
5. Visit protected route (e.g., `/profile`)
6. Click logout and verify session cleared

---

## References

- [auth0-server-python on PyPI](https://pypi.org/project/auth0-server-python/)
- [auth0-server-python GitHub](https://github.com/auth0/auth0-server-python)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Flask-Session Documentation](https://flask-session.readthedocs.io/)

---

## Next Steps

- [Integration Guide](integration.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
