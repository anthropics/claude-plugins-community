---
name: auth0-nuxt
description: >
  Use when adding Auth0 login, logout, session management, or protected routes to a Nuxt 3 or Nuxt 4 application. Integrates @auth0/auth0-nuxt — use even if the user says "add login to my Nuxt app".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Nuxt SDK

## Overview

Server-side session authentication for Nuxt 3/4. NOT the same as @auth0/auth0-vue (client-side SPA).

**Core principle:** Uses server-side encrypted cookie sessions, not client-side tokens.

## When to Use

**Use this when:**
- Building Nuxt 3/4 applications with server-side rendering (Node.js 20 LTS+)
- Need secure session management with encrypted cookies
- Protecting server routes and API endpoints
- Accessing Auth0 Management API or custom APIs

**Don't use this when:**
- Using Nuxt 2 (not supported - use different Auth0 SDK)
- Building pure client-side SPA without server (use @auth0/auth0-vue instead)
- Using non-Auth0 authentication provider
- Static site generation only (SSG) without server runtime

## Critical Mistakes to Avoid

| Mistake | Solution |
|---------|----------|
| Installing `@auth0/auth0-vue` or `@auth0/auth0-spa-js` | Use `@auth0/auth0-nuxt` |
| Auth0 app type "Single Page Application" | Use "Regular Web Application" |
| Env vars: `VITE_AUTH0_*` or `VUE_APP_AUTH0_*` | Use `NUXT_AUTH0_*` prefix |
| Using `useUser()` for security checks | Use `useAuth0(event).getSession()` server-side |
| Missing callback URLs in Auth0 Dashboard | Add `http://localhost:3000/auth/callback` |
| Weak/missing session secret | Generate: `openssl rand -hex 64` |
| Hardcoding credentials in `nuxt.config.ts` | Leave runtimeConfig values as empty strings; Nuxt auto-fills from `NUXT_AUTH0_*` env vars |

## Quick Setup

```bash
# 1. Install
npm install @auth0/auth0-nuxt

# 2. Generate secret
openssl rand -hex 64
```

```bash
# 3. .env
NUXT_AUTH0_DOMAIN=your-tenant.auth0.com
NUXT_AUTH0_CLIENT_ID=your-client-id
NUXT_AUTH0_CLIENT_SECRET=your-client-secret
NUXT_AUTH0_SESSION_SECRET=<from-openssl>
NUXT_AUTH0_APP_BASE_URL=http://localhost:3000
NUXT_AUTH0_AUDIENCE=https://your-api  # optional
```

```typescript
// 4. nuxt.config.ts
// Leave values as empty strings — Nuxt auto-fills them from NUXT_AUTH0_* env vars at runtime.
// If you prefer explicit mapping, use: domain: process.env.NUXT_AUTH0_DOMAIN || ''
export default defineNuxtConfig({
  modules: ['@auth0/auth0-nuxt'],
  runtimeConfig: {
    auth0: {
      domain: '',
      clientId: '',
      clientSecret: '',
      sessionSecret: '',
      appBaseUrl: 'http://localhost:3000',
      audience: '',  // optional
    },
  },
})
```

## Built-in Routes

The SDK automatically mounts these routes:

| Route | Method | Purpose |
|-------|--------|---------|
| `/auth/login` | GET | Initiates login flow. Supports `?returnTo=/path` parameter |
| `/auth/callback` | GET | Handles Auth0 callback after login |
| `/auth/logout` | GET | Logs user out and redirects to Auth0 logout |
| `/auth/backchannel-logout` | POST | Receives logout tokens for back-channel logout |

**Customize:** Pass `routes: { login, callback, logout, backchannelLogout }` or `mountRoutes: false` to module config.

## Composables

| Composable | Context | Usage |
|------------|---------|-------|
| `useAuth0(event)` | Server-side | Access `getUser()`, `getSession()`, `getAccessToken()`, `logout()` |
| `useUser()` | Client-side | Display user data only. **Never use for security checks** |

```typescript
// Server example
const auth0 = useAuth0(event);
const session = await auth0.getSession();
```

```vue
<script setup>
const user = useUser();
</script>

<template>
  <div v-if="user">Welcome {{ user.name }}</div>
<template>
```

## Protecting Routes

**Three layers:** Route middleware (client), server middleware (SSR), API guards.

```typescript
// middleware/auth.ts - Client navigation
export default defineNuxtRouteMiddleware((to) => {
  if (!useUser().value) return navigateTo(`/auth/login?returnTo=${encodeURIComponent(to.path)}`);
});
```

```typescript
// server/middleware/auth.server.ts - SSR protection
export default defineEventHandler(async (event) => {
  const url = getRequestURL(event);
  const auth0Client = useAuth0(event);
  const session = await auth0Client.getSession();
  if (!session)  {
    return sendRedirect(event, `/auth/login?returnTo=${encodeURIComponent(url.pathname)}`);
  }
});
```

```typescript
// server/api/protected.ts - API endpoint protection
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const session = await auth0Client.getSession();

  if (!session) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized'
    });
  }

  return { data: 'protected data' };
});
```

**For role-based, permission-based, and advanced patterns:** [route-protection.md](./references/route-protection.md)

## Session Management

### Stateless (Default)
Uses encrypted, chunked cookies. No configuration needed.

### Stateful (Redis, MongoDB, etc.)
For larger sessions or distributed systems:

```typescript
// nuxt.config.ts
modules: [
  ['@auth0/auth0-nuxt', {
    sessionStoreFactoryPath: '~/server/utils/session-store-factory.ts'
  }]
]
```

**For complete session store implementations, see:** [session-stores.md](./references/session-stores.md)

## API Integration

Configure audience for API access tokens:

```typescript
// nuxt.config.ts
runtimeConfig: {
  auth0: {
    audience: 'https://your-api-identifier',
  }
}
```

Retrieve tokens server-side:

```typescript
// server/api/call-api.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const { accessToken } = await auth0Client.getAccessToken();

  return await $fetch('https://api.example.com/data', {
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });
});
```

## Security Checklist

- ✅ Server-side validation only (never trust `useUser()`)
- ✅ HTTPS in production
- ✅ Strong session secret (`openssl rand -hex 64`)
- ✅ Never commit `.env` files
- ✅ Stateful sessions for PII/large data

## Troubleshooting

| Error | Solution |
|-------|----------|
| "Module not found" | Install `@auth0/auth0-nuxt`, not `@auth0/auth0-vue` |
| "Missing domain/clientId/clientSecret" | Check `NUXT_AUTH0_` prefix, `.env` location, `runtimeConfig` |
| "Redirect URI mismatch" | Match Auth0 Dashboard callback to `appBaseUrl + /auth/callback` |
| "useAuth0 is not defined" | Use only in server context with H3 event object |
| Cookies too large | Use stateful sessions or reduce scopes |

## Additional Resources

**Guides:** [Route Protection Patterns](./references/route-protection.md) • [Custom Session Stores](./references/session-stores.md) • [Common Examples](./references/examples.md)

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-cli` - Manage Auth0 resources from the terminal

---

**Links:** [Auth0-Nuxt GitHub](https://github.com/auth0/auth0-nuxt) • [Auth0 Docs](https://auth0.com/docs) • [Nuxt Modules](https://nuxt.com/modules)
