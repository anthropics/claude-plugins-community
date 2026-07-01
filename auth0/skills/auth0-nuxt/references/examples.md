# Common Patterns and Examples

Real-world patterns and complete examples for Auth0-Nuxt implementations.

## Basic App Layout

### Navigation with Conditional Login/Logout

```vue
<!-- components/AppHeader.vue -->
<script setup>
const user = useUser();
const route = useRoute();
</script>

<template>
  <header>
    <nav>
      <a href="/">Home</a>
      <a href="/dashboard" v-if="user">Dashboard</a>
      <a href="/profile" v-if="user">Profile</a>

      <div class="auth-actions">
        <a v-if="user" :href="`/auth/logout`">
          Logout ({{ user.name }})
        </a>
        <a v-else :href="`/auth/login?returnTo=${encodeURIComponent(route.path)}`">
          Login
        </a>
      </div>
    </nav>
  </header>
</template>
```

### App Layout with User Avatar

```vue
<!-- layouts/default.vue -->
<script setup>
const user = useUser();
</script>

<template>
  <div class="app-layout">
    <header>
      <nav>
        <a href="/">Home</a>

        <div v-if="user" class="user-menu">
          <img :src="user.picture" :alt="user.name" />
          <span>{{ user.name }}</span>
          <a href="/auth/logout">Logout</a>
        </div>
        <a v-else href="/auth/login">Login</a>
      </nav>
    </header>

    <main>
      <slot />
    </main>
  </div>
</template>
```

## User Profile Page

```vue
<!-- pages/profile.vue -->
<script setup lang="ts">
definePageMeta({
  middleware: ['auth']
});

const user = useUser();
</script>

<template>
  <div class="profile" v-if="user">
    <h1>Profile</h1>

    <div class="profile-info">
      <img :src="user.picture" :alt="user.name" />

      <dl>
        <dt>Name</dt>
        <dd>{{ user.name }}</dd>

        <dt>Email</dt>
        <dd>{{ user.email }}</dd>
        <dd v-if="user.email_verified" class="verified">✓ Verified</dd>
        <dd v-else class="not-verified">⚠ Not Verified</dd>

        <dt>User ID</dt>
        <dd>{{ user.sub }}</dd>

        <dt>Last Updated</dt>
        <dd>{{ new Date(user.updated_at).toLocaleString() }}</dd>
      </dl>
    </div>
  </div>
</template>
```

## Protected API Calls

### Fetching User-Specific Data

```typescript
// server/api/user/profile.get.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const user = await auth0Client.getUser();

  if (!user) {
    throw createError({
      statusCode: 401,
      statusMessage: 'Unauthorized'
    });
  }

  // Fetch user profile from database
  const profile = await getUserProfile(user.sub);

  return { profile };
});
```

### Calling External API with Access Token

```typescript
// server/api/external/data.get.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const { accessToken } = await auth0Client.getAccessToken();

  const response = await $fetch('https://api.example.com/data', {
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  return response;
});
```

### Client-Side API Call Pattern

```vue
<!-- pages/dashboard.vue -->
<script setup>
definePageMeta({
  middleware: ['auth']
});

const { data, error } = await useFetch('/api/user/profile');
</script>

<template>
  <div>
    <h1>Dashboard</h1>
    <pre v-if="data">{{ data }}</pre>
    <div v-if="error">Error: {{ error }}</div>
  </div>
</template>
```

## Role-Based UI

### Conditional Rendering by Role

```vue
<script setup>
const user = useUser();

const hasRole = (role: string) => {
  if (!user.value) return false;
  const roles = user.value['https://my-app.com/roles'] || [];
  return roles.includes(role);
};
</script>

<template>
  <div>
    <h1>Dashboard</h1>

    <div v-if="hasRole('admin')">
      <h2>Admin Panel</h2>
      <a href="/admin">Admin Dashboard</a>
    </div>

    <div v-if="hasRole('editor')">
      <h2>Editor Tools</h2>
      <a href="/editor">Content Editor</a>
    </div>

    <div>
      <h2>User Content</h2>
      <p>All users see this</p>
    </div>
  </div>
</template>
```

### Composable for Role Checking

```typescript
// composables/useRoles.ts
export const useRoles = () => {
  const user = useUser();

  const hasRole = (role: string) => {
    if (!user.value) return false;
    const roles = user.value['https://my-app.com/roles'] || [];
    return roles.includes(role);
  };

  const hasAnyRole = (roles: string[]) => {
    return roles.some(role => hasRole(role));
  };

  const hasAllRoles = (roles: string[]) => {
    return roles.every(role => hasRole(role));
  };

  return {
    hasRole,
    hasAnyRole,
    hasAllRoles
  };
};
```

Usage:

```vue
<script setup>
const { hasRole, hasAnyRole } = useRoles();
</script>

<template>
  <button v-if="hasRole('admin')">Delete</button>
  <button v-if="hasAnyRole(['admin', 'moderator'])">Edit</button>
</template>
```

## Multi-Tenant Applications

### Tenant Selection After Login

```typescript
// server/api/auth/callback.get.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const { appState } = await auth0Client.completeInteractiveLogin(
    new URL(event.node.req.url, useRuntimeConfig().auth0.appBaseUrl)
  );

  const user = await auth0Client.getUser();
  const tenants = user?.['https://my-app.com/tenants'] || [];

  // If user has multiple tenants, redirect to tenant selection
  if (tenants.length > 1) {
    return sendRedirect(event, '/select-tenant');
  }

  // Single tenant, set and redirect
  if (tenants.length === 1) {
    // Store tenant in session or cookie
    setCookie(event, 'tenant-id', tenants[0]);
  }

  return sendRedirect(event, appState?.returnTo || '/');
});
```

