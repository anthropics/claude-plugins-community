# auth0-net-android API Reference & Testing

## Configuration Reference

### Auth0ClientOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Domain` | `string` | — (required) | Auth0 tenant domain (e.g., `tenant.auth0.com`) |
| `ClientId` | `string` | — (required) | Auth0 application Client ID |
| `RedirectUri` | `string` | `{packageName}://{domain}/android/{packageName}/callback` | Callback URL after login (auto-derived from package name) |
| `PostLogoutRedirectUri` | `string` | Same as RedirectUri | Callback URL after logout |
| `Scope` | `string` | `"openid profile email"` | Space-separated OIDC scopes |
| `Leeway` | `TimeSpan` | 5 minutes | Clock skew tolerance for ID token validation |
| `MaxAge` | `TimeSpan?` | `null` | Max time since user last authenticated |
| `LoadProfile` | `bool` | `true` | Whether to load user profile from /userinfo |
| `EnableTelemetry` | `bool` | `true` | Include SDK telemetry in requests |
| `Browser` | `IBrowser` | `AutoSelectBrowser` | Browser implementation (ChromeCustomTabs or SystemBrowser) |
| `RefreshTokenMessageHandler` | `HttpMessageHandler` | `null` | Custom HTTP handler for refresh token requests |
| `BackchannelHandler` | `HttpMessageHandler` | `null` | Custom HTTP handler for backchannel communication |

### Auth0Client Constructors

| Constructor | Description |
|-------------|-------------|
| `Auth0Client(Auth0ClientOptions options)` | Create client with auto-detected callback from `Application.Context.PackageName` |
| `Auth0Client(Auth0ClientOptions options, Activity activity)` | Create client with callback auto-detected from Activity's IntentFilter attributes |

### IAuth0Client Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `LoginAsync(extraParameters?, cancellationToken?)` | `Task<LoginResult>` | Launch Chrome Custom Tab for login |
| `LogoutAsync(federated?, extraParameters?, cancellationToken?)` | `Task<BrowserResultType>` | Launch browser for logout |
| `RefreshTokenAsync(refreshToken, cancellationToken?)` | `Task<RefreshTokenResult>` | Refresh tokens using a refresh token |
| `RefreshTokenAsync(refreshToken, extraParameters?, cancellationToken?)` | `Task<RefreshTokenResult>` | Refresh with extra parameters |
| `RefreshTokenAsync(refreshToken, scope?, extraParameters?, cancellationToken?)` | `Task<RefreshTokenResult>` | Refresh with specific scope |
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
| `AuthenticationTime` | `DateTimeOffset` | When authentication occurred |

### RefreshTokenResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `IsError` | `bool` | Whether the refresh failed |
| `AccessToken` | `string` | New access token |
| `IdentityToken` | `string` | New ID token |
| `RefreshToken` | `string` | New refresh token (if rotated) |
| `AccessTokenExpiration` | `DateTimeOffset` | New expiration time |

### BrowserResultType Enum

| Value | Description |
|-------|-------------|
| `Success` | Authentication completed successfully |
| `UserCancel` | User cancelled the authentication |
| `HttpError` | HTTP error during authentication |
| `Timeout` | Authentication timed out |
| `UnknownError` | Unknown error occurred |

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
var userId = loginResult.User.FindFirst("sub")?.Value;
var email = loginResult.User.FindFirst("email")?.Value;
var name = loginResult.User.FindFirst("name")?.Value;
```

## Complete Code Example

See [Integration Patterns](./integration.md) for a full Activity example with login, logout, secure token storage, and callback handling.

## Testing Checklist

- [ ] Login flow: Chrome Custom Tab opens → authenticate → returns to app
- [ ] Callback received: `OnNewIntent` triggered with correct data
- [ ] User claims populated after login
- [ ] Logout flow: Browser opens → session cleared → returns to app
- [ ] Cancel: User presses back during login → app handles `UserCancel` gracefully
- [ ] Physical device: Test on real Android device (not just emulator)
- [ ] Deep link: Verify IntentFilter DataScheme/DataHost/DataPathPrefix are lowercase
- [ ] Dashboard config: Callback URL in Auth0 matches IntentFilter pattern exactly

## Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Callback never received | IntentFilter not matching the redirect URL | Verify DataScheme (lowercase package name), DataHost (domain), DataPathPrefix match |
| Duplicate Activity instances | Missing `LaunchMode.SingleTask` | Add `LaunchMode = LaunchMode.SingleTask` to Activity attribute |
| `UserCancel` error on every attempt | Browser can't find matching intent | Ensure `DataScheme` is lowercase; check no other app is handling same scheme |
| `access_denied` error | Callback URL not in Allowed Callback URLs | Add exact URL to Auth0 Dashboard |
| `invalid_request` error | OIDC Conformant not enabled | Enable in Dashboard → App → Advanced Settings → OAuth |

## Security Considerations

- Domain and ClientId are public values — they are not secrets
- No client secret is needed for Native applications
- The SDK uses PKCE to secure the authorization code exchange
- Tokens should be stored securely if persisted (use Android Keystore or EncryptedSharedPreferences)
- The `DataScheme` should ideally be a reverse-domain package name to reduce scheme hijacking risk
