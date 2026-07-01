---
name: auth0-flask
description: >
  Use when adding session-based login, logout, or user profile to a Flask web application. Integrates auth0-server-python — use even if the user says "add login to my Flask app" or "protect my Flask routes".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Flask Web App Integration

Add login, logout, and user profile to a Flask web application using `auth0-server-python`.

---

## Prerequisites

- Flask application
- Auth0 Regular Web Application configured (not an API — must be an Application)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Python APIs with JWT Bearer validation** — Use `auth0-fastapi-api` for FastAPI, or see the [Django REST Framework quickstart](https://auth0.com/docs/quickstart/backend/django)
- **FastAPI web app with login/logout UI** — No dedicated skill yet; see the [FastAPI quickstart](https://auth0.com/docs/quickstart/webapp/python)
- **Single Page Applications** — Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Next.js applications** — Use `auth0-nextjs` which handles both client and server
- **Node.js web apps** — Use `auth0-express` or `auth0-fastify` for session-based auth

---

## Quick Start Workflow

### 1. Install SDK

```bash
pip install auth0-server-python "flask[async]" python-dotenv
```

**Critical:** You must install `flask[async]` (not just `flask`). The `[async]` extra installs `asgiref` which is required for Flask 2.0+ to support `async def` route handlers. Without it, async routes will not work. In `requirements.txt`, use `flask[async]>=2.0.0`.

### 2. Configure Environment

Create `.env`:

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
AUTH0_SECRET=your_generated_app_secret
AUTH0_REDIRECT_URI=http://localhost:5000/callback
```

`AUTH0_DOMAIN` is your Auth0 tenant domain (without `https://`). `AUTH0_CLIENT_ID` and `AUTH0_CLIENT_SECRET` come from your Auth0 Application settings. `AUTH0_SECRET` is used for encrypting session data — generate with `openssl rand -hex 64`.

### 3. Configure Auth0 Dashboard

In your Auth0 Application settings:
- **Allowed Callback URLs**: `http://localhost:5000/callback`
- **Allowed Logout URLs**: `http://localhost:5000`

### 4. Create Auth Module

Create `auth.py` to initialize the `ServerClient` with Flask session-based stores. The stores use Flask's built-in `session` (cookie-based by default) for a **stateless** setup — no external database needed:

```python
import os
from flask import session as flask_session
from auth0_server_python.auth_server.server_client import ServerClient
from auth0_server_python.auth_types import StateData, TransactionData
from auth0_server_python.store import StateStore, TransactionStore
from dotenv import load_dotenv

load_dotenv()  # Uses .env by default; pass load_dotenv(".env.local") if credentials are in .env.local


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
        # Ensure to not return a dict, as the underlying SDK expects a StateData instance, not a dict
        return StateData(**decrypted) if isinstance(decrypted, dict) else decrypted

    async def delete(self, identifier, options=None):
        flask_session.pop(identifier, None)

    async def delete_by_logout_token(self, claims, options=None):
        pass


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
        # Ensure to not return a dict, as the underlying SDK expects a TransactionData instance, not a dict
        return TransactionData(**decrypted) if isinstance(decrypted, dict) else decrypted

    async def delete(self, identifier, options=None):
        flask_session.pop(identifier, None)


secret = os.getenv("AUTH0_SECRET")

auth0 = ServerClient(
    domain=os.getenv("AUTH0_DOMAIN"),
    client_id=os.getenv("AUTH0_CLIENT_ID"),
    client_secret=os.getenv("AUTH0_CLIENT_SECRET"),
    secret=secret,
    redirect_uri=os.getenv("AUTH0_REDIRECT_URI"),
    state_store=FlaskSessionStateStore(secret=secret),
    transaction_store=FlaskSessionTransactionStore(secret=secret),
    authorization_params={"scope": "openid profile email"},
)
```

Create one `ServerClient` instance and reuse it. Never hardcode credentials — always use environment variables.

**How this works:** Flask's default session is cookie-based (stateless). The SDK encrypts session data (tokens, user profile) with JWE before storing it in the session, so data is both signed and encrypted in the cookie. No server-side database is required.

**No `store_options` or `before_request` needed:** The SDK supports passing `store_options` (e.g. request/response objects) to store methods. Since these stores use `flask.session` — which is globally available during a request — they don't need anything from `store_options`, so you can call SDK methods without passing it. If you implement a custom store that manages cookies directly (instead of using `flask.session`), you would need to reintroduce `store_options` with `{"request": request, "response": response}`.

**Cookie size note:** Stateless sessions store all data in a cookie (~4KB limit). For most apps this is sufficient. If you store large amounts of session data or hit cookie size limits, switch to [stateful setup](#stateful-setup-with-redis).

### 5. Configure Flask App

In `app.py`, set up Flask with the secret key and session configuration:

```python
import os
from flask import Flask, redirect, request
from auth import auth0
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("AUTH0_SECRET")
app.config.update(
    SESSION_COOKIE_SECURE=False,  # Set to True in production (requires HTTPS)
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
)
```

**Critical:** `app.secret_key` must be set for Flask session management. Without it, sessions won't work.

**For production:** Set `SESSION_COOKIE_SECURE=True` when deploying with HTTPS. Leaving it as `False` in production allows session cookies to be sent over unencrypted connections.

### 6. Add Home Route

```python
@app.route("/")
async def home():
    user = await auth0.get_user()
    if user:
        return f"Hello, {user['name']}! <a href='/profile'>Profile</a> | <a href='/logout'>Logout</a>"
    return "Welcome! <a href='/login'>Login</a>"
```

### 7. Add Login Route

```python
@app.route("/login")
async def login():
    authorization_url = await auth0.start_interactive_login()
    return redirect(authorization_url)
```

`start_interactive_login()` returns a URL string pointing to Auth0's Universal Login page. You must wrap it in `redirect()`. Authorization params (scope, redirect_uri) are already configured on the `ServerClient`.

### 8. Add Callback Route

```python
@app.route("/callback")
async def callback():
    try:
        await auth0.complete_interactive_login(str(request.url))
        return redirect("/")
    except Exception as e:
        return f"Authentication error: {str(e)}", 400
```

Pass `str(request.url)` as the first argument — this is the full callback URL including the authorization code query parameters. Always wrap in try/except since the token exchange can fail (e.g. expired code, CSRF mismatch).

### 9. Add Profile Route (Protected)

```python
@app.route("/profile")
async def profile():
    user = await auth0.get_user()
    if user is None:
        return redirect("/login")
    return (
        f"<h1>{user['name']}</h1>"
        f"<p>Email: {user['email']}</p>"
        f"<img src='{user['picture']}' alt='{user['name']}' width='100' />"
        f"<p><a href='/logout'>Logout</a></p>"
    )
```

`get_user()` returns the user's profile from the session, or `None` if not logged in.

### 10. Add Logout Route

```python
@app.route("/logout")
async def logout():
    url = await auth0.logout()
    return redirect(url)
```

`logout()` returns the Auth0 logout URL. Redirect the user to it.

### 11. Test the App

```bash
flask run
```

Visit `http://localhost:5000/login` to start the login flow.

---

## Stateful Setup with Redis

For production apps or when session data exceeds cookie size limits, use **Flask-Session** with Redis to store sessions server-side. Only a session ID is stored in the cookie.

### 1. Install Dependencies

```bash
pip install flask-session redis
```

### 2. Configure Flask-Session

Update `app.py` to use Redis-backed sessions:

```python
import os
from flask import Flask, redirect, request
from flask_session import Session
from auth import auth0
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("AUTH0_SECRET")
app.config.update(
    SESSION_TYPE="redis",
    SESSION_PERMANENT=True,
    SESSION_KEY_PREFIX="auth0:",
    SESSION_COOKIE_SECURE=False,
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
)
Session(app)
```

### 3. No Store Changes Needed

The same `FlaskSessionStateStore` and `FlaskSessionTransactionStore` from `auth.py` work without modification. Flask-Session transparently switches the `flask.session` backend from cookies to Redis — the stores continue to use `flask.session` as before.

**Routes are identical** to the stateless setup — no code changes needed.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hardcoding `domain`, `client_id`, or `client_secret` in source | Always read from environment variables — never embed credentials in code |
| Using `Authlib` or `python-jose` directly | Not needed; `auth0-server-python` handles all OAuth/OIDC flows |
| Using `Flask-Login` or `Flask-Dance` | Not needed; the SDK manages sessions and authentication |
| Manually parsing JWTs with `jwt.decode()` | The SDK handles token validation internally |
| Installing `flask` without `[async]` extra | Must use `flask[async]>=2.0.0` in requirements.txt — without it, async route handlers silently fail |
| Using synchronous route handlers | All routes calling SDK methods must be `async def` and use `await` |
| Forgetting `app.secret_key` | Required for Flask session management — without it, sessions silently fail |
| Using `auth0-fastapi-api` in Flask | That package is for FastAPI APIs — use `auth0-server-python` for Flask |
| Passing `domain` as full URL with `https://` | `domain` should be the bare domain, e.g. `my-tenant.us.auth0.com`, not `https://my-tenant.us.auth0.com` |
| Not configuring callback URL in Auth0 Dashboard | Must add `http://localhost:5000/callback` to Allowed Callback URLs |
| Returning `start_interactive_login()` directly | It returns a URL string, not a response — must wrap in `redirect()` |
| Not handling errors in `/callback` | `complete_interactive_login()` can fail — always wrap in try/except |
| Calling SDK methods without `await` | All SDK methods are async — forgetting `await` returns a coroutine instead of the result |
| Passing options positionally to `logout()` | Use `logout(store_options=...)` — the first positional parameter is `LogoutOptions`, not store options |
| Expecting backchannel logout to work | Not supported with cookie-based sessions — `delete_by_logout_token` is a no-op. Use standard `/logout` route |
| Deploying with `SESSION_COOKIE_SECURE=False` | Must set to `True` in production — cookies are sent over HTTP otherwise |

---

## Key SDK Methods

All methods are async:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `start_interactive_login` | `await auth0.start_interactive_login()` | Returns authorization URL string — wrap in `redirect()` |
| `complete_interactive_login` | `await auth0.complete_interactive_login(str(request.url))` | Processes the callback URL, exchanges code for tokens |
| `get_user` | `await auth0.get_user()` | Returns current session user dict or `None` |
| `get_access_token` | `await auth0.get_access_token()` | Returns the access token for calling external APIs |
| `logout` | `await auth0.logout()` | Returns Auth0 logout URL string |

---

## Related Skills

- `auth0-express` — For server-rendered Express web apps with login/logout sessions
- `auth0-fastify` — For Fastify web applications with session-based auth
- `auth0-cli` — Manage Auth0 resources from the terminal

---

## Quick Reference

**ServerClient configuration:**
```python
auth0 = ServerClient(
    domain=os.getenv("AUTH0_DOMAIN"),                    # required
    client_id=os.getenv("AUTH0_CLIENT_ID"),              # required
    client_secret=os.getenv("AUTH0_CLIENT_SECRET"),      # required
    secret=os.getenv("AUTH0_SECRET"),                    # required (encryption secret)
    redirect_uri=os.getenv("AUTH0_REDIRECT_URI"),        # required
    state_store=FlaskSessionStateStore(secret=secret),   # required
    transaction_store=FlaskSessionTransactionStore(secret=secret),  # required
    authorization_params={"scope": "openid profile email"},  # recommended
)
```

**Route protection pattern:**
```python
user = await auth0.get_user()
if user is None:
    return redirect("/login")
```

**Environment variables:**
- `AUTH0_DOMAIN` — your Auth0 tenant domain (e.g. `tenant.us.auth0.com`)
- `AUTH0_CLIENT_ID` — your Application's client ID
- `AUTH0_CLIENT_SECRET` — your Application's client secret
- `AUTH0_SECRET` — encryption and session secret key
- `AUTH0_REDIRECT_URI` — callback URL (e.g. `http://localhost:5000/callback`)

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup scripts, environment configuration, Auth0 CLI usage
- **[Integration Guide](references/integration.md)** - Protected routes, calling APIs, session management, error handling
- **[API Reference](references/api.md)** - Complete ServerClient API, configuration options, store implementation, security

---

## References

- [auth0-server-python on PyPI](https://pypi.org/project/auth0-server-python/)
- [Auth0 Flask Quickstart](https://auth0.com/docs/quickstart/webapp/python)
- [Flask Documentation](https://flask.palletsprojects.com/)
