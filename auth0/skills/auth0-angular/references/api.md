## Common Patterns

### Protected Route with Auth Guard

Create an auth guard (`src/app/auth.guard.ts`):

```typescript
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '@auth0/auth0-angular';
import { map, take } from 'rxjs/operators';

export const authGuard = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  return auth.isAuthenticated$.pipe(
    take(1),
    map(isAuthenticated => {
      if (!isAuthenticated) {
        auth.loginWithRedirect();
        return false;
      }
      return true;
    })
  );
};
```

**Configure routes** (`src/app/app.routes.ts`):

```typescript
import { Routes } from '@angular/router';
import { authGuard } from './auth.guard';
import { HomeComponent } from './home/home.component';
import { ProfileComponent } from './profile/profile.component';

export const routes: Routes = [
  { path: '', component: HomeComponent },
  {
    path: 'profile',
    component: ProfileComponent,
    canActivate: [authGuard]  // Protect this route
  }
];
```

---

### Get User Profile Component

Create `src/app/profile/profile.component.ts`:

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
      <h1>Profile</h1>
      <img [src]="user.picture" [alt]="user.name" />
      <p>Name: {{ user.name }}</p>
      <p>Email: {{ user.email }}</p>
      <p>User ID: {{ user.sub }}</p>
    </div>
  `
})
export class ProfileComponent {
  constructor(public auth: AuthService) {}
}
```

---

### Call Protected API (Manual Token Approach)

This example uses `getAccessTokenSilently()` to manually obtain and attach tokens. This is an alternative to using the built-in HTTP interceptor — see the [Integration Guide](integration.md#calling-a-protected-api) for both approaches.

Create `src/app/api-test/api-test.component.ts`:

```typescript
import { Component } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { HttpClient } from '@angular/common/http';
import { switchMap } from 'rxjs/operators';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-api-test',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div>
      <button (click)="callApi()">Call API</button>
      <div *ngIf="error">Error: {{ error }}</div>
      <pre *ngIf="data">{{ data | json }}</pre>
    </div>
  `
})
export class ApiTestComponent {
  data: any = null;
  error: string | null = null;

  constructor(
    private auth: AuthService,
    private http: HttpClient
  ) {}

  callApi(): void {
    this.auth.getAccessTokenSilently({
      authorizationParams: {
        audience: 'https://your-api-identifier'
      }
    }).pipe(
      switchMap(token =>
        this.http.get('https://your-api.com/data', {
          headers: {
            Authorization: `Bearer ${token}`
          }
        })
      )
    ).subscribe({
      next: (response) => {
        this.data = response;
      },
      error: (err) => {
        this.error = err.message;
      }
    });
  }
}
```

**Note:** If calling APIs, add `audience` to your Auth module configuration:

```typescript
AuthModule.forRoot({
  domain: environment.auth0.domain,
  clientId: environment.auth0.clientId,
  authorizationParams: {
    redirect_uri: window.location.origin,
    audience: 'https://your-api-identifier'  // Add this
  }
})
```

---

### Custom HTTP Interceptor for API Calls

This shows how to build a custom interceptor from scratch. In most cases, you should use the SDK's built-in `authHttpInterceptorFn` instead — see the [Integration Guide](integration.md#calling-a-protected-api). A custom interceptor is only needed when you require logic beyond what `allowedList` provides.

Create `src/app/auth.interceptor.ts`:

```typescript
import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from '@auth0/auth0-angular';
import { switchMap } from 'rxjs/operators';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);

  // Only add token to API calls
  if (req.url.startsWith('https://your-api.com')) {
    return auth.getAccessTokenSilently().pipe(
      switchMap(token => {
        const clonedReq = req.clone({
          setHeaders: {
            Authorization: `Bearer ${token}`
          }
        });
        return next(clonedReq);
      })
    );
  }

  return next(req);
};
```

**Register interceptor** (`src/app/app.config.ts`):

```typescript
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { authInterceptor } from './auth.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideAuth0({...}),
    provideHttpClient(
      withInterceptors([authInterceptor])
    )
  ]
};
```

---

## Configuration Options

### Complete Auth Configuration

```typescript
AuthModule.forRoot({
  domain: 'your-tenant.auth0.com',
  clientId: 'your-client-id',
  authorizationParams: {
    redirect_uri: window.location.origin,
    audience: 'https://your-api-identifier',  // For API calls
    scope: 'openid profile email',  // Default scopes
  },
  cacheLocation: 'localstorage',  // or 'memory'
  useRefreshTokens: true,  // Enable refresh tokens
  skipRedirectCallback: false,  // Skip automatic callback handling
  errorPath: '/error',  // Path to redirect on auth errors (default: '/')
  httpInterceptor: {
    allowedList: [
      'https://your-api.com/*'  // Automatically add tokens to these URLs
    ]
  }
})
```

---

## Testing

1. Start your dev server: `ng serve`
2. Navigate to `http://localhost:4200`
3. Click "Login" button
4. Complete Auth0 Universal Login
5. Verify redirect back with user authenticated
6. Test protected routes
7. Click "Logout" and verify user is logged out

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Invalid state" error | Clear browser storage. Ensure `redirect_uri` matches configured callback URL |
| User stuck on loading | Check Auth0 application has `http://localhost:4200` in callback URLs |
| API calls fail with 401 | Ensure `audience` is configured and matches your API identifier |
| Logout doesn't work | Include `returnTo` URL and configure in Auth0 "Allowed Logout URLs" |
| HTTP interceptor not working | Check `allowedList` includes your API URLs |

---

## Security Considerations

- **Never expose client secret** - Angular is client-side, use only public client credentials
- **Use PKCE** - Enabled by default with @auth0/auth0-angular
- **Validate tokens on backend** - Never trust client-side token validation
- **Use HTTPS in production** - Auth0 requires HTTPS for production redirect URLs
- **Implement proper CORS** - Configure allowed origins in Auth0 application settings

---

## Advanced Methods

### getAccessTokenWithPopup

Gets an access token via popup window. Useful when silent authentication fails (e.g., third-party cookies blocked).

```typescript
// Try silent, fall back to popup
this.auth.getAccessTokenSilently().subscribe({
  next: (token) => {
    // Use the token (e.g., attach to API requests)
  },
  error: () => {
    // Silent auth failed, try popup
    this.auth.getAccessTokenWithPopup().subscribe(token => {
      // Use the token (e.g., attach to API requests)
    });
  }
});
```

### connectAccountWithRedirect

Redirects to connect an additional account to the logged-in user. Allows users to link multiple identity providers.

```typescript
// Link a Google account to existing user
this.auth.connectAccountWithRedirect({
  connection: 'google-oauth2',
  scopes: ['openid', 'profile', 'email'],
  authorizationParams: {
    // additional params
  }
}).subscribe();
```

After the redirect callback, `handleRedirectCallback` will be called with the details of the connected account.

---

## Related Skills

- `auth0-quickstart` - Initial Auth0 account setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-organizations` - B2B multi-tenancy support
- `auth0-passkeys` - Add passkey authentication

---

## References

- [Auth0 Angular SDK Documentation](https://auth0.com/docs/libraries/auth0-angular)
- [Auth0 Angular SDK GitHub](https://github.com/auth0/auth0-angular)
- [Auth0 Angular Quickstart](https://auth0.com/docs/quickstart/spa/angular)
- [Angular Router Documentation](https://angular.io/guide/router)
