---
name: auth0-ionic-angular
description: >
  Use when adding Auth0 login, logout, or deep linking to an Ionic Angular app with Capacitor. Integrates @auth0/auth0-angular with Capacitor Browser and App plugins for native iOS/Android.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Ionic Angular (Capacitor) Integration

Add authentication to an Ionic Angular application using the `@auth0/auth0-angular` SDK with Capacitor plugins for native iOS and Android. This skill covers login, logout, user profile display, and secure token management using the system browser (SFSafariViewController on iOS, Chrome Custom Tabs on Android) via Capacitor's Browser plugin.

## Prerequisites

- Node.js 20+ and npm 10+
- Ionic CLI (`npm install -g @ionic/cli`)
- Capacitor 5+ configured in the project
- Auth0 CLI (for automatic setup): `brew install auth0/auth0-cli/auth0`
- An Auth0 account (free tier works)

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| Ionic **React** app with Capacitor | `auth0-ionic-react` |
| Ionic **Vue** app with Capacitor | `auth0-ionic-vue` |
| Angular SPA (browser-only, no Capacitor) | `auth0-angular` or `auth0-react` |
| React Native (no Ionic) | `auth0-react-native` |
| Expo (React Native) | `auth0-expo` |
| Native iOS (Swift) | `auth0-swift` |
| Native Android (Kotlin) | `auth0-android` |

## Quick Start Workflow

> **Agent instruction:** Follow these steps in order. **Always** use `AskUserQuestion` to let the developer choose between Automatic Setup and Manual Setup before proceeding — even if credentials are already provided in the prompt.
>
> **SECURITY — Never display credentials:** After obtaining Auth0 credentials (domain, client ID) via the CLI or from a file, NEVER print, echo, or display them in your text output. Write them directly to the config file (`src/environments/environment.ts`) silently. Do NOT produce output like "Domain: xxx" or "Client ID: yyy". Instead, confirm that the config file has been written and tell the user where to find it.
>
> **UI reuse:** Before creating new login/logout components, search the existing project for login/logout handlers or buttons. If found, hook Auth0 into the existing UI rather than creating duplicate components.

### Step 1: Install Dependencies

```bash
npm install @auth0/auth0-angular @capacitor/browser @capacitor/app
```

### Step 2: Configure Auth0

> **Agent instruction:** **Always** present the setup choice using `AskUserQuestion` — even if the user has already provided credentials:
>
> ```
> AskUserQuestion:
>   question: "How would you like to configure Auth0 for your Ionic Angular app?"
>   options:
>     - label: "Automatic Setup (Recommended)"
>       description: "Uses the Auth0 CLI to create a Native application, configure callback URLs, and store credentials in your project automatically."
>     - label: "Manual Setup"
>       description: "You provide an .env file with your Auth0 Domain and Client ID, and the agent reads it and writes the project configuration for you."
> ```
>
> Follow the chosen path in the [Setup Guide](./references/setup.md) which has the full step-by-step instructions for both options.

**Auth0 Dashboard settings (Native application type):**

| Setting | Value |
|---------|-------|
| Application Type | **Native** |
| Allowed Callback URLs | `PACKAGE_ID://YOUR_DOMAIN/capacitor/PACKAGE_ID/callback` |
| Allowed Logout URLs | `PACKAGE_ID://YOUR_DOMAIN/capacitor/PACKAGE_ID/callback` |
| Allowed Origins | `capacitor://localhost, http://localhost` |

Replace `PACKAGE_ID` with your `appId` from `capacitor.config.ts` (e.g., `com.example.myapp`) and `YOUR_DOMAIN` with your Auth0 domain.

> **Note:** For Automatic Setup, these URLs are configured automatically by the Auth0 CLI. For Manual Setup, the user must configure them in the Auth0 Dashboard.

> **Note:** For local web development (`ionic serve`), also add `http://localhost:8100` to Allowed Callback URLs, Allowed Logout URLs, and Allowed Web Origins.

