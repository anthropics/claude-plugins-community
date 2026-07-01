# Integration Patterns

## Authentication Flow

The Ionic Vue + Capacitor authentication flow:

1. User taps "Login" button
2. `loginWithRedirect()` is called with a custom `openUrl` that uses `Browser.open()`
3. Capacitor Browser opens Auth0 Universal Login in a system browser (SFSafariViewController on iOS, Chrome Custom Tabs on Android)
4. User authenticates with Auth0
5. Auth0 redirects to the custom scheme callback URL (`packageId://domain/capacitor/packageId/callback`)
6. Capacitor App plugin receives the deep link via `appUrlOpen` event
7. `handleRedirectCallback(url)` processes the authorization code
8. `Browser.close()` dismisses the system browser
9. User is now authenticated — `isAuthenticated` is `true`, `user` is populated

## Auth0 Plugin Setup

Configure the Auth0 Vue plugin at your app's entry point (`src/main.ts`):

```typescript
import { createApp } from 'vue';
import { createAuth0 } from '@auth0/auth0-vue';
import { IonicVue } from '@ionic/vue';
import App from './App.vue';
import router from './router';

const domain = "your-tenant.auth0.com";
const clientId = "your-client-id";
const packageId = "com.example.myapp";
const callbackUri = `${packageId}://${domain}/capacitor/${packageId}/callback`;

const app = createApp(App);

app.use(IonicVue);
app.use(router);
app.use(
  createAuth0({
    domain,
    clientId,
    useRefreshTokens: true,
    useRefreshTokensFallback: false,
    authorizationParams: {
      redirect_uri: callbackUri
    }
  })
);

router.isReady().then(() => {
  app.mount('#app');
});
```

### Why These Options Are Required for Capacitor

| Option | Value | Reason |
|--------|-------|--------|
| `useRefreshTokens` | `true` | Mobile apps cannot use iframe-based token renewal. Refresh tokens provide reliable session persistence. |
| `useRefreshTokensFallback` | `false` | Prevents the SDK from attempting iframe fallback, which fails on native. |
| `authorizationParams.redirect_uri` | Custom scheme URL | Native apps use a custom URL scheme, not `http://localhost`. |

## Login Implementation

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import { Browser } from '@capacitor/browser';
import { IonButton } from '@ionic/vue';

const { loginWithRedirect } = useAuth0();

const login = async () => {
  await loginWithRedirect({
    async openUrl(url: string) {
      await Browser.open({
        url,
        windowName: "_self"
      });
    }
  });
};
</script>

<template>
  <ion-button @click="login">Log in</ion-button>
</template>
```

## Deep Link Callback Handling

Handle the callback in your App.vue component. This must run on app initialization:

```vue
<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';
import { useAuth0 } from '@auth0/auth0-vue';
import { App as CapApp } from '@capacitor/app';
import { Browser } from '@capacitor/browser';
import { IonApp, IonRouterOutlet } from '@ionic/vue';

const { handleRedirectCallback } = useAuth0();

let urlOpenListener: any;

onMounted(async () => {
  urlOpenListener = await CapApp.addListener('appUrlOpen', async ({ url }) => {
    if (url.includes('state') && (url.includes('code') || url.includes('error'))) {
      await handleRedirectCallback(url);
    }
    await Browser.close();
  });
});

onUnmounted(() => {
  urlOpenListener?.remove();
});
</script>

<template>
  <ion-app>
    <ion-router-outlet />
  </ion-app>
</template>
```

## Logout Implementation

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import { Browser } from '@capacitor/browser';
import { IonButton } from '@ionic/vue';

const domain = "your-tenant.auth0.com";
const packageId = "com.example.myapp";
const logoutUri = `${packageId}://${domain}/capacitor/${packageId}/callback`;

const { logout } = useAuth0();

const doLogout = async () => {
  await logout({
    logoutParams: {
      returnTo: logoutUri
    },
    async openUrl(url: string) {
      await Browser.open({
        url,
        windowName: "_self"
      });
    }
  });
};
</script>

<template>
  <ion-button @click="doLogout">Log out</ion-button>
</template>
```

## User Profile Display

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import {
  IonCard,
  IonCardContent,
  IonCardHeader,
  IonCardTitle,
  IonAvatar,
  IonItem,
  IonLabel,
  IonSpinner
} from '@ionic/vue';

const { user, isLoading, isAuthenticated } = useAuth0();
</script>

<template>
  <ion-spinner v-if="isLoading" />

  <ion-card v-else-if="isAuthenticated && user">
    <ion-card-header>
      <ion-item lines="none">
        <ion-avatar slot="start">
          <img :src="user.picture" :alt="user.name" />
        </ion-avatar>
        <ion-label>
          <ion-card-title>{{ user.name }}</ion-card-title>
          <p>{{ user.email }}</p>
        </ion-label>
      </ion-item>
    </ion-card-header>
    <ion-card-content>
      <pre>{{ JSON.stringify(user, null, 2) }}</pre>
    </ion-card-content>
  </ion-card>
</template>
```

## Protected Routes

Use Vue Router navigation guards with `createAuthGuard` to protect Ionic pages:

```typescript
// src/router/index.ts
import { createRouter, createWebHistory } from '@ionic/vue-router';
import { createAuthGuard } from '@auth0/auth0-vue';
import type { App } from 'vue';

export function setupRouter(app: App) {
  const router = createRouter({
    history: createWebHistory(import.meta.env.BASE_URL),
    routes: [
      {
        path: '/',
        redirect: '/home'
      },
      {
        path: '/home',
        component: () => import('../views/HomePage.vue')
      },
      {
        path: '/profile',
        component: () => import('../views/ProfilePage.vue'),
        beforeEnter: createAuthGuard(app)
      }
    ]
  });

  return router;
}
```

