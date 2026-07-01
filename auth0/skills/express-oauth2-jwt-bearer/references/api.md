# express-oauth2-jwt-bearer API Reference & Testing

## Configuration Reference

All options are passed to the `auth()` function or set via environment variables.

### auth() Options

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `issuerBaseURL` | `string` | No — defaults to `ISSUER_BASE_URL` env var | — | Full issuer URL with `https://`, e.g. `https://your-tenant.us.auth0.com` |
| `audience` | `string` | No — defaults to `AUDIENCE` env var | — | API Identifier from Auth0 Dashboard, e.g. `https://my-api.com` |
| `secret` | `string` | For HS256 only | — | Shared secret for symmetric JWT signing (HS256). Not required for RS256. |
| `tokenSigningAlg` | `string` | No | `RS256` | JWT signing algorithm. Use `HS256` for symmetric keys. |
| `issuer` | `string` | No (alternative to `issuerBaseURL`) | — | Issuer claim value — use with `jwksUri` for non-standard setups |
| `jwksUri` | `string` | No | Derived from `issuerBaseURL` | Custom JWKS endpoint URL |
| `authRequired` | `boolean` | No | `true` | Set `false` to allow unauthenticated requests through (attach auth info if present) |
| `clockTolerance` | `number` | No | `(none)` | Clock skew tolerance in seconds (undefined unless explicitly set) |
| `validators` | `Validators` | No | — | Custom validator overrides. Set `{ iss: false }` to skip issuer validation. |
| `dpop` | `DPoPOptions` | No | — | DPoP configuration (see below) |

### DPoPOptions

| Option | Type | Description |
|--------|------|-------------|
| `enabled` | `boolean` | Enable DPoP token binding. Default is `true` (hybrid Bearer+DPoP mode). |
| `required` | `boolean` | Set `true` to reject plain Bearer tokens (DPoP-only mode). Default: `false`. |
| `iatOffset` | `number` | Max age of a DPoP proof in seconds. |
| `iatLeeway` | `number` | Leeway for `iat` claim in DPoP proofs. |

### Environment Variables (auto-detected)

`express-oauth2-jwt-bearer` reads these variables from the environment automatically, so `auth()` can be called with no arguments. This is the approach this skill uses — put the values in `.env` and let the SDK pick them up:

| Variable | Description |
|----------|-------------|
| `ISSUER_BASE_URL` | Full issuer URL **with** `https://` prefix: `https://your-tenant.us.auth0.com` |
| `AUDIENCE` | API Identifier: `https://your-api.example.com` |

```javascript
import 'dotenv/config'; // load .env before the SDK reads process.env

// No arguments needed — ISSUER_BASE_URL and AUDIENCE are read from the environment
const checkJwt = auth();
```

Pass `issuerBaseURL` / `audience` explicitly only if you need to source them from differently-named variables or compute them at runtime.

## Claims Reference

| Claim | Type | Description |
|-------|------|-------------|
| `sub` | `string` | Subject identifier — the user's or M2M app's unique Auth0 ID |
| `iss` | `string` | Issuer — your Auth0 tenant URL (e.g. `https://your-tenant.us.auth0.com/`) |
| `aud` | `string \| string[]` | Audience — must match your API Identifier |
| `exp` | `number` | Expiration timestamp (Unix epoch) |
| `iat` | `number` | Issued-at timestamp (Unix epoch) |
| `scope` | `string` | Space-separated scopes granted to the token |
| `permissions` | `string[]` | Array of RBAC permissions (Auth0-specific, enabled via RBAC settings on the API) |
| `azp` | `string` | Authorized party — client ID of the application that requested the token |
| `org_id` | `string` | Organization ID (Auth0 Organizations feature) |

**Accessing claims in a handler:**
```javascript
app.get('/api/me', checkJwt, (req, res) => {
  const { sub, permissions, scope } = req.auth.payload;
  res.json({ sub, permissions });
});
```

## Code Examples

### Complete minimal example

```javascript
// server.js
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { auth, requiredScopes, claimIncludes } from 'express-oauth2-jwt-bearer';

const app = express();

// 1. CORS before auth (required for preflight requests)
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
  allowedHeaders: ['Authorization', 'Content-Type', 'DPoP'],
}));

app.use(express.json());

// 2. JWT validation middleware (reads ISSUER_BASE_URL and AUDIENCE from the environment)
const checkJwt = auth();

// 3. Public endpoint (no auth required)
app.get('/api/public', (req, res) => {
  res.json({ message: 'This is a public endpoint' });
});

// 4. Private endpoint (JWT required)
app.get('/api/private', checkJwt, (req, res) => {
  res.json({
    message: 'Authenticated',
    sub: req.auth.payload.sub,
  });
});

// 5. Scoped endpoint (specific scope required)
app.get('/api/messages', checkJwt, requiredScopes('read:messages'), (req, res) => {
  res.json({ messages: ['Hello', 'World'] });
});

// 6. Permission-based endpoint (RBAC permissions claim)
app.get('/api/admin', checkJwt, claimIncludes('permissions', 'admin:access'), (req, res) => {
  res.json({ message: 'Admin access granted' });
});

// 7. RFC 6750 error handler
app.use((err, req, res, next) => {
  if (err.status) {
    return res.status(err.status).json({
      error: err.code,
      message: err.message,
    });
  }
  next(err);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`API listening on port ${PORT}`));
```