### Step 3: Configure the SDK

In `src/app/app.module.ts` (NgModule) or `src/app/app.config.ts` (standalone):

The `provideAuth0()` function (or `AuthModule.forRoot()`) is the Angular equivalent of `Auth0Provider` — it acts as the **provider/wrapper** that wraps the app and makes `AuthService` available everywhere. For local web development with `ionic serve`, the callback URL is `http://localhost:8100`.

**Standalone (Angular 17+):**
```typescript
import { ApplicationConfig } from '@angular/core';
import { provideAuth0 } from '@auth0/auth0-angular';

// Replace with your capacitor.config.ts appId and Auth0 domain
const appId = 'com.example.myapp';
const domain = 'YOUR_AUTH0_DOMAIN';
const callbackUri = `${appId}://${domain}/capacitor/${appId}/callback`;

export const appConfig: ApplicationConfig = {
  providers: [
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

**NgModule (Angular 16 and earlier):**
```typescript
import { AuthModule } from '@auth0/auth0-angular';

const appId = 'com.example.myapp';
const domain = 'YOUR_AUTH0_DOMAIN';
const callbackUri = `${appId}://${domain}/capacitor/${appId}/callback`;

@NgModule({
  imports: [
    AuthModule.forRoot({
      domain,
      clientId: 'YOUR_AUTH0_CLIENT_ID',
      useRefreshTokens: true,
      useRefreshTokensFallback: false,
      authorizationParams: {
        redirect_uri: callbackUri,
      },
    }),
  ],
})
export class AppModule {}
```

### Step 4: Handle Deep Link Callbacks (AppComponent)

Register the `appUrlOpen` listener at the app root so it persists across navigation:

```typescript
import { Component, NgZone, OnInit } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { Browser } from '@capacitor/browser';
import { App as CapApp } from '@capacitor/app';
import { mergeMap } from 'rxjs/operators';

@Component({
  selector: 'app-root',
  template: `<ion-app><ion-router-outlet></ion-router-outlet></ion-app>`,
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

### Step 5: Implement Login

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { Browser } from '@capacitor/browser';

@Component({
  selector: 'app-login',
  template: `<ion-button (click)="login()">Log In</ion-button>`,
})
export class LoginPage {
  constructor(public auth: AuthService) {}

  login() {
    this.auth
      .loginWithRedirect({
        async openUrl(url: string) {
          await Browser.open({ url, windowName: '_self' });
        },
      })
      .subscribe();
  }
}
```

### Step 6: Implement Logout

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { Browser } from '@capacitor/browser';

@Component({
  selector: 'app-logout-button',
  template: `<ion-button (click)="logout()">Log Out</ion-button>`,
})
export class LogoutButtonComponent {
  constructor(public auth: AuthService) {}

  logout() {
    this.auth
      .logout({
        logoutParams: {
          returnTo: `YOUR_PACKAGE_ID://YOUR_AUTH0_DOMAIN/capacitor/YOUR_PACKAGE_ID/callback`,
        },
        async openUrl(url: string) {
          await Browser.open({ url, windowName: '_self' });
        },
      })
      .subscribe();
  }
}
```

### Step 7: Display User Profile

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { AsyncPipe } from '@angular/common';

@Component({
  selector: 'app-profile',
  template: `
    <div *ngIf="auth.user$ | async as user">
      <img [src]="user.picture" [alt]="user.name" />
      <h2>{{ user.name }}</h2>
      <p>{{ user.email }}</p>
    </div>
  `,
})
export class ProfileComponent {
  constructor(public auth: AuthService) {}
}
```

### Step 8: Build and Test

