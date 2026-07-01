---
name: express-oauth2-jwt-bearer
description: >
  Use when protecting Express or Node.js API endpoints with JWT Bearer token validation, scope-based access control, or DPoP binding. Integrates express-oauth2-jwt-bearer — use even if the user says "validate tokens in my Express API" or "protect my Node.js API endpoints".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Node OAuth2 JWT Bearer Integration

The `express-oauth2-jwt-bearer` package provides Express middleware for validating Auth0 JWT Bearer access tokens. It handles token extraction, signature verification, audience and issuer validation, and expiry checks per RFC 6750 — letting you focus on business logic rather than JWT parsing.

> **Agent instruction:** Before providing SDK setup instructions, fetch the latest release version by running:
> ```bash
> gh api repos/auth0/node-oauth2-jwt-bearer/releases/latest --jq '.tag_name'
> ```
> Use the returned version in all `package.json` dependency lines instead of any hardcoded version below.

## Prerequisites

- **Node.js** 18+ (20+ recommended; required for bootstrap script automation)
- **Express** 4.x or 5.x
- **npm** or **yarn**
- An **Auth0 account** with a configured API (Resource Server)
- **Auth0 CLI** (for automatic setup): `npm install -g @auth0/auth0-cli`

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| Building a server-side web app with login UI (Express sessions) | `auth0-express` |
| Building a Next.js app with server-side auth | `auth0-nextjs` |
| Building a React/Angular/Vue SPA | `auth0-react`, `auth0-angular`, `auth0-vue` |
| Building a React Native or mobile app | `auth0-react-native`, `auth0-android`, `auth0-swift` |
| ASP.NET Core Web API | `auth0-aspnetcore-api` |
| Go API with JWT middleware | `go-jwt-middleware` |
| Python API (Flask/FastAPI) | `auth0-api-python` |
| Node.js API using the older `express-jwt` package | `express-jwt` |

## Quick Start Workflow

