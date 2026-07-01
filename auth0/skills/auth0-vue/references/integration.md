# Auth0 Vue Integration Patterns

Practical implementation patterns and examples for common use cases.

---

## Protected Routes

### Navigation Guard

Create a navigation guard to protect routes:

```typescript
// src/router/index.ts
import { createRouter, createWebHistory } from 'vue-router';
import { createAuthGuard } from '@auth0/auth0-vue';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      component: () => import('../views/Home.vue')
    },
    {
      path: '/profile',
      component: () => import('../views/Profile.vue'),
      beforeEnter: createAuthGuard(app)
    }
  ]
});

export default router;
```

### Alternative: Component-Level Guard

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import { watchEffect } from 'vue';
import { useRouter } from 'vue-router';

const { isAuthenticated, isLoading, loginWithRedirect } = useAuth0();
const router = useRouter();

watchEffect(() => {
  if (!isLoading.value && !isAuthenticated.value) {
    loginWithRedirect();
  }
});
</script>

<template>
  <div v-if="isAuthenticated">
    <!-- Protected content -->
  </div>
</template>
```

---

## User Profile

### Display User Information

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';

const { user, isAuthenticated } = useAuth0();
</script>

<template>
  <div v-if="isAuthenticated">
    <img :src="user?.picture" :alt="user?.name" />
    <h2>{{ user?.name }}</h2>
    <p>{{ user?.email }}</p>
    <pre>{{ JSON.stringify(user, null, 2) }}</pre>
  </div>
</template>
```

---

## Calling APIs

### API Call with Access Token

```vue
<script setup lang="ts">
import { ref } from 'vue';
import { useAuth0 } from '@auth0/auth0-vue';

const { getAccessTokenSilently } = useAuth0();
const data = ref(null);
const error = ref(null);
const loading = ref(false);

const callApi = async () => {
  loading.value = true;
  error.value = null;

  try {
    const token = await getAccessTokenSilently({
      authorizationParams: {
        audience: 'https://your-api-identifier'
      }
    });

    const response = await fetch('https://your-api.com/data', {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });

    data.value = await response.json();
  } catch (err) {
    error.value = err.message;
  } finally {
    loading.value = false;
  }
};
</script>

<template>
  <div>
    <button @click="callApi" :disabled="loading">
      {{ loading ? 'Loading...' : 'Call API' }}
    </button>
    <div v-if="error" class="error">{{ error }}</div>
    <pre v-if="data">{{ JSON.stringify(data, null, 2) }}</pre>
  </div>
</template>
```

### Configure Plugin for API Calls

When calling APIs, add `audience` to your plugin configuration:

```typescript
// src/main.ts
app.use(
  createAuth0({
    domain: import.meta.env.VITE_AUTH0_DOMAIN,
    clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
    authorizationParams: {
      redirect_uri: window.location.origin,
      audience: 'https://your-api-identifier' // Add this
    }
  })
);
```

---

## Error Handling

### Handle Loading and Error States

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';

const { isLoading, error, isAuthenticated, user } = useAuth0();
</script>

<template>
  <div v-if="isLoading">Loading authentication...</div>

  <div v-else-if="error">
    <h2>Authentication Error</h2>
    <p>{{ error.message }}</p>
  </div>

  <div v-else-if="isAuthenticated">
    <h1>Welcome back, {{ user?.name }}!</h1>
    <!-- Authenticated app content -->
  </div>

  <div v-else>
    <h1>Please log in</h1>
    <LoginButton />
  </div>
</template>
```

---

## Composable Patterns

### Custom Auth Composable

Create a custom composable for common auth operations:

```typescript
// src/composables/useAuthHelper.ts
import { computed } from 'vue';
import { useAuth0 } from '@auth0/auth0-vue';

