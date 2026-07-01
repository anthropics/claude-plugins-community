# Auth0 Express Integration Patterns

Server-side authentication patterns for Express.js.

---

## Protected Routes

### Single Route

```javascript
const { requiresAuth } = require('express-openid-connect');

app.get('/admin', requiresAuth(), (req, res) => {
  res.send(`Admin: ${req.oidc.user.name}`);
});
```

### Multiple Routes

```javascript
// Protect all /admin routes
app.use('/admin', requiresAuth());

app.get('/admin/dashboard', (req, res) => {
  res.send('Dashboard');
});

app.get('/admin/settings', (req, res) => {
  res.send('Settings');
});
```

### Require Auth Globally

```javascript
app.use(auth({
  authRequired: true  // All routes require authentication
}));

// Make specific routes public
app.get('/public', (req, res) => {
  res.send('Public page');
});
```

---

## Calling APIs

### Get Access Token

```javascript
app.get('/api-call', requiresAuth(), async (req, res) => {
  const { access_token } = req.oidc.accessToken;

  const response = await fetch('https://your-api.com/data', {
    headers: { Authorization: `Bearer ${access_token}` }
  });

  const data = await response.json();
  res.json(data);
});
```

Configure `authorizationParams` in middleware — **all three fields are required** to obtain an access token:

```javascript
// SDK auto-loads SECRET, BASE_URL, CLIENT_ID, ISSUER_BASE_URL, CLIENT_SECRET from env vars
app.use(auth({
  authorizationParams: {
    response_type: 'code',               // required: authorization code flow
    audience: 'https://your-api-identifier', // required: API identifier
    scope: 'openid profile email'        // required: token scopes
  }
}));
```

---

## Custom Login/Logout

### Custom Login Handler

```javascript
app.get('/custom-login', (req, res) => {
  res.oidc.login({
    returnTo: '/dashboard',
    authorizationParams: {
      connection: 'google-oauth2'
    }
  });
});
```

### Custom Logout Handler

```javascript
app.get('/custom-logout', (req, res) => {
  res.oidc.logout({
    returnTo: '/goodbye'
  });
});
```

---

## Silent Authentication

### Automatic Silent Login

Check if user is already authenticated at their IDP without forcing a login prompt.

```javascript
const { auth, attemptSilentLogin } = require('express-openid-connect');

app.use(auth({
  authRequired: false
}));

// Try silent authentication on first visit
app.use(attemptSilentLogin());

// Your routes
app.get('/', (req, res) => {
  if (req.oidc.isAuthenticated()) {
    res.send(`Welcome back, ${req.oidc.user.name}!`);
  } else {
    res.send('Not logged in <a href="/login">Login</a>');
  }
});
```

**How it works:**
- On the user's first visit, redirects to Auth0 with `prompt=none`
- If user has active IDP session, they're silently logged in
- If not, they see your page as anonymous
- Uses a cookie to prevent repeated silent login attempts

**Use cases:**
- Show login/logout button based on IDP session status
- Pre-authenticate users who have existing IDP sessions
- Provide seamless experience for returning users

---

## Session Management

### Access User Info

```javascript
app.get('/user', requiresAuth(), (req, res) => {
  res.json({
    isAuthenticated: req.oidc.isAuthenticated(),
    user: req.oidc.user,
    idToken: req.oidc.idToken,
    accessToken: req.oidc.accessToken
  });
});
```

### Refresh Tokens

```javascript
app.use(auth({
  authorizationParams: {
    scope: 'openid profile email offline_access'
  }
}));

// Access refresh token
app.get('/refresh', requiresAuth(), (req, res) => {
  const refreshToken = req.oidc.refreshToken;
  // Use refresh token
});
```

---

## Error Handling

```javascript
app.use((err, req, res, next) => {
  if (err.name === 'UnauthorizedError') {
    res.status(401).send('Unauthorized');
  } else {
    next(err);
  }
});
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Invalid state" | Regenerate SECRET |
| Session not persisting | Check cookie settings, use HTTPS in production |
| Redirect loop | Verify callback URL matches Auth0 config |

---

## Next Steps

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