> **Agent instruction:** Follow these steps to integrate `express-oauth2-jwt-bearer` into the user's Node.js API project.
>
> 1. **Fetch latest version** (see instruction above).
>
> 2. **Install the SDK:**
>    ```bash
>    npm install express-oauth2-jwt-bearer
>    ```
>
> 3. **Configure Auth0** — follow `references/setup.md`. If the user already provided their Auth0 Domain and API Audience in the prompt, write them to a `.env` file as `ISSUER_BASE_URL` (the full issuer URL, including `https://`) and `AUDIENCE` — the SDK reads these automatically. Skip the bootstrap script and do NOT call `AskUserQuestion` to re-confirm. **Never hardcode the domain or audience as literal strings (or `||` fallback defaults) in `server.js` / `app.js`** — they belong in `.env` only. Otherwise, offer automatic setup via bootstrap script or manual setup.
>
> 4. **Set up middleware** — first create a `.env` file with the Auth0 values, then load it and add the middleware. `express-oauth2-jwt-bearer` reads `ISSUER_BASE_URL` and `AUDIENCE` from the environment automatically, so `auth()` needs no arguments:
>    ```bash
>    # .env
>    ISSUER_BASE_URL=https://your-tenant.us.auth0.com
>    AUDIENCE=https://your-api-identifier
>    ```
>    ```javascript
>    import 'dotenv/config'; // load .env before the SDK reads process.env
>    import { auth } from 'express-oauth2-jwt-bearer';
>
>    // Reads ISSUER_BASE_URL and AUDIENCE from the environment — no config needed
>    const checkJwt = auth();
>
>    app.use(checkJwt); // apply globally, or per-route
>    ```
>    Keep the issuer and audience in `.env` — do not inline literal values or pass them as arguments here.
>
> 5. **Protect endpoints** — apply middleware globally or to specific routes:
>    ```javascript
>    // Global protection
>    app.use(checkJwt);
>
>    // Or per-route
>    app.get('/api/private', checkJwt, (req, res) => {
>      res.json({ sub: req.auth.payload.sub });
>    });
>    ```
>
> 6. **Add RBAC** (optional) — use `requiredScopes()` or `claimIncludes()` for permission-based access:
>    ```javascript
>    import { auth, requiredScopes, claimIncludes } from 'express-oauth2-jwt-bearer';
>
>    app.get('/api/messages', checkJwt, requiredScopes('read:messages'), (req, res) => {
>      res.json({ messages: [] });
>    });
>    ```
>    > **Important:** `requiredScopes` accepts a single argument — a space-separated string or an array. Do NOT pass multiple string arguments: `requiredScopes('read:msg', 'write:msg')` silently ignores everything after the first. Use `requiredScopes('read:msg write:msg')` or `requiredScopes(['read:msg', 'write:msg'])` instead.
>
> 7. **Verify the integration** — build and test:
>    ```bash
>    node server.js
>    curl http://localhost:3000/api/private         # should return 401
>    curl -H "Authorization: Bearer <token>" http://localhost:3000/api/private  # should return 200
>    ```
>
> 8. **Failcheck:** If the server fails to start or tokens are rejected unexpectedly, check `references/api.md` for common issues. After 5-6 failed iterations, use `AskUserQuestion` to ask the user for more details about their environment.

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 API registration, .env configuration, bootstrap script for automated setup, and secret management
- **[Integration Patterns](./references/integration.md)** — Protected endpoints, RBAC with scopes and claims, DPoP, CORS setup, error handling, and testing with curl
- **[API Reference & Testing](./references/api.md)** — Full configuration options, claims reference, complete code example, testing checklist, and common issues

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Created an **Application** instead of an **API** in Auth0 Dashboard | Token validation fails; wrong audience | Create a new **API** (Resource Server) in Auth0 Dashboard → APIs |
| Audience doesn't match API identifier exactly | `401 Unauthorized` — "Audience mismatch" | Copy the exact API Identifier string from Auth0 Dashboard → APIs |
| `ISSUER_BASE_URL` missing the `https://` scheme | `Error: Invalid URL` at startup | `ISSUER_BASE_URL` must be the full issuer URL: `https://your-tenant.us.auth0.com` |
| Checking `scope` claim instead of `permissions` for RBAC | 403 always returned or permissions ignored | Use `requiredScopes()` for scope-based RBAC; use `claimIncludes('permissions', 'read:data')` for Auth0 RBAC permission claims |
| CORS not configured before auth middleware | Preflight OPTIONS requests return 401 | Add `cors()` middleware before `auth()` in the middleware chain |
| `.env` file not loaded | `undefined` for domain/audience | Add `import 'dotenv/config'` at the top of the entry file |
| Hardcoded domain/audience in source (incl. `process.env.X \|\| 'literal'` fallbacks) | Secrets committed to source; fails security review | Put values in `.env` (`ISSUER_BASE_URL` / `AUDIENCE`) and let `auth()` read them automatically — no literal fallbacks |
| `req.auth` is undefined | `TypeError: Cannot read properties of undefined` | Verify `checkJwt` middleware runs before the handler |

## Related Skills

- **[auth0-express](../auth0-express)** — For Express web apps with login UI (sessions, cookies)
- **[auth0-nextjs](../auth0-nextjs)** — For Next.js server-side web apps
- **[auth0-aspnetcore-api](../auth0-aspnetcore-api)** — BACKEND_API reference implementation for .NET
- **[go-jwt-middleware](../go-jwt-middleware)** — JWT middleware for Go APIs
- **[auth0-api-python](../auth0-api-python)** — JWT validation for Python APIs (Flask/FastAPI)
- **[auth0-cli](../auth0-cli)** — Manage Auth0 resources from the terminal

## Quick Reference

### Core Middleware

