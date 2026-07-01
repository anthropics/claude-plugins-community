# auth0-ionic-angular — Integration Patterns

## Authentication Flow Overview

```text
User taps Login
    → auth.loginWithRedirect({ openUrl: Browser.open })
    → System browser opens Auth0 Universal Login
    → User authenticates
    → Auth0 redirects to custom URL scheme
    → OS routes deep link to app
    → CapApp.addListener('appUrlOpen') fires
    → ngZone.run() → auth.handleRedirectCallback(url)
    → Browser.close()
    → auth.isAuthenticated$ emits true
    → auth.user$ emits user profile
```

## Deep Link Callback Handler

The callback handler must be registered early in the app lifecycle. The recommended location is `AppComponent.ngOnInit()`:

```typescript
import { Component, NgZone, OnInit } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { Browser } from '@capacitor/browser';
import { App as CapApp } from '@capacitor/app';
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

**Why `ngZone.run()`?** Capacitor plugin callbacks execute outside Angular's zone. Without `ngZone.run()`, Angular won't detect the authentication state change and the UI won't update.

## Login

### Basic Login

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { Browser } from '@capacitor/browser';

@Component({
  selector: 'app-login',
  template: `
    <ion-button (click)="login()" *ngIf="(auth.isAuthenticated$ | async) === false">
      Log In
    </ion-button>
  `,
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

### Login with Custom Audience and Scopes

```typescript
login() {
  this.auth
    .loginWithRedirect({
      authorizationParams: {
        audience: 'https://my-api.example.com',
        scope: 'openid profile email read:data',
      },
      async openUrl(url: string) {
        await Browser.open({ url, windowName: '_self' });
      },
    })
    .subscribe();
}
```

### Login with Organization

```typescript
login() {
  this.auth
    .loginWithRedirect({
      authorizationParams: {
        organization: 'org_abc123',
      },
      async openUrl(url: string) {
        await Browser.open({ url, windowName: '_self' });
      },
    })
    .subscribe();
}
```

## Logout

### Basic Logout

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { Browser } from '@capacitor/browser';

@Component({
  selector: 'app-logout-button',
  template: `
    <ion-button (click)="logout()" *ngIf="auth.isAuthenticated$ | async">
      Log Out
    </ion-button>
  `,
})
export class LogoutButtonComponent {
  constructor(public auth: AuthService) {}

  logout() {
    this.auth
      .logout({
        logoutParams: {
          returnTo: `PACKAGE_ID://YOUR_AUTH0_DOMAIN/capacitor/PACKAGE_ID/callback`,
        },
        async openUrl(url: string) {
          await Browser.open({ url, windowName: '_self' });
        },
      })
      .subscribe();
  }
}
```

### Building the Logout Return URL Dynamically

```typescript
import { Inject } from '@angular/core';
import { AuthClientConfig } from '@auth0/auth0-angular';
import { DOCUMENT } from '@angular/common';

export class LogoutButtonComponent {
  constructor(
    public auth: AuthService,
    private config: AuthClientConfig,
  ) {}

  logout() {
    const domain = this.config.get().domain;
    const packageId = 'com.example.myapp'; // from capacitor.config.ts
    const returnTo = `${packageId}://${domain}/capacitor/${packageId}/callback`;

    this.auth
      .logout({
        logoutParams: { returnTo },
        async openUrl(url: string) {
          await Browser.open({ url, windowName: '_self' });
        },
      })
      .subscribe();
  }
}
```

## User Profile

### Display User Info

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { AsyncPipe, NgIf } from '@angular/common';
import { IonCard, IonCardHeader, IonCardTitle, IonCardContent, IonAvatar } from '@ionic/angular/standalone';

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [AsyncPipe, NgIf, IonCard, IonCardHeader, IonCardTitle, IonCardContent, IonAvatar],
  template: `
    <ion-card *ngIf="auth.user$ | async as user">
      <ion-card-header>
        <ion-avatar>
          <img [src]="user.picture" [alt]="user.name" />
        </ion-avatar>
        <ion-card-title>{{ user.name }}</ion-card-title>
      </ion-card-header>
      <ion-card-content>
        <p>{{ user.email }}</p>
      </ion-card-content>
    </ion-card>
  `,
})
export class ProfileComponent {
  constructor(public auth: AuthService) {}
}
```

### Access ID Token Claims

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';

