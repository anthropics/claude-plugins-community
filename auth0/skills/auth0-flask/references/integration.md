# Auth0 Flask Integration Patterns

Server-side authentication patterns for Flask.

---

## Protected Routes

### Using Decorator Pattern

```python
from functools import wraps
from flask import redirect, render_template
from auth import auth0


def require_auth(f):
    @wraps(f)
    async def decorated_function(*args, **kwargs):
        user = await auth0.get_user()
        if user is None:
            return redirect("/login")
        return await f(*args, **kwargs)
    return decorated_function


@app.route("/admin")
@require_auth
async def admin():
    user = await auth0.get_user()
    return render_template("admin.html", user=user)
```

### Manual Check in Route

```python
@app.route("/dashboard")
async def dashboard():
    user = await auth0.get_user()
    if user is None:
        return redirect("/login")
    return render_template("dashboard.html", user=user)
```

### Blueprint Protection

```python
from flask import Blueprint, redirect, render_template
from auth import auth0

admin = Blueprint("admin", __name__, url_prefix="/admin")


@admin.before_request
async def check_auth():
    user = await auth0.get_user()
    if user is None:
        return redirect("/login")


@admin.route("/settings")
async def settings():
    user = await auth0.get_user()
    return render_template("settings.html", user=user)


app.register_blueprint(admin)
```

---

## Calling External APIs

### Get Access Token

```python
import httpx
from flask import jsonify, redirect
from auth import auth0


@app.route("/api-call")
async def api_call():
    user = await auth0.get_user()
    if user is None:
        return redirect("/login")

    try:
        access_token = await auth0.get_access_token()
    except Exception as e:
        return f"Access token error: {e}", 401

    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://your-api.com/data",
            headers={"Authorization": f"Bearer {access_token}"}
        )

    return jsonify(response.json())
```

### Configure Audience

Update the `ServerClient` initialization in `auth.py` to include `audience`:

```python
auth0 = ServerClient(
    domain=os.getenv("AUTH0_DOMAIN"),
    client_id=os.getenv("AUTH0_CLIENT_ID"),
    client_secret=os.getenv("AUTH0_CLIENT_SECRET"),
    secret=secret,
    redirect_uri=os.getenv("AUTH0_REDIRECT_URI"),
    state_store=FlaskSessionStateStore(secret=secret),
    transaction_store=FlaskSessionTransactionStore(secret=secret),
    authorization_params={
        "scope": "openid profile email",
        "audience": "https://your-api-identifier",  # Add this
    },
)
```

---

## Custom Login/Logout

### Custom Login with Connection

```python
from auth0_server_python.auth_types import StartInteractiveLoginOptions


@app.route("/login-google")
async def login_google():
    authorization_url = await auth0.start_interactive_login(
        options=StartInteractiveLoginOptions(
            authorization_params={"connection": "google-oauth2"}
        )
    )
    return redirect(authorization_url)
```

### Custom Logout with Return URL

```python
from auth0_server_python.auth_types import LogoutOptions


@app.route("/logout")
async def logout():
    url = await auth0.logout(
        options=LogoutOptions(return_to="http://localhost:5000/goodbye")
    )
    return redirect(url)
```

---

## Session Management

### Access User Information

```python
@app.route("/user-info")
async def user_info():
    user = await auth0.get_user()

    if user is None:
        return jsonify({"authenticated": False})

    return jsonify({
        "authenticated": True,
        "user": user,
    })
```

### Store Custom Session Data

```python
from flask import session as flask_session


@app.route("/callback")
async def callback():
    try:
        await auth0.complete_interactive_login(str(request.url))
        user = await auth0.get_user()

        # Store custom data alongside Auth0 session
        flask_session["user_role"] = "admin"

        return redirect("/")
    except Exception as e:
        return f"Authentication error: {str(e)}", 400
```

### Inject User via before_request

Make user available in all templates using a `before_request` hook (Flask supports async for `before_request` but not for `context_processor`):

```python
@app.before_request
async def load_user():
    g.user = await auth0.get_user()
```

Then in any template:

```html
{% if g.user %}
  <p>Welcome, {{ g.user.name }}!</p>
  <a href="/logout">Logout</a>
{% else %}
  <a href="/login">Login</a>
{% endif %}
```

---

## Error Handling

### Callback Error Handling

```python
@app.route("/callback")
async def callback():
    try:
        await auth0.complete_interactive_login(str(request.url))
        return redirect("/")
    except Exception as e:
        # State validation, token exchange, or other authentication errors
        return f"Authentication error: {str(e)}", 400
```

### Global Error Handler

```python
@app.errorhandler(401)
def unauthorized(error):
    return redirect("/login")
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Callback URL mismatch" | Ensure `AUTH0_REDIRECT_URI` matches Allowed Callback URLs in Auth0 Dashboard exactly |
| Session data lost on page reload | Check `app.secret_key` is set and Flask session is configured |
| Access token is None | Configure `audience` in ServerClient `authorization_params` |
| "Invalid state" error | Regenerate `AUTH0_SECRET` — it may be corrupted or too short |
| Async routes not working | Use `flask[async]>=2.0.0` (not just `flask`) |
| Redirect loop on login | Check that `/login` route is not itself protected by `require_auth` |

---

## Next Steps

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