> **Agent instruction:** After writing all code, verify the build succeeds:
> ```bash
> npm run build
> npx cap sync
> ```
> If the build fails, investigate errors and fix (up to 5-6 iterations). If still failing, use `AskUserQuestion` to ask the user for help.

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 configuration, Auth0 CLI setup, Capacitor platform setup, deep linking
- **[Integration Patterns](./references/integration.md)** — Login/logout flows, token management, user profile, error handling, Capacitor lifecycle
- **[API Reference & Testing](./references/api.md)** — AuthService API, configuration options, claims reference, testing checklist

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Auth0 app type set to **SPA** instead of **Native** | Change to **Native** in Auth0 Dashboard → Application Settings |
| Missing callback URL in Auth0 Dashboard | Add `PACKAGE_ID://{domain}/capacitor/PACKAGE_ID/callback` to Allowed Callback URLs AND Allowed Logout URLs |
| Not wrapping `handleRedirectCallback` in `ngZone.run()` | Angular won't detect auth state changes — always wrap in `ngZone.run()` |
| Using `window.location.href` for login redirect | Must use `Browser.open()` from `@capacitor/browser` for system browser |
| `useRefreshTokens` not set to `true` | Required for mobile — localStorage is unreliable on native platforms |
| `useRefreshTokensFallback` not set to `false` | Must be `false` to avoid falling back to iframe-based token refresh (unsupported on mobile) |
| Missing `@capacitor/app` listener for deep links | The `appUrlOpen` listener is required to handle the callback from the system browser |
| Using `loginWithPopup` on mobile | Popups don't work on native — use `loginWithRedirect` with `Browser.open` |
| Callback URL mismatch (scheme vs package ID) | The URL scheme must match the `appId` in `capacitor.config.ts` exactly |

## WebAuth Method

Ionic with Capacitor uses the **Web Auth** method for authentication:

1. User taps **Log In** → app calls `loginWithRedirect` with a custom `openUrl` that uses `Browser.open()`
2. Capacitor's Browser plugin opens the Auth0 Universal Login page in the system browser (SFSafariViewController / Chrome Custom Tabs)
3. User authenticates → Auth0 redirects to the custom URL scheme callback
4. OS routes the deep link to your app → `appUrlOpen` event fires
5. `handleRedirectCallback(url)` processes the auth code exchange inside `ngZone.run()`
6. `Browser.close()` dismisses the system browser
7. `auth.isAuthenticated$` emits `true`, and `auth.user$` emits the user profile

## Related Skills

- **auth0-ionic-react** — Ionic React with Capacitor
- **auth0-ionic-vue** — Ionic Vue with Capacitor
- **auth0-angular** — Angular SPA (browser-only)
- **auth0-swift** — Native iOS (Swift)
- **auth0-android** — Native Android (Kotlin)

## Quick Reference

| API | Description |
|-----|-------------|
| `AuthService.loginWithRedirect(options)` | Start login flow with custom `openUrl` for Capacitor |
| `AuthService.logout(options)` | Log out with custom `openUrl` and `returnTo` |
| `AuthService.handleRedirectCallback(url)` | Process the callback URL from the deep link |
| `AuthService.isAuthenticated$` | Observable boolean — whether user is logged in |
| `AuthService.user$` | Observable — current user profile (name, email, picture) |
| `AuthService.isLoading$` | Observable boolean — SDK initialization state |
| `AuthService.error$` | Observable — authentication errors |
| `AuthService.getAccessTokenSilently()` | Get access token (uses refresh tokens on mobile) |
| `Browser.open({ url })` | Open URL in system browser (Capacitor) |
| `CapApp.addListener('appUrlOpen', cb)` | Listen for deep link callbacks (Capacitor) |

## References

- [Auth0 Angular SDK — GitHub](https://github.com/auth0/auth0-angular)
- [Auth0 Ionic Angular Quickstart](https://auth0.com/docs/quickstart/native/ionic-angular)
- [Auth0 Angular SDK — API Reference](https://auth0.github.io/auth0-angular/)
- [Capacitor Browser Plugin](https://capacitorjs.com/docs/apis/browser)
- [Capacitor App Plugin — Deep Links](https://capacitorjs.com/docs/apis/app)
- [Ionic Framework — Angular](https://ionicframework.com/docs/angular/overview)
