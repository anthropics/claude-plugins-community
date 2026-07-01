# Integration Patterns

## Authentication Flow

```text
Client → API
  1. Client obtains access token from Auth0 (via /oauth/token)
  2. Client sends request with "Authorization: Bearer <token>" header
  3. express-oauth2-jwt-bearer middleware:
     a. Extracts bearer token from Authorization header
     b. Fetches public key from Auth0 JWKS endpoint (cached)
     c. Verifies token signature, issuer, audience, expiry
     d. Attaches decoded token to req.auth
  4. Route handler accesses req.auth.payload
```

## Protected Endpoints

### Global protection

Apply `checkJwt` middleware globally to protect all routes:

```javascript
import { auth } from 'express-oauth2-jwt-bearer';

// Reads ISSUER_BASE_URL and AUDIENCE from the environment automatically
const checkJwt = auth();

// All routes below this require a valid JWT
app.use(checkJwt);
app.get('/api/users', (req, res) => {
  res.json({ sub: req.auth.payload.sub });
});
```

### Per-route protection

Apply middleware to specific routes only:

```javascript
// Public — no auth
app.get('/api/public', (req, res) => {
  res.json({ message: 'Public endpoint' });
});

// Protected — JWT required
app.get('/api/private', checkJwt, (req, res) => {
  res.json({ sub: req.auth.payload.sub });
});
```

### Optional authentication

Allow unauthenticated requests but attach auth info when present:

```javascript
// issuer and audience come from ISSUER_BASE_URL / AUDIENCE in the environment
const optionalAuth = auth({
  authRequired: false,
});

app.get('/api/profile', optionalAuth, (req, res) => {
  if (req.auth) {
    res.json({ sub: req.auth.payload.sub, authenticated: true });
  } else {
    res.json({ authenticated: false });
  }
});
```

## RBAC — Scope-Based Authorization

Use `requiredScopes()` to enforce scopes on access tokens:

```javascript
import { auth, requiredScopes } from 'express-oauth2-jwt-bearer';

// All scopes must be present
app.get('/api/messages', checkJwt, requiredScopes('read:messages'), (req, res) => {
  res.json({ messages: [] });
});

// Multiple scopes required
app.post('/api/messages', checkJwt, requiredScopes('read:messages write:messages'), (req, res) => {
  res.json({ created: true });
});
```

### Permission-based RBAC (Auth0 RBAC feature)

When Auth0 RBAC is enabled on the API, permissions are stored in the `permissions` claim:

```javascript
import { auth, claimIncludes } from 'express-oauth2-jwt-bearer';

// Require 'read:messages' in the permissions claim
app.get('/api/messages', checkJwt, claimIncludes('permissions', 'read:messages'), (req, res) => {
  res.json({ messages: [] });
});

// Require multiple permissions
app.delete('/api/messages/:id', checkJwt, claimIncludes('permissions', 'delete:messages'), (req, res) => {
  res.json({ deleted: true });
});
```

## Claim Validation

### claimEquals — exact value match

```javascript
import { auth, claimEquals } from 'express-oauth2-jwt-bearer';

// Require org_id to equal a specific value
app.get('/api/org-data', checkJwt, claimEquals('org_id', 'org_123'), (req, res) => {
  res.json({ org: 'org_123' });
});
```

### claimIncludes — array contains all values

```javascript
import { auth, claimIncludes } from 'express-oauth2-jwt-bearer';

// Require the roles claim to include 'admin'
app.get('/api/admin', checkJwt, claimIncludes('roles', 'admin'), (req, res) => {
  res.json({ admin: true });
});
```

### claimCheck — custom validation logic

```javascript
import { auth, claimCheck } from 'express-oauth2-jwt-bearer';

// Custom validation function
app.get('/api/premium', checkJwt, claimCheck((payload) => {
  return payload?.subscription === 'premium' && payload?.active === true;
}, 'Premium subscription required'), (req, res) => {
  res.json({ premium: true });
});
```

## CORS Configuration

**Critical:** CORS middleware must come before auth middleware. Auth rejects OPTIONS preflight requests with 401 if CORS isn't configured first.

```javascript
import cors from 'cors';
import { auth } from 'express-oauth2-jwt-bearer';

// 1. CORS first (handles OPTIONS preflight)
app.use(cors({
  origin: 'http://localhost:5173',  // Your frontend URL
  allowedHeaders: ['Authorization', 'Content-Type', 'DPoP'],
  exposedHeaders: ['WWW-Authenticate'],
}));

// 2. Auth second (reads ISSUER_BASE_URL and AUDIENCE from the environment)
const checkJwt = auth();
```

