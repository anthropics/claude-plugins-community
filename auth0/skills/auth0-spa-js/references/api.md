# Auth0 SPA JS — API Reference & Testing

---

## Configuration Reference

### Auth0ClientOptions

Options passed to `createAuth0Client()` or `new Auth0Client()`.

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `domain` | `string` | Yes | Auth0 tenant domain — hostname only, no `https://` prefix |
| `clientId` | `string` | Yes | SPA application Client ID from Auth0 Dashboard |
| `authorizationParams` | `AuthorizationParams` | No | Authorization request parameters |
| `authorizationParams.redirect_uri` | `string` | No | Where Auth0 redirects after login (default: `window.location.origin`) |
| `authorizationParams.audience` | `string` | No | API identifier (e.g., `https://api.example.com`) for access tokens |
| `authorizationParams.scope` | `string` | No | Space-separated OIDC scopes (default: `openid profile email`) |
| `authorizationParams.organization` | `string` | No | Organization ID or name for multi-tenant apps |
| `useRefreshTokens` | `boolean` | No | Enable refresh token rotation (default: `false`) |
| `useRefreshTokensFallback` | `boolean` | No | Fall back to iframe silent auth if refresh token fails (default: `false`) |
| `cacheLocation` | `'memory' \| 'localstorage'` | No | Token cache location (default: `'memory'`) |
| `cache` | `ICache` | No | Custom cache implementation |
| `useDpop` | `boolean` | No | Enable DPoP token binding (default: `false`) |
| `useMrrt` | `boolean` | No | Multi-resource refresh tokens — requires `useRefreshTokens: true` (default: `false`) |
| `leeway` | `number` | No | Clock skew tolerance in seconds (default: `60`) |
| `sessionCheckExpiryDays` | `number` | No | Days before session check cookie expires (default: `1`) |
| `httpTimeoutInSeconds` | `number` | No | HTTP request timeout (default: `10`) |
| `issuer` | `string` | No | Override expected token issuer |

### getTokenSilently Options

| Option | Type | Description |
|--------|------|-------------|
| `authorizationParams.audience` | `string` | Override audience for this token request |
| `authorizationParams.scope` | `string` | Override scopes for this token request |
| `cacheMode` | `'on' \| 'off' \| 'cache-only'` | Cache behavior (default: `'on'`) |
| `detailedResponse` | `boolean` | Return `{ access_token, token_type, id_token, expires_in }` instead of string |
| `timeoutInSeconds` | `number` | Override timeout for this call |

---

## Environment Variables

| Bundler | Domain Variable | Client ID Variable |
|---------|----------------|-------------------|
| Vite | `VITE_AUTH0_DOMAIN` | `VITE_AUTH0_CLIENT_ID` |
| Create React App | `REACT_APP_AUTH0_DOMAIN` | `REACT_APP_AUTH0_CLIENT_ID` |
| Webpack (custom) | `AUTH0_DOMAIN` | `AUTH0_CLIENT_ID` |

**Vite access:**
```js
import.meta.env.VITE_AUTH0_DOMAIN
```

**CRA access:**
```js
process.env.REACT_APP_AUTH0_DOMAIN
```

---

## Error Types

| Class | Import | When Thrown |
|-------|--------|-------------|
| `AuthenticationError` | `@auth0/auth0-spa-js` | `handleRedirectCallback` — Auth0 returned an error |
| `GenericError` | `@auth0/auth0-spa-js` | Network or Auth0 API errors; base class for all SDK errors |
| `TimeoutError` | `@auth0/auth0-spa-js` | Silent auth or network request timeout |
| `PopupTimeoutError` | `@auth0/auth0-spa-js` | `loginWithPopup` — user didn't complete in time |
| `PopupCancelledError` | `@auth0/auth0-spa-js` | `loginWithPopup` — popup was closed by the user |
| `PopupOpenError` | `@auth0/auth0-spa-js` | `loginWithPopup` — `window.open` returned null (popups blocked) |
| `MfaRequiredError` | `@auth0/auth0-spa-js` | `getTokenSilently` — MFA step required; access `error.mfa_token` |
| `MissingRefreshTokenError` | `@auth0/auth0-spa-js` | `getTokenSilently` — refresh token not available |
| `ConnectError` | `@auth0/auth0-spa-js` | `handleRedirectCallback` — error in connected accounts flow |
| `MfaListAuthenticatorsError` | `@auth0/auth0-spa-js` | `auth0.mfa.getAuthenticators()` failed |
| `MfaEnrollmentError` | `@auth0/auth0-spa-js` | `auth0.mfa.enroll()` failed |
| `MfaChallengeError` | `@auth0/auth0-spa-js` | `auth0.mfa.challenge()` failed |
| `MfaVerifyError` | `@auth0/auth0-spa-js` | `auth0.mfa.verify()` failed |

---

## Claims Reference

Claims available from `auth0.getUser()` (ID token):

