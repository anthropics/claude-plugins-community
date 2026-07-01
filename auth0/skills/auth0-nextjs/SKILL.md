---
name: auth0-nextjs
description: >
  Use when adding Auth0 login, logout, protected pages, or middleware to a Next.js application. Supports App Router and Pages Router with @auth0/nextjs-auth0 — use even if the user says "add login to my Next.js app" or "protect my Next.js routes".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Next.js Integration

Add authentication to Next.js applications using @auth0/nextjs-auth0. Supports both App Router and Pages Router.

---

## Prerequisites

- Next.js 13+ application (App Router or Pages Router)
- Auth0 account and application configured
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Client-side only React apps** - Use `auth0-react` for Vite/CRA SPAs
- **React Native mobile apps** - Use `auth0-react-native` for iOS/Android
- **Non-Next.js frameworks** - Use framework-specific SDKs (Express, Vue, Angular, etc.)
- **Stateless APIs only** - Use JWT validation middleware if you don't need session management

---

## Quick Start Workflow

### 1. Install SDK

```bash
npm install @auth0/nextjs-auth0
```

### 2. Configure Environment

**For automated setup with Auth0 CLI**, see [Setup Guide](references/setup.md) for complete scripts.

**For manual setup:**

Create `.env.local`:

```bash
AUTH0_SECRET=<generate-a-32-character-secret>
APP_BASE_URL=http://localhost:3000
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
```

Generate secret: `openssl rand -hex 32`

**Important:** Add `.env.local` to `.gitignore`

### 3. Create Auth0 Client and Middleware

**Detect project structure first:** Check whether the project uses a `src/` directory (i.e. `src/app/` or `src/pages/` exists). This determines where to place files:
- **With `src/`:** `src/lib/auth0.ts`, `src/middleware.ts` (or `src/proxy.ts` for Next.js 16)
- **Without `src/`:** `lib/auth0.ts`, `middleware.ts` (or `proxy.ts` for Next.js 16)

Create `lib/auth0.ts` (or `src/lib/auth0.ts` if using the `src/` convention):

```typescript
import { Auth0Client } from '@auth0/nextjs-auth0/server';

export const auth0 = new Auth0Client({
  domain: process.env.AUTH0_DOMAIN!,
  clientId: process.env.AUTH0_CLIENT_ID!,
  clientSecret: process.env.AUTH0_CLIENT_SECRET!,
  secret: process.env.AUTH0_SECRET!,
  appBaseUrl: process.env.APP_BASE_URL!,
});
```

**Middleware Configuration (Next.js 15 vs 16):**

**Next.js 15** - Create `middleware.ts` (at project root, or `src/middleware.ts` if using `src/`):

```typescript
import { NextRequest } from 'next/server';
import { auth0 } from '@/lib/auth0';

export async function middleware(request: NextRequest) {
  return await auth0.middleware(request);
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)',
  ],
};
```

**Next.js 16** - You have two options:

**Option 1:** Use `middleware.ts` (same as Next.js 15, same `src/` placement rules):

```typescript
import { NextRequest } from 'next/server';
import { auth0 } from '@/lib/auth0';

export async function middleware(request: NextRequest) {
  return await auth0.middleware(request);
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)',
  ],
};
```

**Option 2:** Use `proxy.ts` (at project root, or `src/proxy.ts` if using `src/`):

```typescript
import { NextRequest } from 'next/server';
import { auth0 } from '@/lib/auth0';

export async function proxy(request: NextRequest) {
  return await auth0.middleware(request);
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)',
  ],
};
```

This automatically creates endpoints:
- `/auth/login` - Login
- `/auth/logout` - Logout
- `/auth/callback` - OAuth callback
- `/auth/profile` - User profile

### 4. Add User Context (Optional)

**Note:** In v4, wrapping with `<Auth0Provider>` is optional. Only needed if you want to pass an initial user during server rendering to `useUser()`.

**App Router** - Optionally wrap app in `app/layout.tsx`:

```typescript
import { Auth0Provider } from '@auth0/nextjs-auth0/client';
import { auth0 } from '@/lib/auth0';

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const session = await auth0.getSession();

  return (
    <html>
      <body>
        <Auth0Provider user={session?.user}>{children}</Auth0Provider>
      </body>
    </html>
  );
}
```

**Pages Router** - Optionally wrap app in `pages/_app.tsx`:

