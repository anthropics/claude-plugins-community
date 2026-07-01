# Auth0 Ionic Vue (Capacitor) — API Reference & Testing

## createAuth0 Configuration

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `domain` | `string` | Yes | — | Auth0 tenant domain (e.g., `your-tenant.auth0.com`) |
| `clientId` | `string` | Yes | — | Auth0 application Client ID |
| `useRefreshTokens` | `boolean` | Yes (for Capacitor) | `false` | Must be `true` for native mobile — uses refresh tokens instead of iframe |
| `useRefreshTokensFallback` | `boolean` | Yes (for Capacitor) | `true` | Must be `false` for native mobile — disables iframe fallback |
| `authorizationParams.redirect_uri` | `string` | Yes | — | Custom scheme callback URL: `{packageId}://{domain}/capacitor/{packageId}/callback` |
| `authorizationParams.audience` | `string` | No | — | API identifier for access token audience |
| `authorizationParams.scope` | `string` | No | `openid profile email` | OAuth scopes to request |
| `cacheLocation` | `string` | No | `memory` | Token cache location: `memory` or `localstorage` |

### Capacitor-Specific Configuration

```typescript
app.use(
  createAuth0({
    domain: "your-tenant.auth0.com",
    clientId: "your-client-id",
    useRefreshTokens: true,
    useRefreshTokensFallback: false,
    authorizationParams: {
      redirect_uri: "com.example.myapp://your-tenant.auth0.com/capacitor/com.example.myapp/callback"
    }
  })
);
```

## useAuth0() Composable

```typescript
const {
  isLoading,              // Ref<boolean> — true while SDK initializes
  isAuthenticated,        // Ref<boolean> — true if user has valid session
  user,                   // Ref<User | undefined> — authenticated user profile
  error,                  // Ref<Error | undefined> — last authentication error
  loginWithRedirect,      // (options?) => Promise<void>
  logout,                 // (options?) => Promise<void>
  getAccessTokenSilently, // (options?) => Promise<string>
  getAccessTokenWithPopup, // (options?) => Promise<string> (not for Capacitor)
  handleRedirectCallback, // (url?) => Promise<RedirectLoginResult>
  idTokenClaims,          // Ref<IdToken | undefined> — raw ID token claims
  checkSession,           // () => Promise<void> — refresh authentication state
} = useAuth0();
```

**Note:** All reactive properties (`isLoading`, `isAuthenticated`, `user`, `error`, `idTokenClaims`) are Vue `Ref` objects. Access their values with `.value` in `<script>` blocks; templates unwrap refs automatically.

## loginWithRedirect Options (Capacitor)

```typescript
await loginWithRedirect({
  // Required for Capacitor: opens URL in system browser
  async openUrl(url: string) {
    await Browser.open({ url, windowName: "_self" });
  },
  // Optional: additional authorization params
  authorizationParams: {
    audience: "https://api.example.com/",
    scope: "openid profile email read:data",
    organization: "org_abc123",
    invitation: "inv_xyz789",
  }
});
```

## logout Options (Capacitor)

```typescript
await logout({
  logoutParams: {
    returnTo: "com.example.myapp://your-tenant.auth0.com/capacitor/com.example.myapp/callback"
  },
  async openUrl(url: string) {
    await Browser.open({ url, windowName: "_self" });
  }
});
```

## getAccessTokenSilently Options

```typescript
const token = await getAccessTokenSilently({
  authorizationParams: {
    audience: "https://api.example.com/",
    scope: "read:data",
  }
});

// Use token in API calls
const response = await fetch("https://api.example.com/data", {
  headers: { Authorization: `Bearer ${token}` }
});
```

## createAuthGuard

Factory function that creates a Vue Router navigation guard for protected routes:

```typescript
import { createAuthGuard } from '@auth0/auth0-vue';
import type { App } from 'vue';

// In router setup (needs app instance)
export function setupRouter(app: App) {
  const router = createRouter({
    history: createWebHistory(),
    routes: [
      {
        path: '/profile',
        component: () => import('../views/Profile.vue'),
        beforeEnter: createAuthGuard(app)
      }
    ]
  });
  return router;
}
```

## Claims Reference

| Claim | Source | Description |
|-------|--------|-------------|
| `sub` | ID Token | User identifier (e.g., `auth0\|abc123`) |
| `name` | ID Token | User's full name |
| `email` | ID Token | User's email address |
| `email_verified` | ID Token | Whether email has been verified |
| `picture` | ID Token | URL to user's profile picture |
| `nickname` | ID Token | User's nickname |
| `updated_at` | ID Token | Last profile update timestamp |
| `org_id` | ID Token | Organization ID (when using Organizations) |
| `permissions` | Access Token | RBAC permissions array (when API has RBAC enabled) |

## Capacitor Plugin Configuration

### capacitor.config.ts

