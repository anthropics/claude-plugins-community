---
name: auth0-fastify
description: >
  Use when adding session-based login, logout, or protected routes to a Fastify web application. Integrates @auth0/auth0-fastify — use even if the user says "add login to my Fastify app". For Fastify APIs validating Bearer tokens, use auth0-fastify-api instead.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Fastify Integration

Add authentication to Fastify web applications using @auth0/auth0-fastify.

---

## Prerequisites

- Fastify application (v5.x or newer)
- Node.js 20 LTS or newer
- Auth0 account and application configured
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Single Page Applications** - Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Next.js applications** - Use `auth0-nextjs` skill which handles both client and server
- **Mobile applications** - Use `auth0-react-native` for React Native/Expo
- **Stateless APIs** - Use `@auth0/auth0-fastify-api` instead for JWT validation without sessions
- **Microservices** - Use JWT validation for service-to-service auth

---

## Quick Start Workflow

### 1. Install SDK

```bash
npm install @auth0/auth0-fastify fastify @fastify/view ejs dotenv
```

### 2. Configure Environment

Create `.env`:

```bash
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
SESSION_SECRET=<openssl-rand-hex-64>
APP_BASE_URL=http://localhost:3000
```

Generate secret: `openssl rand -hex 64`

### 3. Configure Auth Plugin

Create your Fastify server (`server.js`):

```javascript
import 'dotenv/config';
import Fastify from 'fastify';
import fastifyAuth0 from '@auth0/auth0-fastify';
import fastifyView from '@fastify/view';
import ejs from 'ejs';

const fastify = Fastify({ logger: true });

// Register view engine
await fastify.register(fastifyView, {
  engine: { ejs },
  root: './views',
});

// Configure Auth0 plugin
await fastify.register(fastifyAuth0, {
  domain: process.env.AUTH0_DOMAIN,
  clientId: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  appBaseUrl: process.env.APP_BASE_URL,
  sessionSecret: process.env.SESSION_SECRET,
});

fastify.listen({ port: 3000 });
```

This automatically creates:
- `/auth/login` - Login endpoint
- `/auth/logout` - Logout endpoint
- `/auth/callback` - OAuth callback

### 4. Add Routes

```javascript
// Public route
fastify.get('/', async (request, reply) => {
  const session = await fastify.auth0Client.getSession({ request, reply });
  return reply.view('views/home.ejs', {
    isAuthenticated: !!session,
  });
});

// Protected route
fastify.get('/profile', {
  preHandler: async (request, reply) => {
    const session = await fastify.auth0Client.getSession({ request, reply });
    if (!session) {
      return reply.redirect('/auth/login');
    }
  }
}, async (request, reply) => {
  const user = await fastify.auth0Client.getUser({ request, reply });
  return reply.view('views/profile.ejs', { user });
});
```

### 5. Test Authentication

Start your server:

```bash
node server.js
```

Visit `http://localhost:3000` and test the login flow.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgot to add callback URL in Auth0 Dashboard | Add `/auth/callback` path to Allowed Callback URLs (e.g., `http://localhost:3000/auth/callback`) |
| Missing or weak SESSION_SECRET | Generate secure 64-char secret with `openssl rand -hex 64` and store in .env |
| App created as SPA type in Auth0 | Must be Regular Web Application type for server-side auth |
| Session secret exposed in code | Always use environment variables, never hardcode secrets |
| Wrong appBaseUrl for production | Update APP_BASE_URL to match your production domain |
| Not awaiting fastify.register | Fastify v4+ requires awaiting plugin registration |

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Plugin Options:**
- `domain` - Auth0 tenant domain (required)
- `clientId` - Auth0 client ID (required)
- `clientSecret` - Auth0 client secret (required)
- `appBaseUrl` - Application URL (required)
- `sessionSecret` - Session encryption secret (required, min 64 chars)
- `audience` - API audience (optional, for calling APIs)

**Client Methods:**
- `fastify.auth0Client.getSession({ request, reply })` - Get user session
- `fastify.auth0Client.getUser({ request, reply })` - Get user profile
- `fastify.auth0Client.getAccessToken({ request, reply })` - Get access token
- `fastify.auth0Client.logout(options, { request, reply })` - Logout user

**Common Use Cases:**
- Protected routes → Use `preHandler` to check session (see Step 4)
- Check auth status → `!!session`
- Get user info → `getUser({ request, reply })`
- Call APIs → `getAccessToken({ request, reply })`

---

## References

- [Auth0 Fastify Documentation](https://auth0.com/docs/quickstart/webapp/fastify)
- [SDK GitHub Repository](https://github.com/auth0/auth0-fastify)