### Alternative: Component-Level Guard

```vue
<script setup lang="ts">
import { watchEffect } from 'vue';
import { useAuth0 } from '@auth0/auth0-vue';
import { IonPage, IonContent, IonSpinner } from '@ionic/vue';

const { isAuthenticated, isLoading, loginWithRedirect } = useAuth0();
import { Browser } from '@capacitor/browser';

watchEffect(() => {
  if (!isLoading.value && !isAuthenticated.value) {
    loginWithRedirect({
      async openUrl(url: string) {
        await Browser.open({ url, windowName: "_self" });
      }
    });
  }
});
</script>

<template>
  <ion-page>
    <ion-content v-if="isLoading" class="ion-text-center ion-padding">
      <ion-spinner />
    </ion-content>
    <ion-content v-else-if="isAuthenticated">
      <h1>Protected Content</h1>
    </ion-content>
  </ion-page>
</template>
```

## Accessing API Tokens

```vue
<script setup lang="ts">
import { ref } from 'vue';
import { useAuth0 } from '@auth0/auth0-vue';

const { getAccessTokenSilently } = useAuth0();
const data = ref(null);
const error = ref<string | null>(null);
const loading = ref(false);

const callApi = async () => {
  loading.value = true;
  error.value = null;

  try {
    const token = await getAccessTokenSilently({
      authorizationParams: {
        audience: "https://api.example.com/",
        scope: "read:data",
      }
    });

    const response = await fetch("https://api.example.com/data", {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    data.value = await response.json();
  } catch (err: any) {
    error.value = err.message;
  } finally {
    loading.value = false;
  }
};
</script>

<template>
  <div>
    <ion-button @click="callApi" :disabled="loading">
      {{ loading ? 'Loading...' : 'Call API' }}
    </ion-button>
    <div v-if="error" class="error">{{ error }}</div>
    <pre v-if="data">{{ JSON.stringify(data, null, 2) }}</pre>
  </div>
</template>
```

To use API tokens, configure the `audience` in the Auth0 plugin:

```typescript
app.use(
  createAuth0({
    domain,
    clientId,
    useRefreshTokens: true,
    useRefreshTokensFallback: false,
    authorizationParams: {
      redirect_uri: callbackUri,
      audience: "https://api.example.com/",
    }
  })
);
```

## Conditional Login/Logout UI

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import { Browser } from '@capacitor/browser';
import { IonButton } from '@ionic/vue';

const { isAuthenticated, loginWithRedirect, logout } = useAuth0();

const domain = "your-tenant.auth0.com";
const packageId = "com.example.myapp";
const callbackUri = `${packageId}://${domain}/capacitor/${packageId}/callback`;

const login = async () => {
  await loginWithRedirect({
    async openUrl(url: string) {
      await Browser.open({ url, windowName: "_self" });
    }
  });
};

const doLogout = async () => {
  await logout({
    logoutParams: { returnTo: callbackUri },
    async openUrl(url: string) {
      await Browser.open({ url, windowName: "_self" });
    }
  });
};
</script>

<template>
  <ion-button v-if="isAuthenticated" @click="doLogout">Log out</ion-button>
  <ion-button v-else @click="login">Log in</ion-button>
</template>
```

## Organizations Support

```typescript
await loginWithRedirect({
  authorizationParams: {
    organization: "org_abc123",
  },
  async openUrl(url: string) {
    await Browser.open({ url, windowName: "_self" });
  }
});
```

To accept an organization invitation:

```typescript
await loginWithRedirect({
  authorizationParams: {
    organization: "org_abc123",
    invitation: "inv_xyz789",
  },
  async openUrl(url: string) {
    await Browser.open({ url, windowName: "_self" });
  }
});
```

## Error Handling

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import { IonSpinner, IonCard, IonCardContent } from '@ionic/vue';

const { error, isLoading } = useAuth0();
</script>

<template>
  <ion-spinner v-if="isLoading" />

  <ion-card v-else-if="error" color="danger">
    <ion-card-content>
      <h2>Authentication Error</h2>
      <p>{{ error.message }}</p>
    </ion-card-content>
  </ion-card>

  <slot v-else />
</template>
```

### Common Error Types

| Error | Cause | Resolution |
|-------|-------|------------|
| `login_required` | Session expired or not authenticated | Re-trigger `loginWithRedirect()` |
| `consent_required` | User hasn't consented to requested scopes | Re-trigger login with `prompt: 'consent'` |
| `invalid_grant` | Refresh token expired or revoked | Clear session and re-authenticate |
| `access_denied` | User denied consent or rule blocked access | Check Auth0 Actions/Rules for blocks |
| `mfa_required` | MFA is required for the user | Handle MFA enrollment flow |

## Testing Patterns

### Physical Device Testing

Always test authentication flows on a physical device. Simulators and emulators may not correctly handle deep link callbacks or system browser interactions. To test on a physical device:

```bash
ionic build
npx cap sync
npx cap open ios   # Build and run on device from Xcode
npx cap open android  # Build and run on device from Android Studio
```

### Manual Testing Flow

1. Run `ionic serve` for browser testing (limited — deep links won't work)
2. Build and deploy to a physical device:
   ```bash
   ionic build
   npx cap sync
   npx cap open ios   # or: npx cap open android
   ```
3. Build and run from Xcode/Android Studio on a physical device
4. Tap Login → should open system browser
5. Authenticate → should return to app with user data
6. Tap Logout → should clear session and redirect back