```typescript
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.myapp',
  appName: 'My App',
  webDir: 'dist',  // Ionic Vue with Vite uses 'dist'
  server: {
    androidScheme: 'https'
  }
};

export default config;
```

### iOS: URL Scheme Registration

Add a custom URL scheme to `ios/App/App/Info.plist` so iOS can route the Auth0 callback deep link back to the app:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_PACKAGE_ID</string>
    </array>
  </dict>
</array>
```

Replace `YOUR_PACKAGE_ID` with the `appId` from `capacitor.config.ts` (e.g., `com.example.myapp`).

### Android: URL Scheme Registration

Add an intent filter to `android/app/src/main/AndroidManifest.xml` inside the main `<activity>` to handle the custom scheme callback:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="YOUR_PACKAGE_ID" />
</intent-filter>
```

Replace `YOUR_PACKAGE_ID` with the `appId` from `capacitor.config.ts`. Ensure the `appId` matches the `applicationId` in `android/app/build.gradle`.

## Auth0 Dashboard Configuration

### Callback URLs

```text
YOUR_PACKAGE_ID://YOUR_DOMAIN/capacitor/YOUR_PACKAGE_ID/callback
```

Example: `com.example.myapp://your-tenant.auth0.com/capacitor/com.example.myapp/callback`

### Logout URLs

Same as callback URL:
```text
YOUR_PACKAGE_ID://YOUR_DOMAIN/capacitor/YOUR_PACKAGE_ID/callback
```

### Allowed Origins

```text
capacitor://localhost, http://localhost
```

## Testing Checklist

- [ ] Auth0 plugin registered with `app.use(createAuth0({...}))` with correct domain and clientId
- [ ] `useRefreshTokens: true` and `useRefreshTokensFallback: false` are set
- [ ] `redirect_uri` uses custom scheme format (`packageId://domain/capacitor/packageId/callback`)
- [ ] Login opens system browser (SFSafariViewController on iOS, Chrome Custom Tabs on Android)
- [ ] Deep link callback is handled via `CapApp.addListener('appUrlOpen', ...)`
- [ ] `handleRedirectCallback(url)` is called when URL contains `state` and `code`/`error`
- [ ] `Browser.close()` is called after handling callback
- [ ] Logout redirects back to app via custom scheme
- [ ] `getAccessTokenSilently()` works with refresh tokens
- [ ] User profile data is accessible via `useAuth0().user`
- [ ] `npx cap sync` has been run after installing Capacitor plugins
- [ ] Auth0 Dashboard has correct Callback URLs, Logout URLs, and Allowed Origins
- [ ] Application type is set to "Native" in Auth0 Dashboard
- [ ] Vue refs are accessed with `.value` in script, template unwraps automatically

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Login opens but never returns to app | Callback URL mismatch or missing deep link handler | Verify callback URL in Dashboard matches `redirect_uri`; ensure `appUrlOpen` listener is registered |
| `handleRedirectCallback` not called | Deep link listener not set up or URL check is wrong | Verify `CapApp.addListener('appUrlOpen', ...)` runs in `onMounted` |
| Token refresh fails silently | `useRefreshTokens` not enabled | Set `useRefreshTokens: true` in `createAuth0()` |
| iframe fallback error on mobile | `useRefreshTokensFallback` not disabled | Set `useRefreshTokensFallback: false` in `createAuth0()` |
| `Browser.open` does nothing | `@capacitor/browser` not installed or synced | Run `npm install @capacitor/browser && npx cap sync` |
| App crashes on deep link | Missing `@capacitor/app` plugin | Run `npm install @capacitor/app && npx cap sync` |
| CORS error during token exchange | Missing Allowed Origins in Auth0 Dashboard | Add `capacitor://localhost, http://localhost` to Allowed Origins |
| `user` is `undefined` after login | Callback not processed before reading user | Wait for `isLoading.value === false` before accessing `user.value` |
| SSO not working on iOS | SFSafariViewController doesn't share Safari cookies (iOS 11+) | Expected limitation — SSO across apps is not supported on iOS |
| Auth plugin not found | `createAuth0()` not registered before mount | Call `app.use(createAuth0({...}))` before `app.mount('#app')` |
| Composable returns undefined | `useAuth0()` called outside setup or before plugin registration | Ensure `useAuth0()` is called inside `<script setup>` or `setup()` of a component |

## Security Considerations

- **No client secret**: Native applications must not include a client secret. Use PKCE (Auth Code + PKCE) flow, which is the default.
- **Refresh tokens**: Always enable `useRefreshTokens: true` for Capacitor apps. localStorage is transient on mobile.
- **Token storage**: The SDK stores tokens in memory by default. On mobile, refresh tokens are the reliable mechanism for session persistence.
- **Custom scheme validation**: The callback URL scheme must match the app's package/bundle ID exactly.
- **HTTPS**: Capacitor uses HTTPS for Android by default (`androidScheme: 'https'` in config). Do not change this.
