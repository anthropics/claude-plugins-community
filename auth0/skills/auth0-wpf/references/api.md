# Auth0 WPF API Reference & Testing

## Configuration Reference

### Auth0ClientOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Domain` | `string` | — (required) | Auth0 tenant domain (e.g., `tenant.auth0.com`) |
| `ClientId` | `string` | — (required) | Auth0 application Client ID |
| `Scope` | `string` | `"openid profile email"` | Space-separated OIDC scopes |
| `RedirectUri` | `string` | `https://{Domain}/mobile` | Callback URL after login |
| `PostLogoutRedirectUri` | `string` | `https://{Domain}/mobile` | Callback URL after logout |
| `Leeway` | `TimeSpan` | 5 minutes | Clock skew tolerance for ID token validation |
| `MaxAge` | `TimeSpan?` | `null` | Max time since user last authenticated |
| `LoadProfile` | `bool` | `true` | Whether to load user profile from /userinfo |
| `EnableTelemetry` | `bool` | `true` | Include SDK telemetry in requests |
| `Browser` | `IBrowser` | `WebViewBrowser` | Browser implementation (WebView2 popup by default) |
| `RefreshTokenMessageHandler` | `HttpMessageHandler` | `null` | Custom HTTP handler for refresh token requests |
| `BackchannelHandler` | `HttpMessageHandler` | `null` | Custom HTTP handler for backchannel communication |

### IAuth0Client Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `LoginAsync(extraParameters?, cancellationToken?)` | `Task<LoginResult>` | Open WebView2 window for login |
| `LogoutAsync(federated?, extraParameters?, cancellationToken?)` | `Task<BrowserResultType>` | Open WebView2 window for logout |
| `RefreshTokenAsync(refreshToken, cancellationToken?)` | `Task<RefreshTokenResult>` | Refresh tokens using a refresh token |
| `GetUserInfoAsync(accessToken)` | `Task<UserInfoResult>` | Get user claims from /userinfo endpoint |
| `PrepareLoginAsync(extraParameters?, cancellationToken?)` | `Task<AuthorizeState>` | Prepare login URL and state (advanced) |
| `ProcessResponseAsync(data, state, extraParameters?, cancellationToken?)` | `Task<LoginResult>` | Process auth response manually (advanced) |

### LoginResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `IsError` | `bool` | Whether the login failed |
| `Error` | `string` | Error code (if failed) |
| `ErrorDescription` | `string` | Error description (if failed) |
| `User` | `ClaimsPrincipal` | Authenticated user's claims |
| `AccessToken` | `string` | Access token |
| `IdentityToken` | `string` | ID token |
| `RefreshToken` | `string` | Refresh token (requires `offline_access` scope) |
| `AccessTokenExpiration` | `DateTimeOffset` | When the access token expires |

### RefreshTokenResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `IsError` | `bool` | Whether the refresh failed |
| `AccessToken` | `string` | New access token |
| `IdentityToken` | `string` | New ID token |
| `RefreshToken` | `string` | New refresh token (if rotated) |

## Claims Reference

Standard OIDC claims available on `LoginResult.User.Claims`:

| Claim Type | Description | Example |
|------------|-------------|---------|
| `sub` | Auth0 user ID | `auth0\|507f1f77bcf86cd799439011` |
| `name` | Full name | `John Doe` |
| `email` | Email address | `john@example.com` |
| `email_verified` | Whether email is verified | `true` |
| `picture` | Profile picture URL | `https://s.gravatar.com/...` |
| `nickname` | User's nickname | `john.doe` |
| `updated_at` | Last profile update | `2024-01-15T10:30:00.000Z` |

Access claims:
```csharp
var user = loginResult.User;
var name = user.FindFirst(c => c.Type == "name")?.Value;
var email = user.FindFirst(c => c.Type == "email")?.Value;
var picture = user.FindFirst(c => c.Type == "picture")?.Value;
```

## Testing Checklist

- [ ] **Login flow**: Click login → WebView2 popup opens → authenticate → popup closes → user info available
- [ ] **Logout flow**: Click logout → WebView2 popup opens → session cleared → popup closes
- [ ] **Token refresh**: After token expires, `RefreshTokenAsync` returns new valid tokens
- [ ] **Cancel handling**: User closes WebView2 popup → `LoginResult.IsError` is true with `UserCancel`
- [ ] **Claims access**: User claims (`sub`, `email`, `name`) are accessible after login
- [ ] **Offline access**: With `offline_access` scope, `RefreshToken` is present in `LoginResult`
- [ ] **Error display**: Authentication errors display meaningful messages

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| WebView2 popup doesn't appear | WebView2 Runtime not installed | Install Microsoft Edge WebView2 Runtime |
| `LoginResult.IsError = true` with no description | Callback URL mismatch | Verify `https://{yourDomain}/mobile` is in Allowed Callback URLs |
| Logout doesn't complete | PostLogoutRedirectUri not in Dashboard | Add `https://{yourDomain}/mobile` to Allowed Logout URLs |
| RefreshToken is null after login | Missing `offline_access` scope | Add `offline_access` to `Scope` in `Auth0ClientOptions` |
| `UserCancel` result | User closed the WebView2 window | Handle gracefully — show login button again |
| ID token validation fails | Clock skew between machine and server | Increase `Leeway` value (default is 5 minutes) |

## Security Considerations

- **No client secret**: Native apps do not use a client secret. The Auth0 application type must be "Native" with `token_endpoint_auth_method` set to `none`.
- **PKCE**: The SDK automatically uses Proof Key for Code Exchange (PKCE) for all authorization requests.
- **WebView2**: The SDK uses WebView2 (Chromium-based) which provides process isolation and modern security features.
- **Token storage**: The SDK does not persist tokens. If you need to persist refresh tokens, use Windows DPAPI or a secure storage mechanism.
- **Redirect URI validation**: Always use the same redirect URI in code and Auth0 Dashboard. Mismatches cause silent failures.