### Tenant-Based Data Isolation

```typescript
// server/api/data.get.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const user = await auth0Client.getUser();

  if (!user) {
    throw createError({ statusCode: 401 });
  }

  const tenantId = getCookie(event, 'tenant-id');

  if (!tenantId) {
    throw createError({
      statusCode: 400,
      statusMessage: 'No tenant selected'
    });
  }

  // Verify user has access to this tenant
  const tenants = user['https://my-app.com/tenants'] || [];
  if (!tenants.includes(tenantId)) {
    throw createError({
      statusCode: 403,
      statusMessage: 'Access denied to this tenant'
    });
  }

  return getTenantData(tenantId);
});
```

## Organization Support

### Organization Login

```vue
<!-- pages/org/[organization]/login.vue -->
<script setup>
const route = useRoute();
const organization = route.params.organization;
</script>

<template>
  <a :href="`/auth/login?organization=${organization}`">
    Login to {{ organization }}
  </a>
</template>
```

### Custom Login Handler with Organization

```typescript
// server/routes/auth/org-login.get.ts
export default defineEventHandler(async (event) => {
  const query = getQuery(event);
  const organization = query.organization as string;

  if (!organization) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Organization parameter required'
    });
  }

  const auth0Client = useAuth0(event);
  const authUrl = await auth0Client.startInteractiveLogin({
    authorizationParams: {
      organization: organization
    },
    appState: {
      returnTo: query.returnTo || '/'
    }
  });

  return sendRedirect(event, authUrl.href);
});
```

## Impersonation Support

### Start Impersonation

```typescript
// server/api/admin/impersonate.post.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const admin = await auth0Client.getUser();

  if (!admin) {
    throw createError({ statusCode: 401 });
  }

  // Check admin permission
  const permissions = admin['https://my-app.com/permissions'] || [];
  if (!permissions.includes('impersonate:users')) {
    throw createError({ statusCode: 403 });
  }

  const body = await readBody(event);
  const { userId } = body;

  // Store impersonation in session
  const session = await auth0Client.getSession();
  if (session) {
    session.impersonating = {
      adminId: admin.sub,
      userId: userId
    };
  }

  return { success: true };
});
```

### End Impersonation

```typescript
// server/api/admin/stop-impersonate.post.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const session = await auth0Client.getSession();

  if (session?.impersonating) {
    delete session.impersonating;
  }

  return { success: true };
});
```

## Progressive Enhancement

### Login Link with Fallback

```vue
<template>
  <!-- Progressive enhancement: JavaScript-free login -->
  <a href="/auth/login" @click.prevent="handleLogin">
    Login
  </a>
</template>

<script setup>
const handleLogin = async () => {
  // Enhanced behavior with JavaScript
  const returnTo = useRoute().fullPath;
  await navigateTo(`/auth/login?returnTo=${encodeURIComponent(returnTo)}`);
};
</script>
```

## Error Handling

### Global Error Handler

```typescript
// server/middleware/error-handler.server.ts
export default defineEventHandler(async (event) => {
  try {
    // Continue to next middleware/handler
  } catch (error) {
    console.error('Authentication error:', error);

    if (error.statusCode === 401) {
      return sendRedirect(event, '/auth/login');
    }

    throw error;
  }
});
```

### Client-Side Error Boundary

```vue
<!-- error.vue -->
<script setup>
const error = useError();
</script>

<template>
  <div v-if="error.statusCode === 401">
    <h1>Authentication Required</h1>
    <a href="/auth/login">Log In</a>
  </div>

  <div v-else-if="error.statusCode === 403">
    <h1>Access Denied</h1>
    <p>You don't have permission to access this resource.</p>
  </div>

  <div v-else>
    <h1>Error {{ error.statusCode }}</h1>
    <p>{{ error.message }}</p>
  </div>
</template>
```

## Loading States

### Auth Loading Component

```vue
<!-- components/AuthGuard.vue -->
<script setup>
const user = useUser();
const loading = ref(true);

onMounted(() => {
  // Give time for SSR hydration
  setTimeout(() => {
    loading.value = false;
  }, 100);
});
</script>

<template>
  <div v-if="loading">
    Loading...
  </div>
  <div v-else-if="user">
    <slot />
  </div>
  <div v-else>
    <p>You need to log in</p>
    <a href="/auth/login">Log In</a>
  </div>
</template>
```

## Logging and Monitoring

### Audit Log Middleware

```typescript
// server/middleware/audit-log.server.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);
  const user = await auth0Client.getUser();

  if (user) {
    console.log({
      timestamp: new Date().toISOString(),
      userId: user.sub,
      path: event.node.req.url,
      method: event.node.req.method,
      ip: getRequestIP(event);
    });
  }
});
```

## Token Refresh Handling

```typescript
// server/api/sensitive-data.get.ts
export default defineEventHandler(async (event) => {
  const auth0Client = useAuth0(event);

  try {
    const { accessToken } = await auth0Client.getAccessToken();

    return await $fetch('https://api.example.com/sensitive', {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
  } catch (error) {
    // Token might be expired, SDK handles refresh automatically
    // If refresh fails, session is invalid
    if (error.statusCode === 401) {
      throw createError({
        statusCode: 401,
        statusMessage: 'Session expired, please log in again'
      });
    }
    throw error;
  }
});
```
