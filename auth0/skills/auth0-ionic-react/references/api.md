# Auth0 Ionic React (Capacitor) — API Reference & Testing

## Auth0Provider Configuration

| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `domain` | `string` | Yes | — | Auth0 tenant domain (e.g., `your-tenant.auth0.com`) |
| `clientId` | `string` | Yes | — | Auth0 application Client ID |
| `useRefreshTokens` | `boolean` | Yes (for Capacitor) | `false` | Must be `true` for native mobile — uses refresh tokens instead of iframe |
| `useRefreshTokensFallback` | `boolean` | Yes (for Capacitor) | `true` | Must be `false` for native mobile — disables iframe fallback |
| `authorizationParams.redirect_uri` | `string` | Yes | — | Custom scheme callback URL: `{packageId}://{domain}/capacitor/{packageId}/callback` |
| `authorizationParams.audience` | `string` | No | — | API identifier for access token audience |
| `authorizationParams.scope` | `string` | No | `openid profile email` | OAuth scopes to request |
| `cacheLocation` | `string` | No | `memory` | Token cache location: `memory` or `localstorage` |

### Capacitor-Specific Configuration

```tsx
<Auth0Provider
  domain="your-tenant.auth0.com"
  clientId="your-client-id"
  useRefreshTokens={true}
  useRefreshTokensFallback={false}
  authorizationParams={{
    redirect_uri: "com.example.myapp://your-tenant.auth0.com/capacitor/com.example.myapp/callback"
  }}
>
  <App />
</Auth0Provider>
```

## useAuth0() Hook

```tsx
const {
  isLoading,          // boolean — true while SDK initializes
  isAuthenticated,    // boolean — true if user has valid session
  user,               // User | undefined — authenticated user profile
  error,              // Error | undefined — last authentication error
  loginWithRedirect,  // (options?) => Promise<void>
  logout,             // (options?) => Promise<void>
  getAccessTokenSilently, // (options?) => Promise<string>
  getAccessTokenWithPopup, // (options?) => Promise<string> (not for Capacitor)
  handleRedirectCallback,  // (url?) => Promise<RedirectLoginResult>
} = useAuth0();
```

## loginWithRedirect Options (Capacitor)

```tsx
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

```tsx
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

```tsx
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

## Claims Reference

| Claim | Source | Description |
|-------|--------|-------------|
| `sub` | ID Token | User identifier (e.g., `auth0|abc123`) |
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
  webDir: 'dist',  // or 'build' for CRA
  server: {
    androidScheme: 'https'
  }
};

export default config;
```

### iOS: URL Scheme Registration

No additional URL scheme registration needed for Capacitor — the deep link uses the app's bundle ID as the scheme, which Capacitor handles automatically.

### Android: URL Scheme Registration

Capacitor handles deep link registration automatically via the `appId` in `capacitor.config.ts`. Ensure the `appId` matches the `applicationId` in `android/app/build.gradle`.

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

- [ ] Auth0Provider wraps root component with correct domain and clientId
- [ ] `useRefreshTokens={true}` and `useRefreshTokensFallback={false}` are set
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

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Login opens but never returns to app | Callback URL mismatch or missing deep link handler | Verify callback URL in Dashboard matches `redirect_uri`; ensure `appUrlOpen` listener is registered |
| `handleRedirectCallback` not called | Deep link listener not set up or URL check is wrong | Verify `CapApp.addListener('appUrlOpen', ...)` runs on app mount |
| Token refresh fails silently | `useRefreshTokens` not enabled | Set `useRefreshTokens={true}` on Auth0Provider |
| iframe fallback error on mobile | `useRefreshTokensFallback` not disabled | Set `useRefreshTokensFallback={false}` on Auth0Provider |
| `Browser.open` does nothing | `@capacitor/browser` not installed or synced | Run `npm install @capacitor/browser && npx cap sync` |
| App crashes on deep link | Missing `@capacitor/app` plugin | Run `npm install @capacitor/app && npx cap sync` |
| CORS error during token exchange | Missing Allowed Origins in Auth0 Dashboard | Add `capacitor://localhost, http://localhost` to Allowed Origins |
| `user` is `undefined` after login | Callback not processed before reading user | Wait for `isLoading === false` before accessing `user` |
| SSO not working on iOS | SFSafariViewController doesn't share Safari cookies (iOS 11+) | Expected limitation — SSO across apps is not supported on iOS |

## Security Considerations

- **No client secret**: Native applications must not include a client secret. Use PKCE (Auth Code + PKCE) flow, which is the default.
- **Refresh tokens**: Always enable `useRefreshTokens={true}` for Capacitor apps. localStorage is transient on mobile.
- **Token storage**: The SDK stores tokens in memory by default. On mobile, refresh tokens are the reliable mechanism for session persistence.
- **Custom scheme validation**: The callback URL scheme must match the app's package/bundle ID exactly.
- **HTTPS**: Capacitor uses HTTPS for Android by default (`androidScheme: 'https'` in config). Do not change this.
