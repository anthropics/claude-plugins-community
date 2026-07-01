# Route Protection Patterns for Auth0-Nuxt

Comprehensive guide for protecting routes, pages, and API endpoints in Nuxt 3/4 applications with Auth0.

## Protection Layers

Auth0-Nuxt provides three protection layers:

1. **Route Middleware** - Client-side navigation guards (pages)
2. **Server Middleware** - SSR protection (server-rendered routes)
3. **API Route Guards** - Protect API endpoints

## Route Middleware (Client-Side Navigation)

### Basic Route Middleware

Create `middleware/auth.ts`:

```typescript
export default defineNuxtRouteMiddleware((to, from) => {
  const user = useUser();

  if (!user.value) {
    return navigateTo(`/auth/login?returnTo=${encodeURIComponent(to.path)}`);
  }
});
```

### Apply to Specific Pages

```vue
<!-- pages/dashboard.vue -->
<script setup>
definePageMeta({
  middleware: ['auth']
});
</script>

<template>
  <div>Private Dashboard</div>
</template>
```

### Role-Based Middleware

```typescript
// middleware/admin.ts
export default defineNuxtRouteMiddleware((to, from) => {
  const user = useUser();

  if (!user.value) {
    return navigateTo(`/auth/login?returnTo=${encodeURIComponent(to.path)}`);
  }

  // Check for admin role
  const roles = user.value['https://my-app.com/roles'] || [];
  if (!roles.includes('admin')) {
    return navigateTo('/unauthorized');
  }
});
```

```vue
<!-- pages/admin/index.vue -->
<script setup>
definePageMeta({
  middleware: ['admin']
});
</script>
```

### Permission-Based Middleware

```typescript
// middleware/permissions.ts
export default defineNuxtRouteMiddleware((to, from) => {
  const user = useUser();

  if (!user.value) {
    return navigateTo(`/auth/login?returnTo=${encodeURIComponent(to.path)}`);
  }

  // Check for specific permission
  const permissions = user.value['https://my-app.com/permissions'] || [];
  const requiredPermission = to.meta.permission;

  if (requiredPermission && !permissions.includes(requiredPermission)) {
    return navigateTo('/forbidden');
  }
});
```

```vue
<!-- pages/settings/billing.vue -->
<script setup>
definePageMeta({
  middleware: ['permissions'],
  permission: 'read:billing'
});
</script>
```

### Multiple Middleware Chain

```vue
<script setup>
definePageMeta({
  middleware: ['auth', 'admin', 'audit-log']
});
</script>
```

## Server Middleware (SSR Protection)

### Global Server Middleware

```typescript
// server/middleware/auth.server.ts
export default defineEventHandler(async (event) => {
  const url = getRequestURL(event);

  // Skip auth routes
  if (url.pathname.startsWith('/auth/')) {
    return;
  }

  // Protect all /dashboard routes
  if (url.pathname.startsWith('/dashboard')) {
    const auth0Client = useAuth0(event);
    const session = await auth0Client.getSession();

    if (!session) {
      return sendRedirect(event, `/auth/login?returnTo=${encodeURIComponent(url.pathname)}`);
    }
  }
});
```

### Path-Specific Protection

```typescript
// server/middleware/auth.server.ts
const protectedPaths = ['/dashboard', '/profile', '/settings'];

export default defineEventHandler(async (event) => {
  const url = getRequestURL(event);

  const isProtected = protectedPaths.some(path =>
    url.pathname.startsWith(path)
  );

  if (isProtected) {
    const auth0Client = useAuth0(event);
    const session = await auth0Client.getSession();

    if (!session) {
      return sendRedirect(event, `/auth/login?returnTo=${encodeURIComponent(url.pathname)}`);
    }
  }
});
```

### Role-Based Server Protection

```typescript
// server/middleware/admin-routes.server.ts
export default defineEventHandler(async (event) => {
  const url = getRequestURL(event);

  if (url.pathname.startsWith('/admin')) {
    const auth0Client = useAuth0(event);
    const session = await auth0Client.getSession();

    if (!session) {
      return sendRedirect(event, `/auth/login?returnTo=${encodeURIComponent(url.pathname)}`);
    }

    const user = await auth0Client.getUser();
    const roles = user?.['https://my-app.com/roles'] || [];

    if (!roles.includes('admin')) {
      throw createError({
        statusCode: 403,
        statusMessage: 'Forbidden: Admin access required'
      });
    }
  }
});
```

## API Route Protection

### Basic API Protection

```typescript
// server/api/user-data.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const session = await auth0Client.getSession();

  if (!session) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized'
    });
  }

  return { data: 'protected user data' };
});
```

### Reusable Auth Guard

```typescript
// server/utils/require-auth.ts
export async function requireAuth(event: H3Event) {
  const auth0Client = useAuth0(event);
  const session = await auth0Client.getSession();

  if (!session) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized'
    });
  }

  return session;
}
```

Use in API routes:

```typescript
// server/api/protected.ts
export default defineEventHandler(async (event) => {
  await requireAuth(event);
  return { message: 'This is protected' };
});
```

### Permission-Based API Protection

```typescript
// server/utils/require-permission.ts
export async function requirePermission(
  event: H3Event,
  permission: string
) {
  const auth0Client = useAuth0(event);
  const user = await auth0Client.getUser();

  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized'
    });
  }

  const permissions = user['https://my-app.com/permissions'] || [];

  if (!permissions.includes(permission)) {
    throw createError({
      statusCode: 403,
      statusMessage: `Forbidden: Missing permission '${permission}'`
    });
  }

  return user;
}
```

Use in API routes:

