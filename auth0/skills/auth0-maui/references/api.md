# auth0-maui API Reference & Testing

## Configuration Reference

### Auth0ClientOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Domain` | `string` | — (required) | Auth0 tenant domain (e.g., `tenant.auth0.com`) |
| `ClientId` | `string` | — (required) | Auth0 application Client ID |
| `RedirectUri` | `string` | `https://{Domain}/mobile` | Callback URL after login |
| `PostLogoutRedirectUri` | `string` | `https://{Domain}/mobile` | Callback URL after logout |
| `Scope` | `string` | `"openid profile email"` | Space-separated OIDC scopes |
| `Leeway` | `TimeSpan` | 5 minutes | Clock skew tolerance for ID token validation |
| `MaxAge` | `TimeSpan?` | `null` | Max time since user last authenticated |
| `LoadProfile` | `bool` | `true` | Whether to load user profile from /userinfo |
| `EnableTelemetry` | `bool` | `true` | Include SDK telemetry in requests |
| `Browser` | `IBrowser` | `WebAuthenticatorBrowser` | Browser implementation (auto-set for MAUI) |
| `RefreshTokenMessageHandler` | `HttpMessageHandler` | `null` | Custom HTTP handler for refresh token requests |
| `BackchannelHandler` | `HttpMessageHandler` | `null` | Custom HTTP handler for backchannel communication |

### IAuth0Client Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `LoginAsync(extraParameters?, cancellationToken?)` | `Task<LoginResult>` | Launch system browser for login |
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

## Code Examples

### Complete MAUI Page with Login/Logout

```csharp
using Auth0.OidcClient;

namespace MyMauiApp;

public partial class MainPage : ContentPage
{
    private readonly Auth0Client _auth0Client;
    private string _accessToken;

    public MainPage()
    {
        InitializeComponent();

        _auth0Client = new Auth0Client(new Auth0ClientOptions
        {
            Domain = "YOUR_AUTH0_DOMAIN",
            ClientId = "YOUR_AUTH0_CLIENT_ID",
            RedirectUri = "myapp://callback",
            PostLogoutRedirectUri = "myapp://callback",
            Scope = "openid profile email offline_access"
        });
    }

    private async void OnLoginClicked(object sender, EventArgs e)
    {
        var loginResult = await _auth0Client.LoginAsync();

        if (loginResult.IsError)
        {
            await DisplayAlert("Error", loginResult.ErrorDescription, "OK");
            return;
        }

        _accessToken = loginResult.AccessToken;
        var userName = loginResult.User.FindFirst("name")?.Value;
        WelcomeLabel.Text = $"Hello, {userName}!";
    }

    private async void OnLogoutClicked(object sender, EventArgs e)
    {
        var result = await _auth0Client.LogoutAsync();
        _accessToken = null;
        WelcomeLabel.Text = "You are logged out.";
    }
}
```

### Using Extra Parameters

```csharp
// Login with organization
var loginResult = await client.LoginAsync(new
{
    organization = "org_abc123"
});

// Login with specific connection
var loginResult = await client.LoginAsync(new
{
    connection = "google-oauth2"
});

// Login with audience for API access
var loginResult = await client.LoginAsync(new
{
    audience = "https://my-api.example.com"
});

// Login with screen_hint for signup
var loginResult = await client.LoginAsync(new
{
    screen_hint = "signup"
});
```

### Token Refresh

```csharp
// Store refresh token after login
var refreshToken = loginResult.RefreshToken;

// Later, refresh the access token
var refreshResult = await client.RefreshTokenAsync(refreshToken);
if (!refreshResult.IsError)
{
    var newAccessToken = refreshResult.AccessToken;
    // Update stored refresh token if rotated
    if (!string.IsNullOrEmpty(refreshResult.RefreshToken))
    {
        refreshToken = refreshResult.RefreshToken;
    }
}
```

## Testing Checklist

- [ ] **Login flow**: User taps login → system browser opens → authenticates → returns to app with user info
- [ ] **Logout flow**: User taps logout → browser opens → session cleared → returns to app
- [ ] **Token refresh**: After token expires, `RefreshTokenAsync` returns new valid tokens
- [ ] **Cancel handling**: User cancels login in browser → `LoginResult.IsError` is true, app handles gracefully
- [ ] **Android callback**: `WebAuthenticatorCallbackActivity` intercepts the callback URL correctly
- [ ] **Windows callback**: Protocol activation works and `CheckRedirectionActivation()` handles redirect
- [ ] **iOS/macOS**: Universal link or scheme-based callback returns control to app
- [ ] **Claims access**: User claims (`sub`, `email`, `name`) are accessible after login
- [ ] **Offline access**: With `offline_access` scope, `RefreshToken` is present in `LoginResult`
- [ ] **Error display**: Authentication errors display meaningful messages to the user

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `UserCancel` result type | User closed browser without completing login | Handle gracefully — show login button again |
| `LoginResult.IsError = true` with no description | Callback URL mismatch | Verify `RedirectUri` matches Auth0 Dashboard "Allowed Callback URLs" exactly |
| Logout doesn't return to app | PostLogoutRedirectUri not in Dashboard | Add `PostLogoutRedirectUri` value to "Allowed Logout URLs" in Dashboard |
| RefreshToken is null after login | Missing `offline_access` scope | Add `offline_access` to `Scope` in `Auth0ClientOptions` |
| Android: Activity not found for callback | Missing or incorrect `IntentFilter` | Verify `DataScheme` in `IntentFilter` matches your callback scheme |
| Windows: App launches new instance | `CheckRedirectionActivation()` not called early enough | Must be first line in Windows `App()` constructor, before `InitializeComponent()` |
| ID token validation fails | Clock skew between device and server | Increase `Leeway` value (default is 5 minutes) |

## Security Considerations

- **No client secret**: Native apps do not use a client secret. The Auth0 application type must be "Native" with `token_endpoint_auth_method` set to `none`.
- **PKCE**: The SDK automatically uses Proof Key for Code Exchange (PKCE) for all authorization requests.
- **Custom scheme security**: Use a unique scheme (e.g., your reverse domain) to minimize scheme hijacking risk. On Android, only one app can register a given scheme.
- **Token storage**: The SDK does not persist tokens. Store refresh tokens securely using `SecureStorage` from MAUI Essentials.
- **System browser**: The SDK uses the system browser (not an embedded WebView), which prevents the app from accessing user credentials and enables SSO.
- **Redirect URI validation**: Always use the same redirect URI in code and Auth0 Dashboard. Mismatches cause silent failures.
