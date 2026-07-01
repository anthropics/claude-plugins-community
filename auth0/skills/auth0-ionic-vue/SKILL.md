---
name: auth0-ionic-vue
description: >
  Use when adding Auth0 login, logout, or deep linking to an Ionic Vue app with Capacitor. Integrates @auth0/auth0-vue with Capacitor Browser and App plugins for native iOS/Android.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
    requires:
      bins:
        - gh
        - node
---

# Auth0 Ionic Vue (Capacitor) Integration

Add Auth0 authentication to Ionic Vue applications using Capacitor. This skill covers native mobile authentication using the `@auth0/auth0-vue` SDK combined with `@capacitor/browser` and `@capacitor/app` plugins for deep link handling on iOS and Android.

## Prerequisites

- Node.js 18+
- Ionic CLI (`npm install -g @ionic/cli`)
- An existing Ionic Vue application with Capacitor configured
- Auth0 account and tenant
- For iOS: Xcode 14+ and CocoaPods
- For Android: Android Studio with API level 21+
- Auth0 CLI — `brew install auth0/auth0-cli/auth0`

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| Vue SPA (no Capacitor/Ionic) | `auth0-vue` |
| React SPA (no Capacitor/Ionic) | `auth0-react` |
| React Native (bare CLI) | `auth0-react-native` |
| Expo (React Native) | `auth0-expo` |
| Ionic + React + Capacitor | `auth0-ionic-react` |
| Ionic + Angular + Capacitor | `auth0-ionic-angular` |
| Next.js (server-side) | `auth0-nextjs` |
| Nuxt (server-side) | `auth0-nuxt` |
| iOS native (Swift) | `auth0-swift` |
| Android native (Kotlin) | `auth0-android` |

## Quick Start Workflow

### Step 1: Configure Auth0

**For automated setup with Auth0 CLI**, see [Setup Guide](./references/setup.md) for complete scripts.

**For manual setup**, configure a **Native** application in the [Auth0 Dashboard](https://manage.auth0.com/) and note your Domain and Client ID.

### Step 2: Install Dependencies

```bash
npm install @auth0/auth0-vue @capacitor/browser @capacitor/app
npx cap sync
```

### Step 3: Set Up Auth0 Plugin

> **Agent instruction:** If Step 1 already wrote `.env` and updated `src/main.ts`, verify the configuration looks correct and skip to Step 4. Only use the template below if configuring manually.

Register the Auth0 Vue plugin in your app entry point (`src/main.ts`), configuring it for Capacitor. Credentials are read from `.env` via `import.meta.env`:

```typescript
import { createApp } from 'vue';
import { createAuth0 } from '@auth0/auth0-vue';
import { IonicVue } from '@ionic/vue';
import App from './App.vue';
import router from './router';

// Agent: read appId from capacitor.config.ts and replace this value
const packageId = "YOUR_PACKAGE_ID";

const app = createApp(App);

app.use(IonicVue);
app.use(router);
app.use(
  createAuth0({
    domain: import.meta.env.VITE_AUTH0_DOMAIN,
    clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
    useRefreshTokens: true,
    useRefreshTokensFallback: false,
    authorizationParams: {
      redirect_uri: `${packageId}://${import.meta.env.VITE_AUTH0_DOMAIN}/capacitor/${packageId}/callback`
    }
  })
);

router.isReady().then(() => {
  app.mount('#app');
});
```

### Step 4: Implement Login with Capacitor Browser

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import { Browser } from '@capacitor/browser';
import { IonButton } from '@ionic/vue';

const { loginWithRedirect } = useAuth0();

const login = async () => {
  await loginWithRedirect({
    async openUrl(url: string) {
      await Browser.open({ url, windowName: "_self" });
    }
  });
};
</script>

<template>
  <ion-button @click="login">Log in</ion-button>
</template>
```

### Step 5: Handle Callback via Deep Link

Handle the deep link callback in your App.vue component. This must run on app initialization:

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

### Step 6: Implement Logout

```vue
<script setup lang="ts">
import { useAuth0 } from '@auth0/auth0-vue';
import { Browser } from '@capacitor/browser';
import { IonButton } from '@ionic/vue';

const domain = import.meta.env.VITE_AUTH0_DOMAIN;
// Agent: read appId from capacitor.config.ts and replace this value
const packageId = "YOUR_PACKAGE_ID";
const logoutUri = `${packageId}://${domain}/capacitor/${packageId}/callback`;

const { logout } = useAuth0();

const doLogout = async () => {
  await logout({
    logoutParams: {
      returnTo: logoutUri
    },
    async openUrl(url: string) {
      await Browser.open({ url, windowName: "_self" });
    }
  });
};
</script>

<template>
  <ion-button @click="doLogout">Log out</ion-button>