```typescript
import { Auth0Provider } from '@auth0/nextjs-auth0/client';
import type { AppProps } from 'next/app';

export default function App({ Component, pageProps }: AppProps) {
  return (
    <Auth0Provider user={pageProps.user}>
      <Component {...pageProps} />
    </Auth0Provider>
  );
}
```

### 5. Add Authentication UI

**Client Component** (works in both routers):

```typescript
'use client'; // Only needed for App Router

import { useUser } from '@auth0/nextjs-auth0/client';

export default function Profile() {
  const { user, isLoading } = useUser();

  if (isLoading) return <div>Loading...</div>;

  if (user) {
    return (
      <div>
        <img src={user.picture} alt={user.name} />
        <h2>Welcome, {user.name}!</h2>
        <a href="/auth/logout">Logout</a>
      </div>
    );
  }

  return <a href="/auth/login">Login</a>;
}
```

### 6. Test Authentication

Start your dev server:

```bash
npm run dev
```

Visit `http://localhost:3000` and test the login flow.

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup scripts, environment configuration, Auth0 CLI usage
- **[Integration Guide](references/integration.md)** - Server-side auth, protected routes, API routes, middleware
- **[API Reference](references/api.md)** - Complete SDK API, hooks, helpers, session management

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using v3 environment variables | v4 uses `APP_BASE_URL` and `AUTH0_DOMAIN` (not `AUTH0_BASE_URL` or `AUTH0_ISSUER_BASE_URL`) |
| Forgot to add callback URL in Auth0 Dashboard | Add `/auth/callback` to Allowed Callback URLs (e.g., `http://localhost:3000/auth/callback`) |
| Missing middleware configuration | v4 requires middleware to mount auth routes - create `middleware.ts` (Next.js 15+16) or `proxy.ts` (Next.js 16 only) with `auth0.middleware()` |
| Wrong route paths | v4 uses `/auth/login` not `/api/auth/login` - routes drop the `/api` prefix |
| Missing or weak AUTH0_SECRET | Generate secure secret with `openssl rand -hex 32` and store in .env.local |
| Using .env instead of .env.local | Next.js requires .env.local for local secrets, and .env.local should be in .gitignore |
| App created as SPA type in Auth0 | Must be Regular Web Application type for Next.js |
| Using removed v3 helpers | v4 removed `withPageAuthRequired` and `withApiAuthRequired` - use `getSession()` instead |
| Using useUser in Server Component | useUser is client-only, use `auth0.getSession()` for Server Components |
| AUTH0_DOMAIN includes https:// | v4 `AUTH0_DOMAIN` should be just the domain (e.g., `example.auth0.com`), no scheme |

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**V4 Setup:**
- Detect `src/` convention: check if `src/app/` or `src/pages/` exists — place all files inside `src/` if so
- Create `lib/auth0.ts` (or `src/lib/auth0.ts`) with `Auth0Client` instance
- Create middleware configuration (required):
  - Next.js 15: `middleware.ts` (or `src/middleware.ts`) with `middleware()` function
  - Next.js 16: `middleware.ts` with `middleware()` OR `proxy.ts` with `proxy()` function (same `src/` rules)
- Optional: Wrap with `<Auth0Provider>` for SSR user

**Client-Side Hooks:**
- `useUser()` - Get user in client components
- `user` - User profile object
- `isLoading` - Loading state

**Server-Side Methods:**
- `auth0.getSession()` - Get session in Server Components/API routes/middleware
- `auth0.getAccessToken()` - Get access token for calling APIs

**Common Use Cases:**
- Login/Logout links → Use `/auth/login` and `/auth/logout` paths (see Step 5)
- Protected pages (App Router) → [Integration Guide](references/integration.md#protected-pages-app-router)
- Protected pages (Pages Router) → [Integration Guide](references/integration.md#protected-pages-pages-router)
- API routes with auth → [Integration Guide](references/integration.md#protected-api-routes)
- Middleware protection → [Integration Guide](references/integration.md#middleware)

---

## References

- [Auth0 Next.js SDK Documentation](https://auth0.com/docs/libraries/nextjs)
- [Auth0 Next.js Quickstart](https://auth0.com/docs/quickstart/webapp/nextjs)
- [SDK GitHub Repository](https://github.com/auth0/nextjs-auth0)
