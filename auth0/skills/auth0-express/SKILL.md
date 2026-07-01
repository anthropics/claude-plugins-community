---
name: auth0-express
description: >
  Use when adding session-based login, logout, or protected routes to an Express.js web application. Integrates express-openid-connect — use even if the user says "add login to my Express app" or "protect my Express routes".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Express Integration

Add authentication to Express.js web applications using express-openid-connect.

---

## Prerequisites

- Express.js application
- Auth0 account and application configured
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Single Page Applications** - Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Next.js applications** - Use `auth0-nextjs` skill which handles both client and server
- **Mobile applications** - Use `auth0-react-native` for React Native/Expo
- **Stateless APIs** - Use JWT validation middleware instead of session-based auth
- **Microservices** - Use JWT validation for service-to-service auth

---

## Quick Start Workflow

### 1. Install SDK

```bash
npm install express-openid-connect dotenv
```

### 2. Configure Environment

**For automated setup with Auth0 CLI**, see [Setup Guide](references/setup.md) for complete scripts.

**For manual setup:**

Create `.env`:

```bash
SECRET=<openssl-rand-hex-32>
BASE_URL=http://localhost:3000
CLIENT_ID=your-client-id
CLIENT_SECRET=your-client-secret
ISSUER_BASE_URL=https://your-tenant.auth0.com
AUDIENCE=https://your-api-identifier  # only required if calling external APIs (Step 3a)
```

Generate secret: `openssl rand -hex 32`

### 3. Configure Auth Middleware

Update your Express app (`app.js` or `index.js`):

```javascript
require('dotenv').config();
const express = require('express');
const { auth, requiresAuth } = require('express-openid-connect');

const app = express();

// Configure Auth0 middleware
app.use(auth({
  authRequired: false,  // Don't require auth for all routes
  auth0Logout: true,    // Enable logout endpoint
  secret: process.env.SECRET,
  baseURL: process.env.BASE_URL,
  clientID: process.env.CLIENT_ID,
  issuerBaseURL: process.env.ISSUER_BASE_URL,
  clientSecret: process.env.CLIENT_SECRET
}));

app.listen(3000, () => {
  console.log('Server running on http://localhost:3000');
});
```

> **Calling external APIs?** If you need an access token for a downstream API, you **must** add `authorizationParams` — see Step 3a below.

This automatically creates:
- `/login` - Login endpoint
- `/logout` - Logout endpoint
- `/callback` - OAuth callback

### 3a. Configure Middleware for API Access (when calling external APIs)

When you need an access token for an external API, `audience` **must** go inside `authorizationParams` — putting it at the top level is silently ignored and no access token is issued.

```javascript
// SDK auto-loads SECRET, BASE_URL, CLIENT_ID, ISSUER_BASE_URL, CLIENT_SECRET from env vars
app.use(auth({
  authRequired: false,
  auth0Logout: true,
  authorizationParams: {            // ← required for access tokens
    response_type: 'code',          // ← required: authorization code flow
    audience: process.env.AUDIENCE, // ← API identifier (never top-level)
    scope: 'openid profile email'
  }
}));
```

Then access the token in your route:

```javascript
app.get('/api-call', requiresAuth(), async (req, res) => {
  const { access_token } = req.oidc.accessToken; // object, not a string
  const response = await fetch('https://your-api.com/data', {
    headers: { Authorization: `Bearer ${access_token}` }
  });
  res.json(await response.json());
});
```

### 4. Add Routes

```javascript
// Public route
app.get('/', (req, res) => {
  res.send(req.oidc.isAuthenticated() ? 'Logged in' : 'Logged out');
});

// Protected route
app.get('/profile', requiresAuth(), (req, res) => {
  res.send(`
    <h1>Profile</h1>
    <p>Name: ${req.oidc.user.name}</p>
    <p>Email: ${req.oidc.user.email}</p>
    <pre>${JSON.stringify(req.oidc.user, null, 2)}</pre>
    <a href="/logout">Logout</a>
  `);
});

// Login/logout links
app.get('/', (req, res) => {
  res.send(`
    ${req.oidc.isAuthenticated() ? `
      <p>Welcome, ${req.oidc.user.name}!</p>
      <a href="/profile">Profile</a>
      <a href="/logout">Logout</a>
    ` : `
      <a href="/login">Login</a>
    `}
  `);
});
```

### 5. Test Authentication

Start your server:

```bash
node app.js
```

Visit `http://localhost:3000` and test the login flow.

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup scripts, environment configuration, Auth0 CLI usage
- **[Integration Guide](references/integration.md)** - Protected routes, sessions, API integration, error handling
- **[API Reference](references/api.md)** - Complete middleware API, configuration options, request properties

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgot to add callback URL in Auth0 Dashboard | Add `/callback` path to Allowed Callback URLs (e.g., `http://localhost:3000/callback`) |
| Missing or weak SECRET | Generate secure secret with `openssl rand -hex 32` and store in .env as `SECRET` |
| Setting authRequired: true globally | Set to false and use `requiresAuth()` middleware on specific routes |
| App created as SPA type in Auth0 | Must be Regular Web Application type for server-side auth |
| Session secret exposed in code | Always use environment variables, never hardcode secrets |
| Wrong baseURL for production | Update BASE_URL to match your production domain |
| Not handling logout returnTo | Add your domain to Allowed Logout URLs in Auth0 Dashboard |
| `audience` as a top-level config key | Move `audience` inside `authorizationParams` with `response_type: 'code'` and `scope` — top-level `audience` is silently ignored, no access token is issued |
| `req.oidc.accessToken` used as a string | It is an object — destructure with `const { access_token } = req.oidc.accessToken` |

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Middleware Options:**
- `authRequired` - Require auth for all routes (default: false)
- `auth0Logout` - Enable /logout endpoint (default: false)
- `secret` - Session secret (required)
- `baseURL` - Application URL (required)
- `clientID` - Auth0 client ID (required)
- `issuerBaseURL` - Auth0 tenant URL (required)

**Request Properties:**
- `req.oidc.isAuthenticated()` - Check if user is logged in
- `req.oidc.user` - User profile object
- `req.oidc.accessToken` - Access token object (`{ access_token, token_type, expires_in }`); `expires_in` is seconds remaining. Destructure with `const { access_token } = req.oidc.accessToken`. Also exposes `isExpired()` and `refresh()` methods. Only populated when `authorizationParams` with `audience` + `response_type: 'code'` is configured
- `req.oidc.idToken` - ID token
- `req.oidc.refreshToken` - Refresh token

**Common Use Cases:**
- Protected routes → Use `requiresAuth()` middleware (see Step 4)
- Check auth status → `req.oidc.isAuthenticated()`
- Get user info → `req.oidc.user`
- Call APIs → [Integration Guide](references/integration.md#calling-apis)

---

## References

- [Express OpenID Connect Documentation](https://auth0.com/docs/libraries/express-openid-connect)
- [Auth0 Express Quickstart](https://auth0.com/docs/quickstart/webapp/express)
- [SDK GitHub Repository](https://github.com/auth0/express-openid-connect)