```typescript
// server/api/billing/invoices.get.ts
export default defineEventHandler(async (event) => {
  await requirePermission(event, 'read:billing');

  return { invoices: [] };
});
```

### Global API Middleware

```typescript
// server/middleware/api-auth.server.ts
export default defineEventHandler(async (event) => {
  const url = getRequestURL(event);

  // Protect all API routes except public ones
  if (url.pathname.startsWith('/api/')) {
    const publicRoutes = ['/api/health', '/api/version'];

    if (!publicRoutes.includes(url.pathname)) {
      const auth0Client = useAuth0(event);
      const session = await auth0Client.getSession();

      if (!session) {
        throw createError({
          statusCode: 401,
          statusMessage: 'Unauthorized'
        });
      }
    }
  }
});
```

## Advanced Patterns

### Conditional Protection by Environment

```typescript
// middleware/auth.ts
export default defineNuxtRouteMiddleware((to, from) => {
  const config = useRuntimeConfig();

  // Skip auth in development
  if (config.public.environment === 'development') {
    return;
  }

  const user = useUser();
  if (!user.value) {
    return navigateTo(`/auth/login?returnTo=${encodeURIComponent(to.path)}`);
  }
});
```

### Subscription-Based Protection

```typescript
// middleware/subscription.ts
export default defineNuxtRouteMiddleware((to, from) => {
  const user = useUser();

  if (!user.value) {
    return navigateTo(`/auth/login?returnTo=${encodeURIComponent(to.path)}`);
  }

  const subscription = user.value['https://my-app.com/subscription'];

  if (!subscription || subscription.status !== 'active') {
    return navigateTo('/subscribe');
  }
});
```

### Rate Limiting Protection

```typescript
// server/middleware/rate-limit.server.ts
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const user = await auth0Client.getUser();

  if (!user) {
    return;
  }

  const userId = user.sub;
  const now = Date.now();
  const limit = rateLimitMap.get(userId);

  if (!limit || now > limit.resetAt) {
    rateLimitMap.set(userId, {
      count: 1,
      resetAt: now + 60000 // 1 minute
    });
  } else {
    limit.count++;

    if (limit.count > 100) {
      throw createError({
        statusCode: 429,
        statusMessage: 'Too Many Requests'
      });
    }
  }
});
```

### Email Verification Required

```typescript
// middleware/verified.ts
export default defineNuxtRouteMiddleware((to, from) => {
  const user = useUser();

  if (!user.value) {
    return navigateTo(`/auth/login?returnTo=${encodeURIComponent(to.path)}`);
  }

  if (!user.value.email_verified) {
    return navigateTo('/verify-email');
  }
});
```

## Error Pages

### 401 Unauthorized Page

```vue
<!-- pages/unauthorized.vue -->
<template>
  <div>
    <h1>Unauthorized</h1>
    <p>You need to log in to access this page.</p>
    <a :href="`/auth/login?returnTo=${encodeURIComponent($route.query.returnTo || '/')}`">
      Log In
    </a>
  </div>
</template>
```

### 403 Forbidden Page

```vue
<!-- pages/forbidden.vue -->
<template>
  <div>
    <h1>Forbidden</h1>
    <p>You don't have permission to access this resource.</p>
    <a href="/">Go Home</a>
  </div>
</template>
```

## Testing Protected Routes

### Unit Testing Middleware

```typescript
// middleware/auth.spec.ts
import { describe, it, expect, vi } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';

mockNuxtImport('useUser', () => {
  return () => ({ value: null });
});

mockNuxtImport('navigateTo', () => {
  return vi.fn((path) => path);
});

describe('auth middleware', () => {
  it('should redirect to login when user is not authenticated', async () => {
    const { default: authMiddleware } = await import('./auth');
    const result = authMiddleware(
      { path: '/dashboard' },
      { path: '/' }
    );

    expect(result).toBe('/auth/login?returnTo=/dashboard');
  });
});
```

### E2E Testing with Playwright

```typescript
// test/protected-routes.spec.ts
import { test, expect } from '@playwright/test';

test('should redirect to login when accessing protected route', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page).toHaveURL(/\/auth\/login/);
});

test('should access protected route when logged in', async ({ page }) => {
  // Login first
  await page.goto('/auth/login');
  // ... perform login
  await page.waitForURL('/');

  // Access protected route
  await page.goto('/dashboard');
  await expect(page).toHaveURL('/dashboard');
});
```

## Security Checklist

- [ ] Never rely on `useUser()` for any security-critical decisions (it's client-side only and can be tampered with)
- [ ] Always validate sessions server-side with `useAuth0(event).getSession()` for all security-critical decisions
- [ ] Implement proper error handling (401/403 responses)
- [ ] Validate `returnTo` parameter (SDK does this automatically)
- [ ] Use HTTPS in production
- [ ] Implement rate limiting for API routes
- [ ] Log authentication failures for monitoring
- [ ] Test protected routes thoroughly
- [ ] Implement proper error pages
- [ ] Consider role/permission hierarchies

## Common Pitfalls

### ❌ Client-Side Only Protection
```typescript
// BAD - Can be bypassed
if (!useUser().value) {
  return navigateTo('/login');
}
```

### ✅ Server-Side Validation
```typescript
// GOOD - Cannot be bypassed
const session = await useAuth0(event).getSession();
if (!session) {
  throw createError({ statusCode: 401 });
}
```

### ❌ Forgetting SSR Context
```typescript
// BAD - Only protects client-side navigation
definePageMeta({ middleware: ['auth'] });
```

### ✅ Both Client and Server Protection
```typescript
// GOOD - Protects both client navigation and SSR
definePageMeta({ middleware: ['auth'] });
// PLUS server middleware in server/middleware/
```