| Function | Description | Returns |
|----------|-------------|---------|
| `auth(options?)` | JWT Bearer validation middleware | `Handler` — 401 if token invalid/missing |
| `requiredScopes(scopes)` | Validates token has all required scopes | `Handler` — 403 if scopes missing |
| `scopeIncludesAny(scopes)` | Validates token has at least one scope | `Handler` — 403 if no match |
| `claimEquals(claim, value)` | Validates a claim equals a value | `Handler` — 401 if mismatch |
| `claimIncludes(claim, ...values)` | Validates claim includes all values | `Handler` — 401 if incomplete |
| `claimCheck(fn, desc?)` | Custom claim validation function | `Handler` — 401 if fn returns false |

### Configuration Options

| Option | Type | Description |
|--------|------|-------------|
| `issuerBaseURL` | `string` | Full issuer URL with `https://`. Optional — defaults to the `ISSUER_BASE_URL` env var |
| `audience` | `string` | API Identifier from Auth0 Dashboard. Optional — defaults to the `AUDIENCE` env var |
| `tokenSigningAlg` | `string` | Signing algorithm (default: `RS256`; use `HS256` for symmetric) |
| `authRequired` | `boolean` | Set `false` to make authentication optional (default: `true`) |
| `clockTolerance` | `number` | Clock skew tolerance in seconds (no default; undefined unless set) |
| `dpop` | `DPoPOptions` | DPoP configuration (see integration.md) |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `ISSUER_BASE_URL` | Full issuer URL with `https://`, e.g. `https://your-tenant.us.auth0.com` (auto-detected by SDK) |
| `AUDIENCE` | API Identifier, e.g. `https://your-api-identifier` (auto-detected by SDK) |

### Request Object

After successful validation, `req.auth` contains:
```typescript
req.auth.payload    // Decoded JWT payload (sub, iss, aud, exp, permissions, etc.)
req.auth.header     // JWT header (alg, typ, kid)
req.auth.token      // Raw JWT string
```

## SDK Architecture

The `node-oauth2-jwt-bearer` monorepo contains three packages:

| Package | Purpose |
|---------|---------|
| `express-oauth2-jwt-bearer` | **Main package.** Express middleware for JWT Bearer validation. Published to npm. |
| `access-token-jwt` | Low-level JWT verification utilities (used internally). |
| `oauth2-bearer` | RFC 6750 Bearer token extraction (used internally). |

In practice, you only install and import `express-oauth2-jwt-bearer`.

## Auth Flow Comparison

| Auth Pattern | SDK | When to Use |
|-------------|-----|-------------|
| JWT Bearer (stateless) | `express-oauth2-jwt-bearer` | APIs called by SPAs, mobile apps, M2M clients |
| Session-based (stateful) | `@auth0/express-openid-connect` | Web apps with login UI and server-side sessions |

## Testing Quick Reference

```bash
# Get test token from Auth0 Dashboard → APIs → your API → Test tab
# Copy the token, then:

# 1. Verify 401 on protected route (no token)
curl -v http://localhost:3000/api/private

# 2. Verify 200 with valid token
curl -H "Authorization: Bearer <paste-token-here>" http://localhost:3000/api/private

# 3. Verify 403 with valid token but missing scope
curl -H "Authorization: Bearer <paste-token-here>" http://localhost:3000/api/admin

# 4. Verify CORS preflight
curl -v -X OPTIONS http://localhost:3000/api/private \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization"
```

## References

- [express-oauth2-jwt-bearer on npm](https://www.npmjs.com/package/express-oauth2-jwt-bearer)
- [GitHub: auth0/node-oauth2-jwt-bearer](https://github.com/auth0/node-oauth2-jwt-bearer)
- [Auth0 Node.js API Quickstart](https://auth0.com/docs/quickstart/backend/nodejs/interactive)
- [Auth0 APIs Dashboard](https://manage.auth0.com/#/apis)
- [RFC 6750 — Bearer Token Usage](https://datatracker.ietf.org/doc/html/rfc6750)
