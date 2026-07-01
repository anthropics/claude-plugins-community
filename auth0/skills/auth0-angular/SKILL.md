---
name: auth0-angular
description: >
  Use when adding Auth0 login, logout, route guards, or HTTP interceptors to an Angular application. Integrates @auth0/auth0-angular for SPAs — use even if the user says "protect my Angular routes" or "add authentication to Angular" without naming the SDK.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Angular Integration

Add authentication to Angular applications using @auth0/auth0-angular.

---

## Prerequisites

- Angular 13+ application
- Auth0 account and application configured
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **AngularJS (1.x)** - This SDK requires Angular 13+, use legacy solutions for AngularJS
- **Mobile applications** - Use `auth0-react-native` for React Native or native SDKs for Ionic
- **Backend APIs** - Use JWT validation middleware for your server language

---

## Quick Start Workflow

### 1. Install SDK

```bash
npm install @auth0/auth0-angular
```

### 2. Configure Environment

**For automated setup with Auth0 CLI**, see [Setup Guide](references/setup.md) for complete scripts.

**For manual setup:**

Update `src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  auth0: {
    domain: 'your-tenant.auth0.com',
    clientId: 'your-client-id',
    authorizationParams: {
      redirect_uri: window.location.origin
    }
  }
};
```

### 3. Configure Auth Module

**For standalone components (Angular 14+):**

Update `src/app/app.config.ts`:

```typescript
import { ApplicationConfig } from '@angular/core';
import { provideAuth0 } from '@auth0/auth0-angular';
import { environment } from '../environments/environment';

export const appConfig: ApplicationConfig = {
  providers: [
    provideAuth0({
      domain: environment.auth0.domain,
      clientId: environment.auth0.clientId,
      authorizationParams: environment.auth0.authorizationParams
    })
  ]
};
```

**For NgModule-based apps:**

Update `src/app/app.module.ts`:

```typescript
import { AuthModule } from '@auth0/auth0-angular';
import { environment } from '../environments/environment';

@NgModule({
  imports: [
    AuthModule.forRoot({
      domain: environment.auth0.domain,
      clientId: environment.auth0.clientId,
      authorizationParams: environment.auth0.authorizationParams
    })
  ]
})
export class AppModule {}
```

### 4. Add Authentication UI

Update `src/app/app.component.ts`:

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';

@Component({
  selector: 'app-root',
  template: `
    <div *ngIf="auth.isLoading$ | async; else loaded">
      <p>Loading...</p>
    </div>

    <ng-template #loaded>
      <ng-container *ngIf="auth.isAuthenticated$ | async; else loggedOut">
        <div *ngIf="auth.user$ | async as user">
          <img [src]="user.picture" [alt]="user.name" />
          <h2>Welcome, {{ user.name }}!</h2>
          <button (click)="logout()">Logout</button>
        </div>
      </ng-container>

      <ng-template #loggedOut">
        <button (click)="login()">Login</button>
      </ng-template>
    </ng-template>
  `
})
export class AppComponent {
  constructor(public auth: AuthService) {}

  login(): void {
    this.auth.loginWithRedirect();
  }

  logout(): void {
    this.auth.logout({ logoutParams: { returnTo: window.location.origin } });
  }
}
```

### 5. Test Authentication

Start your dev server and test the login flow:

```bash
ng serve
```

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup scripts (Bash/PowerShell), CLI commands, manual configuration
- **[Integration Guide](references/integration.md)** - Protected routes with guards, HTTP interceptors, error handling
- **[API Reference](references/api.md)** - Complete SDK API, configuration options, services reference, testing strategies

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgot to add redirect URI in Auth0 Dashboard | Add your application URL (e.g., `http://localhost:4200`, `https://app.example.com`) to Allowed Callback URLs in Auth0 Dashboard |
| Not configuring AuthModule properly | Must call `AuthModule.forRoot()` in NgModule or `provideAuth0()` in standalone config |
| Accessing auth before initialization | Use `isLoading$` observable to wait for SDK initialization |
| Storing tokens manually | Never manually store tokens - SDK handles secure storage automatically |
| No token sent to API | Use either `authHttpInterceptorFn` for automatic token attachment, or `getAccessTokenSilently()` for manual control — see [Integration Guide](references/integration.md#calling-a-protected-api) |
| Route guard not protecting routes | Apply `AuthGuard` (or `authGuardFn`) to protected routes in routing config |

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Core Services:**
- `AuthService` - Main authentication service
- `isAuthenticated$` - Observable check if user is logged in
- `user$` - Observable user profile information
- `loginWithRedirect()` - Initiate login
- `logout()` - Log out user
- `getAccessTokenSilently()` - Get access token manually (alternative to HTTP interceptor)

**Common Use Cases:**
- Login/Logout buttons → See Step 4 above
- Protected routes with guards → [Integration Guide](references/integration.md#protected-routes)
- Calling a protected API → [Integration Guide](references/integration.md#calling-a-protected-api)
- Error handling → [Integration Guide](references/integration.md#error-handling)

---

## References

- [Auth0 Angular SDK Documentation](https://auth0.com/docs/libraries/auth0-angular)
- [Auth0 Angular Quickstart](https://auth0.com/docs/quickstart/spa/angular)
- [SDK GitHub Repository](https://github.com/auth0/auth0-angular)