## DPoP Support

DPoP (Demonstration of Proof-of-Possession) binds tokens to the client's key pair, preventing token theft. The SDK supports DPoP natively.

### Hybrid mode (Bearer or DPoP both accepted — default)

```javascript
// issuer and audience come from ISSUER_BASE_URL / AUDIENCE in the environment
const checkJwt = auth({
  dpop: {
    enabled: true,
    required: false,  // Accept both Bearer and DPoP tokens
  },
});
```

### DPoP-only mode (rejects plain Bearer tokens)

```javascript
// issuer and audience come from ISSUER_BASE_URL / AUDIENCE in the environment
const checkJwt = auth({
  dpop: {
    enabled: true,
    required: true,  // Reject plain Bearer tokens
  },
});
```

### Bearer-only mode (disable DPoP)

```javascript
// issuer and audience come from ISSUER_BASE_URL / AUDIENCE in the environment
const checkJwt = auth({
  dpop: { enabled: false },
});
```


## Error Handling

The SDK throws RFC 6750-compliant errors with `.status` and `.headers` properties. Add an error handler after your routes:

```javascript
app.use((err, req, res, next) => {
  if (err.status) {
    // JWT validation error — send WWW-Authenticate header per RFC 6750
    res.set(err.headers);
    return res.status(err.status).json({
      error: err.code,
      error_description: process.env.NODE_ENV === 'production' ? undefined : err.message,
    });
  }
  // Other errors
  console.error(err);
  res.status(500).json({ error: 'internal_error' });
});
```

### Error types

| Error Class | Status | Code | Cause |
|------------|--------|------|-------|
| `UnauthorizedError` | 401 | `invalid_token` | Missing, expired, or malformed token |
| `InvalidRequestError` | 400 | `invalid_request` | Malformed Authorization header |
| `InvalidTokenError` | 401 | `invalid_token` | Token signature/claims validation failed |
| `InsufficientScopeError` | 403 | `insufficient_scope` | Token lacks required scope |

```javascript
import {
  UnauthorizedError,
  InvalidTokenError,
  InsufficientScopeError
} from 'express-oauth2-jwt-bearer';

app.use((err, req, res, next) => {
  if (err instanceof InsufficientScopeError) {
    return res.status(403).json({ error: 'forbidden' });
  }
  if (err instanceof UnauthorizedError || err instanceof InvalidTokenError) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  next(err);
});
```

## Testing Patterns

### Manual testing with curl

```bash
# 1. Get a test token (from Auth0 Dashboard → APIs → Test, or via M2M credentials)
ACCESS_TOKEN=$(curl -s --request POST \
  --url "https://YOUR_AUTH0_DOMAIN/oauth/token" \
  --header "content-type: application/json" \
  --data '{
    "client_id": "YOUR_M2M_CLIENT_ID",
    "client_secret": "YOUR_M2M_CLIENT_SECRET",
    "audience": "YOUR_API_AUDIENCE",
    "grant_type": "client_credentials"
  }' | jq -r '.access_token')

# 2. Test protected endpoint
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:3000/api/private

# 3. Test scoped endpoint
curl -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:3000/api/messages
```

### Unit testing with Jest/Vitest

```javascript
import request from 'supertest';
import app from './app.js';

describe('API Authentication', () => {
  it('returns 401 without token', async () => {
    const res = await request(app).get('/api/private');
    expect(res.status).toBe(401);
  });

  it('returns 200 with valid token', async () => {
    // Use a test token from Auth0 or a mocked JWT
    const res = await request(app)
      .get('/api/private')
      .set('Authorization', `Bearer ${process.env.TEST_TOKEN}`);
    expect(res.status).toBe(200);
  });
});
```

### Mocking in unit tests

For unit tests, you can mock the `auth` middleware to bypass JWT validation:

```javascript
// test-utils.js
import { jest } from '@jest/globals';

export function mockAuth(payload = { sub: 'test-user' }) {
  jest.mock('express-oauth2-jwt-bearer', () => ({
    auth: () => (req, res, next) => {
      req.auth = { payload };
      next();
    },
    requiredScopes: (scopes) => (req, res, next) => {
      const tokenScopes = req.auth?.payload?.scope?.split(' ') || [];
      const missing = [scopes].flat().filter(s => !tokenScopes.includes(s));
      if (missing.length) return res.status(403).json({ error: 'insufficient_scope' });
      next();
    },
    claimIncludes: () => (req, res, next) => next(),
  }));
}
```
