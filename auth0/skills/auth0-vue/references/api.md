## Common Patterns

### Protected Route (Vue Router)

**Install Vue Router:**
```bash
npm install vue-router
```

**Configure router (`src/router/index.ts`):**
```typescript
import { createRouter, createWebHistory } from 'vue-router';
import { createAuthGuard } from '@auth0/auth0-vue';
import Home from '../views/Home.vue';
import Profile from '../views/Profile.vue';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'Home',
      component: Home
    },
    {
      path: '/profile',
      name: 'Profile',
      component: Profile,
      beforeEnter: createAuthGuard()  // Protect this route
    }
  ]
});

export default router;
```

**Alternative: Use the exported `authGuard` directly:**
```typescript
import { createRouter, createWebHistory } from 'vue-router';
import { authGuard } from '@auth0/auth0-vue';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/profile',
      component: () => import('../views/Profile.vue'),
      beforeEnter: authGuard  // Use the pre-configured guard
    }
  ]
});
```

---

### Get User Profile

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';

const { user, isAuthenticated } = useAuth0();
</script>

<template>
  <div v-if="isAuthenticated">
    <h1>Profile</h1>
    <img :src="user?.picture" :alt="user?.name" />
    <p>Name: {{ user?.name }}</p>
    <p>Email: {{ user?.email }}</p>
    <p>User ID: {{ user?.sub }}</p>
  </div>
  <div v-else>
    <p>Please log in to view your profile</p>
  </div>
</template>
```

---

### Call Protected API

```vue
<script setup lang="ts">
import { ref } from 'vue';
import { useAuth0 } from '@auth0/auth0-vue';

const { getAccessTokenSilently } = useAuth0();
const data = ref(null);
const error = ref(null);

const callApi = async () => {
  try {
    const token = await getAccessTokenSilently({
      authorizationParams: {
        audience: 'https://your-api-identifier',
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
  }
};
</script>

<template>
  <div>
    <button @click="callApi">Call API</button>
    <div v-if="error">Error: {{ error }}</div>
    <pre v-if="data">{{ JSON.stringify(data, null, 2) }}</pre>
  </div>
</template>
```

**Note:** If calling APIs, add `audience` to your plugin configuration:

```typescript
app.use(
  createAuth0({
    domain: import.meta.env.VITE_AUTH0_DOMAIN,
    clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
    authorizationParams: {
      redirect_uri: window.location.origin,
      audience: 'https://your-api-identifier'  // Add this
    }
  })
);
```

---

### Handle Loading and Error States

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';

const { isLoading, error, isAuthenticated, user } = useAuth0();
</script>

<template>
  <div v-if="isLoading">
    Loading authentication...
  </div>

  <div v-else-if="error">
    Authentication error: {{ error.message }}
  </div>

  <div v-else>
    <div v-if="isAuthenticated">
      <h1>Welcome back, {{ user?.name }}!</h1>
      <!-- Authenticated content -->
    </div>
    <div v-else>
      <h1>Please log in</h1>
      <button @click="loginWithRedirect()">Login</button>
    </div>
  </div>
</template>
```

---

### Composition API with Reactive State

```vue
<script setup lang="ts">
import { computed } from 'vue';
import { useAuth0 } from '@auth0/auth0-vue';

const auth0 = useAuth0();

const userName = computed(() => auth0.user.value?.name || 'Guest');
const isLoggedIn = computed(() => auth0.isAuthenticated.value);
</script>

<template>
  <div>
    <p>{{ userName }}</p>
    <p v-if="isLoggedIn">You are logged in</p>
  </div>
</template>
```

---

## Configuration Options

### Complete Plugin Configuration

```typescript
app.use(
  createAuth0({
    domain: 'your-tenant.auth0.com',
    clientId: 'your-client-id',
    authorizationParams: {
      redirect_uri: window.location.origin,
      audience: 'https://your-api-identifier',  // For API calls
      scope: 'openid profile email',  // Default scopes
    },
    cacheLocation: 'localstorage',  // or 'memory' for stricter security
    useRefreshTokens: true,  // Enable refresh tokens
  })
);
```

---

## Testing

1. Start your dev server: `npm run dev`
2. Click "Login" button
3. Complete Auth0 Universal Login
4. Verify redirect back to your app with user authenticated
5. Navigate to protected routes
6. Click "Logout" and verify user is logged out

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Invalid state" error | Clear browser storage. Ensure `redirect_uri` matches configured callback URL in Auth0 |
| User stuck on loading | Check Auth0 application has correct callback URLs configured |
| API calls fail with 401 | Ensure `audience` is configured in plugin and matches your API identifier |
| Logout doesn't work | Include `returnTo` URL in logout options and configure in Auth0 "Allowed Logout URLs" |
| Router guard loops | Ensure auth guard checks `isLoading` before redirecting |

---

## Security Considerations

- **Never expose client secret** - Vue is client-side, use only public client credentials
- **Use PKCE** - Enabled by default with @auth0/auth0-vue
- **Validate tokens on backend** - Never trust client-side token validation
- **Use HTTPS in production** - Auth0 requires HTTPS for production redirect URLs
- **Implement proper CORS** - Configure allowed origins in Auth0 application settings

---

## Related Skills

- `auth0-quickstart` - Initial Auth0 account setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-organizations` - B2B multi-tenancy support
- `auth0-passkeys` - Add passkey authentication

---

## References

- [Auth0 Vue SDK Documentation](https://auth0.com/docs/libraries/auth0-vue)
- [Auth0 Vue SDK GitHub](https://github.com/auth0/auth0-vue)
- [Auth0 Vue Quickstart](https://auth0.com/docs/quickstart/spa/vuejs)
- [Vue Router Documentation](https://router.vuejs.org/)