| Claim | Type | Description |
|-------|------|-------------|
| `sub` | `string` | Subject — unique user ID: `auth0\|64abc...` |
| `name` | `string` | Full name |
| `given_name` | `string` | First name |
| `family_name` | `string` | Last name |
| `nickname` | `string` | Nickname or username |
| `email` | `string` | Email address |
| `email_verified` | `boolean` | Whether email is verified |
| `picture` | `string` | Profile picture URL |
| `locale` | `string` | User locale |
| `updated_at` | `string` | Last profile update ISO timestamp |

Claims on the **access token** (from `getTokenSilently({ detailedResponse: true })`):

| Claim | Description |
|-------|-------------|
| `iss` | Issuer — your Auth0 domain URL |
| `aud` | Audience — API identifier(s) |
| `azp` | Authorized party — your Client ID |
| `scope` | Space-separated scopes granted |
| `permissions` | RBAC permissions array (requires API audience + Auth0 RBAC enabled) |
| `org_id` | Organization ID for multi-tenant apps |

---

## Testing Checklist

### Core Authentication

- [ ] Login redirect sends user to Auth0 Universal Login page
- [ ] After login, user is returned to app (no dangling `code=` params in URL)
- [ ] `auth0.isAuthenticated()` returns `true` after successful login
- [ ] `auth0.getUser()` returns profile with `sub`, `name`, `email`
- [ ] Logout clears session and redirects to `returnTo` URL
- [ ] After logout, `isAuthenticated()` returns `false`

### Token Management

- [ ] `getTokenSilently()` returns a JWT string
- [ ] Access token decoded at [jwt.io](https://jwt.io) shows correct `aud`, `iss`, `sub`
- [ ] Tokens are **not** stored in `localStorage` (DevTools → Application → Local Storage)
- [ ] Page refresh maintains authentication (silent auth via `checkSession`)
- [ ] `getTokenSilently()` works without redirecting when session is active

### Error Handling

- [ ] Navigating to app when not logged in does not throw uncaught errors
- [ ] `login_required` error on `getTokenSilently` triggers re-authentication
- [ ] Network failure in `getTokenSilently` is caught and handled gracefully

### Security

- [ ] Auth0 Dashboard: Application type is **Single Page Application**
- [ ] Auth0 Dashboard: Token Endpoint Auth Method is **None**
- [ ] Auth0 Dashboard: Allowed Web Origins includes your app origin
- [ ] No `client_secret` anywhere in source code or `.env`
- [ ] Dev `.env` file is in `.gitignore`

---

## Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `login_required` on `getTokenSilently` | Allowed Web Origins not configured | Add `http://localhost:5173` to Allowed Web Origins in Auth0 Dashboard |
| `invalid_client` | Wrong Client ID | Check env var matches Auth0 Dashboard Client ID |
| Callback URL mismatch error | Port mismatch between app and Dashboard | Match exactly: `http://localhost:5173` in both places |
| `Unable to open popup` | Popup not triggered by user gesture | Call `loginWithPopup` directly in a click handler, never from async init |
| Token not refreshing silently | `offline_access` scope missing | Add `scope: 'openid profile email offline_access'` with `useRefreshTokens: true` |
| `MissingRefreshTokenError` | `useRefreshTokens` false or scope missing | Enable `useRefreshTokens: true` and include `offline_access` scope |
| User logged out on page refresh | Allowed Web Origins missing or no refresh tokens | Add Allowed Web Origins; enable `useRefreshTokens: true` |
| Cross-origin iframe blocked | Browser blocks third-party cookies | Use `useRefreshTokens: true` instead of silent iframe auth |
| Domain includes protocol | `domain` option should not include `https://` | Use `your-tenant.auth0.com` not `https://your-tenant.auth0.com` |

---

## Security Considerations

### Token Storage

| Strategy | Security | Session Persistence |
|----------|----------|-------------------|
| In-memory (default) | Highest — immune to XSS | Lost on page refresh |
| Refresh tokens (`useRefreshTokens: true`) | High — refresh token in memory | Persists across page refreshes |
| `localStorage` | Lowest — vulnerable to XSS | Persists across page refreshes |

**Recommendation:** Use `useRefreshTokens: true` with `cacheLocation: 'memory'` (the default) for the best balance of security and user experience.

### No Client Secret

SPAs run entirely in the browser and cannot protect secrets. The Auth0 SPA application type explicitly disables client secret authentication. Never add `client_secret` to a browser-based application.

### PKCE Flow

`@auth0/auth0-spa-js` always uses the Authorization Code + PKCE (Proof Key for Code Exchange) flow. This protects against authorization code interception and is the only secure OAuth 2.0 flow for browser-based applications.

### Content Security Policy

If you need to restrict iframe origins (only relevant when NOT using `useRefreshTokens`):
```
Content-Security-Policy: frame-src https://your-tenant.auth0.com;
```

### XSS Protection

Never use `cacheLocation: 'localstorage'` in production unless you have fully mitigated all XSS risks. XSS can steal tokens from `localStorage`. The default in-memory cache is immune to XSS-based token theft.
