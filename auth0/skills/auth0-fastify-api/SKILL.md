---
name: auth0-fastify-api
description: >
  Use when protecting Fastify API endpoints with JWT Bearer token validation or scope checks. Integrates @auth0/auth0-fastify-api for stateless APIs receiving access tokens from frontends or mobile apps.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
    requires:
      bins:
        - auth0
---

# Auth0 Fastify API Integration

Protect Fastify API endpoints with JWT access token validation using @auth0/auth0-fastify-api.

---

## Prerequisites

- Fastify API application (v5.x or newer)
- Node.js 20 LTS or newer
- Auth0 API configured (not Application - must be API resource)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Server-rendered web applications** - Use `@auth0/auth0-fastify` for session-based auth
- **Single Page Applications** - Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Next.js applications** - Use `auth0-nextjs` skill
- **Mobile applications** - Use `auth0-react-native` for React Native/Expo

---

## Quick Start Workflow

### 1. Install SDK

```bash
npm install @auth0/auth0-fastify-api fastify dotenv
```

### 2. Create Auth0 API

You need an **API** (not Application) in Auth0:

```bash
# Using Auth0 CLI
auth0 apis create \
  --name "My Fastify API" \
  --identifier https://my-api.example.com
```

Or create manually in Auth0 Dashboard → Applications → APIs

### 3. Configure Environment

Create `.env`:

```bash
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_AUDIENCE=https://my-api.example.com
```

### 4. Configure Auth Plugin

Create your Fastify server (`server.js`):

```javascript
import 'dotenv/config';
import Fastify from 'fastify';
import fastifyAuth0Api from '@auth0/auth0-fastify-api';

const fastify = Fastify({ logger: true });

// Register Auth0 API plugin
await fastify.register(fastifyAuth0Api, {
  domain: process.env.AUTH0_DOMAIN,
  audience: process.env.AUTH0_AUDIENCE,
});

fastify.listen({ port: 3001 });
```

### 5. Protect Routes

```javascript
// Public route - no authentication
fastify.get('/api/public', async (request, reply) => {
  return {
    message: 'Hello from a public endpoint!',
    timestamp: new Date().toISOString(),
  };
});

// Protected route - requires valid JWT
fastify.get('/api/private', {
  preHandler: fastify.requireAuth()
}, async (request, reply) => {
  return {
    message: 'Hello from a protected endpoint!',
    user: request.user.sub,
    timestamp: new Date().toISOString(),
  };
});

// Protected route with user info
fastify.get('/api/profile', {
  preHandler: fastify.requireAuth()
}, async (request, reply) => {
  return {
    profile: request.user,  // JWT claims
  };
});
```

### 6. Test API

Test public endpoint:

```bash
curl http://localhost:3001/api/public
```

Test protected endpoint (requires access token):

```bash
# First, obtain an access token (e.g. via Auth0 Dashboard > APIs > Test tab)
curl http://localhost:3001/api/private \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Created Application instead of API in Auth0 | Must create API resource in Auth0 Dashboard → Applications → APIs |
| Missing Authorization header | Include `Authorization: Bearer <token>` in all protected endpoint requests |
| Wrong audience in token | Client must request token with matching `audience` parameter |
| Using ID token instead of access token | Must use **access token** for API auth, not ID token |
| Not handling 401/403 errors | Implement proper error handling for unauthorized/forbidden responses |

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-fastify` - For server-rendered Fastify web apps with sessions
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Plugin Options:**
- `domain` - Auth0 tenant domain (required)
- `audience` - API identifier from Auth0 API settings (required)

**Request Properties:**
- `request.user` - Decoded JWT claims object
- `request.user.sub` - User ID (subject)

**Middleware:**
- `fastify.requireAuth()` - Protect route with JWT validation
- `fastify.requireAuth({ scopes: 'read:data' })` - Require specific scope
- `fastify.requireAuth({ scopes: ['read:data', 'write:data'] })` - Require specific scopes

**Common Use Cases:**
- Protect routes → Use `preHandler: fastify.requireAuth()` (see Step 5)
- Get user ID → `request.user.sub`
- Custom claims → Access via `request.user['namespace/claim']`

---

## References

- [Auth0 Fastify API Documentation](https://auth0.com/docs/quickstart/backend/fastify)
- [SDK GitHub Repository](https://github.com/auth0/auth0-fastify)
- [Access Tokens Guide](https://auth0.com/docs/secure/tokens/access-tokens)
