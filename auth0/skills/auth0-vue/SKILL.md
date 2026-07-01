---
name: auth0-vue
description: >
  Use when adding Auth0 login, logout, protected routes, or user sessions to a Vue 3 SPA. Integrates @auth0/auth0-vue — use even if the user says "add login to my Vue app" or "protect my Vue routes" without naming the SDK.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Vue.js Integration

Add authentication to Vue.js 3 single-page applications using @auth0/auth0-vue.

---

## Prerequisites

- Vue 3+ application (Vite or Vue CLI)
- Auth0 account and application configured
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Server-side rendered Vue apps** - See [Auth0 Nuxt.js guide](https://auth0.com/docs/quickstart/webapp/nuxt) for SSR patterns
- **Vue 2 applications** - This SDK requires Vue 3+, use legacy @auth0/auth0-spa-js wrapper
- **Embedded login** - This SDK uses Auth0 Universal Login (redirect-based)
- **Backend API authentication** - Use express-openid-connect or JWT validation instead

---

## Quick Start Workflow

### 1. Install SDK

```bash
npm install @auth0/auth0-vue
```

### 2. Configure Environment

**For automated setup with Auth0 CLI**, see [Setup Guide](references/setup.md) for complete scripts.

**For manual setup:**

Create `.env` file:

```bash
VITE_AUTH0_DOMAIN=your-tenant.auth0.com
VITE_AUTH0_CLIENT_ID=your-client-id
```

### 3. Configure Auth0 Plugin

Update `src/main.ts`:

```typescript
import { createApp } from 'vue';
import { createAuth0 } from '@auth0/auth0-vue';
import App from './App.vue';

const app = createApp(App);

app.use(
  createAuth0({
    domain: import.meta.env.VITE_AUTH0_DOMAIN,
    clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
    authorizationParams: {
      redirect_uri: window.location.origin
    }
  })
);

app.mount('#app');
```

### 4. Add Authentication UI

Create a login component:

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';

const { loginWithRedirect, logout, isAuthenticated, user, isLoading } = useAuth0();
</script>

<template>
  <div>
    <div v-if="isLoading">Loading...</div>

    <div v-else-if="isAuthenticated">
      <img :src="user?.picture" :alt="user?.name" />
      <span>Welcome, {{ user?.name }}</span>
      <button @click="logout({ logoutParams: { returnTo: window.location.origin }})">
        Logout
      </button>
    </div>

    <button v-else @click="loginWithRedirect()">
      Login
    </button>
  </div>
</template>
```

### 5. Test Authentication

Start your dev server and test the login flow:

```bash
npm run dev
```

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup scripts (Bash/PowerShell), CLI commands, manual configuration
- **[Integration Guide](references/integration.md)** - Protected routes, API calls, error handling, composables
- **[API Reference](references/api.md)** - Complete SDK API, configuration options, composables reference, testing strategies

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgot to add redirect URI in Auth0 Dashboard | Add your application URL (e.g., `http://localhost:3000`, `https://app.example.com`) to Allowed Callback URLs in Auth0 Dashboard |
| Using wrong env var prefix | Vite requires `VITE_` prefix, Vue CLI uses `VUE_APP_` |
| Not handling loading state | Always check `isLoading` before rendering auth-dependent UI |
| Storing tokens in localStorage | Never manually store tokens - SDK handles secure storage automatically |
| Missing createAuth0 plugin registration | Must call `app.use(createAuth0({...}))` before mounting app |
| Accessing auth before plugin loads | Wrap auth-dependent code in `v-if="!isLoading"` |

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Core Composables:**
- `useAuth0()` - Main authentication composable
- `isAuthenticated` - Reactive check if user is logged in
- `user` - Reactive user profile information
- `loginWithRedirect()` - Initiate login
- `logout()` - Log out user
- `getAccessTokenSilently()` - Get access token for API calls

**Common Use Cases:**
- Login/Logout buttons → See Step 4 above
- Protected routes with navigation guards → [Integration Guide](references/integration.md#protected-routes)
- API calls with tokens → [Integration Guide](references/integration.md#calling-apis)
- Error handling → [Integration Guide](references/integration.md#error-handling)

---

## References

- [Auth0 Vue SDK Documentation](https://auth0.com/docs/libraries/auth0-vue)
- [Auth0 Vue Quickstart](https://auth0.com/docs/quickstart/spa/vuejs)
- [SDK GitHub Repository](https://github.com/auth0/auth0-vue)