export function useAuthHelper() {
  const {
    isAuthenticated,
    user,
    loginWithRedirect,
    logout,
    getAccessTokenSilently
  } = useAuth0();

  const userName = computed(() => user.value?.name || 'Guest');
  const userEmail = computed(() => user.value?.email || '');

  const login = () => {
    loginWithRedirect();
  };

  const logoutUser = () => {
    logout({ logoutParams: { returnTo: window.location.origin } });
  };

  const callProtectedApi = async (url: string) => {
    const token = await getAccessTokenSilently();
    return fetch(url, {
      headers: { Authorization: `Bearer ${token}` }
    });
  };

  return {
    isAuthenticated,
    userName,
    userEmail,
    login,
    logoutUser,
    callProtectedApi
  };
}
```

**Usage:**
```vue
<script setup lang="ts">
import { useAuthHelper } from '@/composables/useAuthHelper';

const { isAuthenticated, userName, login, logoutUser } = useAuthHelper();
</script>

<template>
  <div>
    <span v-if="isAuthenticated">Welcome, {{ userName }}</span>
    <button v-if="isAuthenticated" @click="logoutUser">Logout</button>
    <button v-else @click="login">Login</button>
  </div>
</template>
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Invalid state" error | Clear browser storage and try again. Ensure `redirect_uri` matches configured callback URL |
| User stuck on loading | Check Auth0 application settings have correct callback URLs configured |
| API calls fail with 401 | Ensure `audience` is configured in plugin and matches your API identifier |
| Logout doesn't work | Include `returnTo` URL in logout options and configure in Auth0 "Allowed Logout URLs" |
| CORS errors | Add your application URL to "Allowed Web Origins" in Auth0 application settings |
| Composables not reactive | Ensure you're accessing `.value` on refs returned from `useAuth0()` |

---

## Security Considerations

### Client-Side Security

- **Never expose client secret** - Vue runs client-side, use only public client credentials
- **Use PKCE** - Enabled by default with @auth0/auth0-vue
- **Validate tokens on backend** - Never trust client-side token validation
- **Use HTTPS in production** - Auth0 requires HTTPS for production redirect URLs
- **Implement proper CORS** - Configure allowed origins in Auth0 application settings

### Token Storage

The SDK stores tokens in memory by default (cleared on page refresh). To persist sessions:

```typescript
app.use(
  createAuth0({
    domain: import.meta.env.VITE_AUTH0_DOMAIN,
    clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
    cacheLocation: 'localstorage', // or 'memory' for stricter security
    useRefreshTokens: true
  })
);
```

---

## Advanced Patterns

### Custom Login with Options

```typescript
import { useAuth0 } from '@auth0/auth0-vue';

const { loginWithRedirect } = useAuth0();

// Login with specific connection
await loginWithRedirect({
  authorizationParams: {
    connection: 'google-oauth2'
  }
});

// Login with signup screen
await loginWithRedirect({
  authorizationParams: {
    screen_hint: 'signup'
  }
});
```

### Handle Redirect Callback

```vue
<script setup lang="ts">
import { onMounted } from 'vue';
import { useAuth0 } from '@auth0/auth0-vue';
import { useRouter } from 'vue-router';

const { handleRedirectCallback } = useAuth0();
const router = useRouter();

onMounted(async () => {
  if (window.location.search.includes('code=')) {
    await handleRedirectCallback();
    router.push('/');
  }
});
</script>
```

---

## Testing

### Manual Testing Checklist

1. **Login Flow**
   - Start dev server: `npm run dev`
   - Click "Login" button
   - Complete Auth0 Universal Login
   - Verify redirect back to app with user authenticated

2. **Logout Flow**
   - Click "Logout" button
   - Verify user is logged out
   - Verify redirect to correct page

3. **Protected Routes**
   - Navigate to protected route while logged out
   - Verify redirect to Auth0 login
   - After login, verify redirect back to protected route

4. **API Calls**
   - Call protected API endpoint
   - Verify access token is included
   - Verify API responds correctly

---

## Next Steps

- [API Reference](api.md) - Complete SDK documentation
- [Setup Guide](setup.md) - Detailed setup instructions
- [Main Skill](../SKILL.md) - Return to main skill guide