### Environment configuration (.env)

```env
ISSUER_BASE_URL=https://your-tenant.us.auth0.com
AUDIENCE=https://your-api.example.com
PORT=3000
CORS_ORIGIN=http://localhost:5173
```

### TypeScript example

```typescript
import 'dotenv/config';
import express, { Request, Response, NextFunction } from 'express';
import { auth, requiredScopes } from 'express-oauth2-jwt-bearer';

// Note: express-oauth2-jwt-bearer already declares req.auth on the Express
// Request interface in its own .d.ts — no need to redeclare it here.

const app = express();

// Reads ISSUER_BASE_URL and AUDIENCE from the environment
const checkJwt = auth();

app.get('/api/private', checkJwt, (req: Request, res: Response) => {
  const sub = req.auth?.payload.sub;
  res.json({ sub });
});
```

## Testing Checklist

- [ ] **Public endpoint** returns `200` without a token: `curl http://localhost:3000/api/public`
- [ ] **Protected endpoint** returns `401` without a token: `curl http://localhost:3000/api/private`
- [ ] **Protected endpoint** returns `200` with valid M2M token: `curl -H "Authorization: Bearer <token>" http://localhost:3000/api/private`
- [ ] **Scoped endpoint** returns `403` with token missing required scope
- [ ] **Scoped endpoint** returns `200` with token that has the required scope
- [ ] **Expired token** returns `401` with error description
- [ ] **Wrong audience** returns `401`
- [ ] **CORS preflight** (`OPTIONS`) returns `200` from protected routes
- [ ] `req.auth.payload.sub` contains the expected subject
- [ ] `req.auth.payload.permissions` array is populated (if RBAC is enabled on the Auth0 API)

### Getting a test token with M2M credentials

```bash
curl --request POST \
  --url "https://YOUR_AUTH0_DOMAIN/oauth/token" \
  --header "content-type: application/json" \
  --data '{
    "client_id": "YOUR_M2M_CLIENT_ID",
    "client_secret": "YOUR_M2M_CLIENT_SECRET",
    "audience": "YOUR_API_AUDIENCE",
    "grant_type": "client_credentials"
  }'
```

## Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `UnauthorizedError: No authorization token was found` | No `Authorization: Bearer ...` header | Add the bearer token to the request header |
| `UnauthorizedError: invalid_token — jwt audience invalid` | Audience mismatch | Verify `AUDIENCE` matches the API Identifier in Auth0 Dashboard exactly |
| `UnauthorizedError: invalid_token — jwt issuer invalid` | Issuer mismatch | Verify `ISSUER_BASE_URL` is the full Auth0 tenant URL **including** `https://` |
| `UnauthorizedError: invalid_token — jwt expired` | Token has expired | Request a new token; check system clock drift (`clockTolerance` option) |
| `Error: JWKS request failed` | Network or issuer misconfiguration | Verify `ISSUER_BASE_URL` is reachable; check network/proxy settings |
| `InsufficientScopeError: Insufficient scope` | Token lacks required scope | Verify the requesting app has the scope granted; check `requiredScopes()` call |
| `CORS error` on OPTIONS preflight | Auth middleware running before CORS | Move `cors()` middleware before `auth()` in the middleware chain |
| `TypeError: Cannot read properties of undefined (reading 'payload')` | `req.auth` is undefined | Check that `checkJwt` middleware runs before the handler |

## Security Considerations

- **Never log tokens.** Full JWT strings contain sensitive claims. Log only `sub` or `jti` for tracing.
- **CORS before auth.** Always register `cors()` before `auth()`. Auth middleware rejects OPTIONS preflight requests with 401 if CORS isn't set first.
- **Audience validation is critical.** Without a matching `audience`, your API would accept tokens issued for other services.
- **Issuer validation.** The `issuerBaseURL` is used to fetch the JWKS and validate the `iss` claim. Never disable issuer validation in production.
- **RBAC via `permissions` claim.** Auth0 RBAC stores user permissions in the `permissions` JWT claim (not `scope`). Enable "Add Permissions in the Access Token" on your Auth0 API settings.
- **DPoP.** For APIs requiring sender-constrained tokens, enable DPoP with `dpop: { enabled: true, required: true }`. This prevents token theft — stolen tokens cannot be replayed without the original private key.
- **Helmet.** Pair with `helmet` for security headers: `npm install helmet` + `app.use(helmet())`.
- **Production secrets.** Never commit `.env` to source control. Use environment variables in production (Railway, Heroku, Fly.io, etc.).