@Component({
  selector: 'app-claims',
  template: `
    <pre *ngIf="auth.idTokenClaims$ | async as claims">
      {{ claims | json }}
    </pre>
  `,
})
export class ClaimsComponent {
  constructor(public auth: AuthService) {}
}
```

## Token Management

### Get Access Token

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';

@Component({ ... })
export class ApiComponent {
  constructor(private auth: AuthService, private http: HttpClient) {}

  callApi() {
    this.auth.getAccessTokenSilently().subscribe(token => {
      this.http.get('https://my-api.example.com/data', {
        headers: { Authorization: `Bearer ${token}` },
      }).subscribe(data => console.log(data));
    });
  }
}
```

### Use HTTP Interceptor (Recommended)

The `authHttpInterceptorFn` automatically attaches tokens to matching requests:

```typescript
// app.config.ts
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideAuth0, authHttpInterceptorFn } from '@auth0/auth0-angular';

export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(withInterceptors([authHttpInterceptorFn])),
    provideAuth0({
      domain: 'YOUR_AUTH0_DOMAIN',
      clientId: 'YOUR_AUTH0_CLIENT_ID',
      useRefreshTokens: true,
      useRefreshTokensFallback: false,
      authorizationParams: {
        audience: 'https://my-api.example.com',
      },
      httpInterceptor: {
        allowedList: ['https://my-api.example.com/*'],
      },
    }),
  ],
};
```

Then make HTTP calls as normal — tokens are added automatically:

```typescript
this.http.get('https://my-api.example.com/data').subscribe(data => {
  console.log(data);
});
```

## Route Guards

### Protect Routes with `authGuardFn`

```typescript
import { Routes } from '@angular/router';
import { authGuardFn } from '@auth0/auth0-angular';

export const routes: Routes = [
  { path: '', component: HomePage },
  { path: 'profile', component: ProfilePage, canActivate: [authGuardFn] },
  { path: 'settings', component: SettingsPage, canActivate: [authGuardFn] },
];
```

When an unauthenticated user navigates to a protected route, `authGuardFn` automatically triggers `loginWithRedirect()`.

## Error Handling

### Subscribe to Auth Errors

```typescript
import { Component, OnInit } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';

@Component({ ... })
export class AppComponent implements OnInit {
  constructor(private auth: AuthService) {}

  ngOnInit() {
    this.auth.error$.subscribe(error => {
      if (error) {
        console.error('Auth error:', error.message);
        // Show toast or navigate to error page
      }
    });
  }
}
```

### Handle Callback Errors

```typescript
CapApp.addListener('appUrlOpen', ({ url }) => {
  this.ngZone.run(() => {
    if (url.includes('state') && (url.includes('code') || url.includes('error'))) {
      this.auth.handleRedirectCallback(url).pipe(
        mergeMap(() => Browser.close()),
      ).subscribe({
        error: (err) => {
          console.error('Callback error:', err);
          Browser.close();
        },
      });
    }
  });
});
```

## Capacitor Lifecycle Considerations

### Listener Cleanup

If registering the `appUrlOpen` listener in a component that can be destroyed (not AppComponent), clean up:

```typescript
import { Component, NgZone, OnInit, OnDestroy } from '@angular/core';
import { App as CapApp } from '@capacitor/app';
import { PluginListenerHandle } from '@capacitor/core';

@Component({ ... })
export class AuthCallbackComponent implements OnInit, OnDestroy {
  private listenerHandle?: PluginListenerHandle;

  async ngOnInit() {
    this.listenerHandle = await CapApp.addListener('appUrlOpen', ({ url }) => {
      this.ngZone.run(() => {
        // handle callback...
      });
    });
  }

  async ngOnDestroy() {
    await this.listenerHandle?.remove();
  }
}
```

### App Resume / Background

The Auth0 Angular SDK handles token refresh automatically via `useRefreshTokens: true`. When the app resumes from background:
- If the refresh token is still valid, `getAccessTokenSilently()` returns a fresh access token
- If the refresh token has expired, `isAuthenticated$` will emit `false` and the user needs to log in again

## Testing Patterns

### Mock AuthService in Unit Tests

```typescript
import { TestBed } from '@angular/core/testing';
import { AuthService } from '@auth0/auth0-angular';
import { of } from 'rxjs';

const mockAuthService = {
  isAuthenticated$: of(true),
  user$: of({ name: 'Test User', email: 'test@example.com', picture: 'https://example.com/pic.jpg' }),
  loginWithRedirect: jasmine.createSpy('loginWithRedirect').and.returnValue(of(void 0)),
  logout: jasmine.createSpy('logout').and.returnValue(of(void 0)),
  getAccessTokenSilently: jasmine.createSpy('getAccessTokenSilently').and.returnValue(of('mock-token')),
};

TestBed.configureTestingModule({
  providers: [
    { provide: AuthService, useValue: mockAuthService },
  ],
});
```
