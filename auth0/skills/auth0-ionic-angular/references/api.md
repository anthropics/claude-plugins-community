# auth0-ionic-angular — API Reference & Testing

## Configuration Options

### `provideAuth0()` / `AuthModule.forRoot()` Options

| Option | Type | Required | Default | Description |
|--------|------|----------|---------|-------------|
| `domain` | `string` | Yes | — | Auth0 tenant domain (e.g., `your-tenant.auth0.com`) |
| `clientId` | `string` | Yes | — | Auth0 application Client ID |
| `useRefreshTokens` | `boolean` | Yes (mobile) | `false` | Must be `true` for Ionic Capacitor apps |
| `useRefreshTokensFallback` | `boolean` | Yes (mobile) | `true` | Must be `false` for Ionic Capacitor apps |
| `cacheLocation` | `'memory' \| 'localstorage'` | No | `'memory'` | Where to store tokens — `'memory'` recommended for mobile |
| `authorizationParams.redirect_uri` | `string` | Yes (Capacitor) | `window.location.origin` | Must be set to custom URL scheme for Capacitor: `PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback` |
| `authorizationParams.audience` | `string` | No | — | API audience for access token scoping |
| `authorizationParams.scope` | `string` | No | `'openid profile email'` | OAuth scopes to request |
| `httpInterceptor.allowedList` | `string[] \| HttpInterceptorRouteConfig[]` | No | `[]` | API URLs to attach access tokens to |
| `errorPath` | `string` | No | — | Route to redirect to on authentication error |

### Capacitor Configuration (`capacitor.config.ts`)

```typescript
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.myapp',      // Used as URL scheme
  appName: 'My Ionic App',
  webDir: 'www',
  server: {
    androidScheme: 'https',
  },
};

export default config;
```

## AuthService API

### Properties (Observables)

| Property | Type | Description |
|----------|------|-------------|
| `isAuthenticated$` | `Observable<boolean>` | Emits `true` when user is authenticated |
| `isLoading$` | `Observable<boolean>` | Emits `true` while SDK is initializing |
| `user$` | `Observable<User \| null \| undefined>` | Emits user profile after authentication |
| `error$` | `Observable<Error \| undefined>` | Emits authentication errors |
| `idTokenClaims$` | `Observable<IdToken \| null \| undefined>` | Emits raw ID token claims |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `loginWithRedirect(options?)` | `Observable<void>` | Redirect to Auth0 Universal Login. Pass `openUrl` for Capacitor. |
| `logout(options?)` | `Observable<void>` | Log out and redirect. Pass `openUrl` and `logoutParams.returnTo` for Capacitor. |
| `handleRedirectCallback(url?)` | `Observable<RedirectLoginResult>` | Process callback URL from deep link. Call inside `ngZone.run()`. |
| `getAccessTokenSilently(options?)` | `Observable<string>` | Get access token using refresh token (no iframe on mobile). |
| `getAccessTokenWithPopup(options?)` | `Observable<string>` | Not supported on mobile — use `getAccessTokenSilently()`. |

### `loginWithRedirect` Options (Capacitor)

```typescript
// callbackUri = `${appId}://${domain}/capacitor/${appId}/callback`
this.auth.loginWithRedirect({
  authorizationParams: {
    audience: 'https://my-api.example.com',
    scope: 'openid profile email read:data',
    redirect_uri: callbackUri,
  },
  async openUrl(url: string) {
    await Browser.open({ url, windowName: '_self' });
  },
}).subscribe();
```

### `logout` Options (Capacitor)

```typescript
// callbackUri = `${appId}://${domain}/capacitor/${appId}/callback`
this.auth.logout({
  logoutParams: {
    returnTo: callbackUri,
  },
  async openUrl(url: string) {
    await Browser.open({ url, windowName: '_self' });
  },
}).subscribe();
```

## Claims Reference

### Standard OIDC Claims (`user$`)

| Claim | Type | Description |
|-------|------|-------------|
| `sub` | `string` | Unique user identifier (e.g., `auth0\|abc123`) |
| `name` | `string` | Full name |
| `given_name` | `string` | First name |
| `family_name` | `string` | Last name |
| `nickname` | `string` | Casual name |
| `picture` | `string` | Profile picture URL |
| `email` | `string` | Email address |
| `email_verified` | `boolean` | Whether email is verified |
| `locale` | `string` | User locale |
| `updated_at` | `string` | Last profile update timestamp |

### Auth0-Specific Claims

| Claim | Type | Source | Description |
|-------|------|--------|-------------|
| `org_id` | `string` | Organizations | Organization identifier |
| `permissions` | `string[]` | RBAC | Granted permissions (requires API audience + RBAC enabled) |

## HTTP Interceptor for API Calls

Attach access tokens to outgoing API requests automatically:

```typescript
provideAuth0({
  domain: 'YOUR_AUTH0_DOMAIN',
  clientId: 'YOUR_AUTH0_CLIENT_ID',
  useRefreshTokens: true,
  useRefreshTokensFallback: false,
  authorizationParams: {
    audience: 'https://my-api.example.com',
  },
  httpInterceptor: {
    allowedList: [
      'https://my-api.example.com/*',
      {
        uri: 'https://my-api.example.com/admin/*',
        tokenOptions: {
          authorizationParams: {
            scope: 'admin:access',
          },
        },
      },
    ],
  },
}),
provideHttpClient(withInterceptors([authHttpInterceptorFn])),
```

## Complete Minimal Example

### `src/app/app.config.ts`
```typescript
import { ApplicationConfig } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideAuth0, authHttpInterceptorFn } from '@auth0/auth0-angular';
import { routes } from './app.routes';