</template>
```

### Step 7: Build and Test

> **Agent instruction:** After integration, verify the build:
> ```bash
> ionic build
> npx cap sync
> ```
> For iOS: `npx cap open ios` then build in Xcode.
> For Android: `npx cap open android` then build in Android Studio.
> If the build fails, iterate up to 5-6 times to fix issues. If still failing, use `AskUserQuestion` to request help.

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 CLI automated setup (login, app creation, credential injection), Capacitor URL scheme registration, secret management
- **[Integration Patterns](./references/integration.md)** — Login/logout with Capacitor Browser, deep link callback handling, user profile, protected routes, token access, error handling
- **[Testing & Reference](./references/api.md)** — Full API reference for createAuth0 options, useAuth0 composable, Capacitor plugin configuration, testing checklist, common issues

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| App type not set to **Native** in Auth0 Dashboard | Change application type to "Native" in Dashboard settings |
| Missing or incorrect callback URL format | Use `YOUR_PACKAGE_ID://YOUR_DOMAIN/capacitor/YOUR_PACKAGE_ID/callback` — must match exactly |
| Not enabling refresh tokens | Set `useRefreshTokens: true` and `useRefreshTokensFallback: false` in `createAuth0()` |
| Missing `@capacitor/browser` or `@capacitor/app` | Install both: `npm install @capacitor/browser @capacitor/app && npx cap sync` |
| Not handling deep link callback | Add `CapApp.addListener('appUrlOpen', ...)` to process Auth0 redirect |
| Forgetting `npx cap sync` after install | Always run `npx cap sync` after installing Capacitor plugins |
| Using `window.location.origin` as redirect URI | Use the custom URL scheme (`packageId://domain/...`), not `http://localhost` |
| Missing Allowed Origins in Dashboard | Add `capacitor://localhost, http://localhost` to Allowed Origins |
| Not calling `app.use(createAuth0(...))` before mount | Register Auth0 plugin before calling `app.mount('#app')` |
| Accessing `.value` incorrectly on auth refs | `useAuth0()` returns Vue refs — use `.value` in `<script>`, template unwraps automatically |
| localStorage treated as persistent on mobile | Use refresh tokens (`useRefreshTokens: true`) for reliable token persistence |

## WebAuth Method

This SDK uses Auth0's Universal Login (WebAuth) via the Capacitor Browser plugin. The `loginWithRedirect()` method opens the Auth0 authorization endpoint in a system browser (SFSafariViewController on iOS, Chrome Custom Tabs on Android). After authentication, Auth0 redirects back to the app using a native callback URL with a custom scheme: `{packageId}://{domain}/capacitor/{packageId}/callback`. The `@capacitor/app` plugin captures this deep link, and `handleRedirectCallback(url)` processes the authorization code exchange.

Unlike standard native SDKs that use `https://{domain}/android/{packageId}/callback` or `https://{domain}/ios/{bundleId}/callback`, Ionic Capacitor apps use the Capacitor-specific callback path with the package ID as the URL scheme.

## Related Skills

- **auth0-vue** — Vue SPA (browser-only, no Capacitor)
- **auth0-ionic-react** — Ionic with React and Capacitor
- **auth0-ionic-angular** — Ionic with Angular and Capacitor
- **auth0-react-native** — React Native (bare CLI, no Ionic/Capacitor)
- **auth0-expo** — Expo (React Native) with Auth0

## Quick Reference

| API | Description |
|-----|-------------|
| `createAuth0(options)` | Vue plugin factory — registers Auth0 with `app.use()` |
| `useAuth0()` | Composable — returns `{ isLoading, isAuthenticated, user, loginWithRedirect, logout, getAccessTokenSilently, handleRedirectCallback, error }` |
| `loginWithRedirect({ openUrl })` | Login via Universal Login — use `Browser.open()` in `openUrl` callback |
| `logout({ logoutParams, openUrl })` | Logout — use `Browser.open()` in `openUrl` callback |
| `handleRedirectCallback(url)` | Process Auth0 callback URL from deep link |
| `getAccessTokenSilently()` | Get access token (uses refresh tokens on mobile) |
| `createAuthGuard(app)` | Vue Router navigation guard factory for protected routes |
| `Browser.open({ url })` | Capacitor — opens URL in system browser (SFSafariViewController / Chrome Custom Tabs) |
| `CapApp.addListener('appUrlOpen', cb)` | Capacitor — listens for deep link events |
| `Browser.close()` | Capacitor — closes the in-app browser after callback |

## References

- [Auth0 Ionic Vue Quickstart](https://auth0.com/docs/quickstart/native/ionic-vue/interactive)
- [Auth0 Vue SDK GitHub](https://github.com/auth0/auth0-vue)
- [Auth0 Vue SDK API Reference](https://auth0.github.io/auth0-vue/)
- [Ionic Vue Capacitor Sample App](https://github.com/auth0-samples/auth0-ionic-samples/tree/main/vue)
- [Capacitor Browser Plugin](https://capacitorjs.com/docs/apis/browser)
- [Capacitor App Plugin](https://capacitorjs.com/docs/apis/app)
- [Auth0 Dashboard](https://manage.auth0.com/)
