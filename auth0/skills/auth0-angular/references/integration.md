# Auth0 Angular Integration Patterns

Angular-specific implementation patterns with route guards, HTTP interceptors, and RxJS.

---

## Protected Routes

### Auth Guard

Create `src/app/guards/auth.guard.ts`:

```typescript
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '@auth0/auth0-angular';
import { map } from 'rxjs/operators';

export const authGuard = () => {
  const authService = inject(AuthService);
  const router = inject(Router);

  return authService.isAuthenticated$.pipe(
    map(isAuthenticated => {
      if (!isAuthenticated) {
        authService.loginWithRedirect();
        return false;
      }
      return true;
    })
  );
};
```

### Apply Guard to Routes

```typescript
// app.routes.ts (standalone)
import { Routes } from '@angular/router';
import { authGuard } from './guards/auth.guard';

export const routes: Routes = [
  { path: '', component: HomeComponent },
  {
    path: 'profile',
    component: ProfileComponent,
    canActivate: [authGuard]
  }
];
```

---

## Calling a Protected API

There are two alternative approaches to attach access tokens to API requests. Choose the one that best fits your needs — you do not need both:

- **HTTP Interceptor (recommended)** — Automatically attaches tokens to outgoing requests matching a configured URL list. This is the simplest, most centralized approach and works well for most applications.
- **Manual token retrieval** — Call `getAccessTokenSilently()` to obtain a token and attach it to requests yourself. Use this when you need explicit, per-request control over token handling.

### Option 1: HTTP Interceptor

Configure the built-in HTTP interceptor in app config:

```typescript
// app.config.ts
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { authHttpInterceptorFn } from '@auth0/auth0-angular';
import { environment } from '../environments/environment'; // Adjust path as needed

export const appConfig: ApplicationConfig = {
  providers: [
    provideAuth0({
      domain: environment.auth0.domain,
      clientId: environment.auth0.clientId,
      authorizationParams: {
        audience: 'https://your-api-identifier',
        redirect_uri: window.location.origin
      },
      httpInterceptor: {
        allowedList: [
          '/api/*',
          'https://your-api.com/*'
        ]
      }
    }),
    provideHttpClient(
      withInterceptors([authHttpInterceptorFn])
    )
  ]
};
```

With this in place, any `HttpClient` request to a URL matching `allowedList` will automatically include the access token:

```typescript
// data.service.ts
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Injectable({ providedIn: 'root' })
export class DataService {
  constructor(private http: HttpClient) {}

  getData() {
    return this.http.get('https://your-api.com/data');
    // Access token automatically added by interceptor
  }
}
```

### Option 2: Manual Token Retrieval

If you prefer explicit control instead of using the interceptor, call `getAccessTokenSilently()` to obtain a token and attach it yourself:

```typescript
import { AuthService } from '@auth0/auth0-angular';
import { HttpClient } from '@angular/common/http';
import { switchMap } from 'rxjs/operators';

constructor(private auth: AuthService, private http: HttpClient) {}

callApi() {
  this.auth.getAccessTokenSilently({
    authorizationParams: {
      audience: 'https://your-api-identifier'
    }
  }).pipe(
    switchMap(token =>
      this.http.get('https://your-api.com/data', {
        headers: { Authorization: `Bearer ${token}` }
      })
    )
  ).subscribe({
    next: (response) => console.log(response),
    error: (err) => console.error(err)
  });
}
```

---

## User Profile Component

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div *ngIf="auth.user$ | async as user">
      <img [src]="user.picture" [alt]="user.name" />
      <h2>{{ user.name }}</h2>
      <p>{{ user.email }}</p>
      <pre>{{ user | json }}</pre>
    </div>
  `
})
export class ProfileComponent {
  constructor(public auth: AuthService) {}
}
```

---

## Error Handling

### Handle Auth Errors

```typescript
import { Component, OnInit } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';

@Component({
  template: `
    <div *ngIf="error$ | async as error" class="error">
      <h3>Authentication Error</h3>
      <p>{{ error.message }}</p>
    </div>
  `
})
export class AppComponent implements OnInit {
  error$ = this.auth.error$;

  constructor(private auth: AuthService) {}

  ngOnInit() {
    this.error$.subscribe(error => {
      if (error) {
        console.error('Auth error:', error);
      }
    });
  }
}
```

---

## Common Patterns

### Login with Options

```typescript
login() {
  this.auth.loginWithRedirect({
    authorizationParams: {
      connection: 'google-oauth2',
      screen_hint: 'signup'
    }
  });
}
```

## Testing

### Mock AuthService

```typescript
// auth.service.mock.ts
import { of } from 'rxjs';

export const mockAuthService = {
  isAuthenticated$: of(true),
  user$: of({ name: 'Test User', email: 'test@example.com' }),
  loginWithRedirect: jasmine.createSpy('loginWithRedirect'),
  logout: jasmine.createSpy('logout'),
  getAccessTokenSilently: jasmine.createSpy('getAccessTokenSilently').and.returnValue(of('mock-token'))
};
```

### Use in Tests

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { AuthService } from '@auth0/auth0-angular';
import { mockAuthService } from './auth.service.mock';

describe('AppComponent', () => {
  let fixture: ComponentFixture<AppComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: mockAuthService }
      ]
    });
    fixture = TestBed.createComponent(AppComponent);
  });

  it('should display user name', () => {
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('Test User');
  });
});
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| CORS errors | Add URLs to "Allowed Web Origins" in Auth0 Dashboard |
| Interceptor not adding tokens | Verify `allowedList` in httpInterceptor config |
| Guard not redirecting | Ensure AuthService is provided in root |
| Observables not updating | Use `async` pipe or subscribe properly |

---

## Next Steps

- [API Reference](api.md) - Complete SDK documentation
- [Setup Guide](setup.md) - Installation and configuration
- [Main Skill](../SKILL.md) - Quick start workflow