const appId = 'YOUR_PACKAGE_ID';
const domain = 'YOUR_AUTH0_DOMAIN';
const callbackUri = `${appId}://${domain}/capacitor/${appId}/callback`;

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideHttpClient(withInterceptors([authHttpInterceptorFn])),
    provideAuth0({
      domain,
      clientId: 'YOUR_AUTH0_CLIENT_ID',
      useRefreshTokens: true,
      useRefreshTokensFallback: false,
      authorizationParams: {
        redirect_uri: callbackUri,
      },
    }),
  ],
};
```

### `src/app/app.component.ts`
```typescript
import { Component, NgZone, OnInit } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { Browser } from '@capacitor/browser';
import { App as CapApp } from '@capacitor/app';
import { IonApp, IonRouterOutlet } from '@ionic/angular/standalone';
import { mergeMap } from 'rxjs/operators';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [IonApp, IonRouterOutlet],
  template: `
    <ion-app>
      <ion-router-outlet></ion-router-outlet>
    </ion-app>
  `,
})
export class AppComponent implements OnInit {
  constructor(
    private auth: AuthService,
    private ngZone: NgZone
  ) {}

  ngOnInit() {
    CapApp.addListener('appUrlOpen', ({ url }) => {
      this.ngZone.run(() => {
        if (url.includes('state') && (url.includes('code') || url.includes('error'))) {
          this.auth
            .handleRedirectCallback(url)
            .pipe(mergeMap(() => Browser.close()))
            .subscribe();
        }
      });
    });
  }
}
```

## Testing Checklist

- [ ] App opens Auth0 Universal Login in system browser (not in-app WebView)
- [ ] After login, system browser closes and app receives user profile
- [ ] `auth.isAuthenticated$` emits `true` after successful login
- [ ] `auth.user$` contains name, email, and picture
- [ ] Logout opens system browser, clears session, and returns to app
- [ ] After logout, `auth.isAuthenticated$` emits `false`
- [ ] Token refresh works silently (no login prompt on app restart if session valid)
- [ ] Deep link callback URL matches Auth0 Dashboard configuration exactly
- [ ] App works on both iOS (SFSafariViewController) and Android (Chrome Custom Tabs)
- [ ] `ngZone.run()` wraps all callback handling (UI updates correctly)
- [ ] Build succeeds: `npm run build && npx cap sync`

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Login opens but never returns to app | Callback URL mismatch | Ensure `PACKAGE_ID://{domain}/capacitor/PACKAGE_ID/callback` is in Auth0 Dashboard |
| UI doesn't update after login | Missing `ngZone.run()` | Wrap `handleRedirectCallback` in `this.ngZone.run()` |
| `getAccessTokenSilently` fails | `useRefreshTokens` not `true` | Set `useRefreshTokens: true` and `useRefreshTokensFallback: false` |
| "Callback URL mismatch" error | Wrong app type in Auth0 | Change application type to **Native** (not SPA) |
| White screen after login on Android | `androidScheme` not set | Add `server: { androidScheme: 'https' }` to `capacitor.config.ts` |
| Token lost on app restart | Cache location issue | Ensure `useRefreshTokens: true` for persistent sessions |
| `Browser.open` not available | Missing Capacitor plugin | Run `npm install @capacitor/browser && npx cap sync` |

## Security Considerations

- **Never store tokens in localStorage** on mobile — use `useRefreshTokens: true` with in-memory cache
- **Never embed Client Secret** in mobile apps — Native apps use PKCE (no secret needed)
- **Always validate the callback URL** contains `state` and `code`/`error` before calling `handleRedirectCallback`
- **Use HTTPS** for any API calls made with access tokens
- **Set `useRefreshTokensFallback: false`** to prevent iframe-based token refresh attempts on mobile
