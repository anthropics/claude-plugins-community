# auth0-net-ios API Reference & Testing

## Configuration Reference

### Auth0ClientOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Domain` | `string` | — (required) | Auth0 tenant domain (e.g., `tenant.auth0.com`) |
| `ClientId` | `string` | — (required) | Auth0 application Client ID |
| `RedirectUri` | `string` | `{BundleIdentifier}://{domain}/ios/{BundleIdentifier}/callback` | Callback URL after login (auto-derived from Bundle ID) |
| `PostLogoutRedirectUri` | `string` | Same as RedirectUri | Callback URL after logout |
| `Scope` | `string` | `"openid profile email"` | Space-separated OIDC scopes |
| `Leeway` | `TimeSpan` | 5 minutes | Clock skew tolerance for ID token validation |
| `MaxAge` | `TimeSpan?` | `null` | Max time since user last authenticated |
| `LoadProfile` | `bool` | `true` | Whether to load user profile from /userinfo |
| `EnableTelemetry` | `bool` | `true` | Include SDK telemetry in requests |
| `Browser` | `IBrowser` | `AutoSelectBrowser` (ASWebAuthenticationSession) | Browser implementation |
| `RefreshTokenMessageHandler` | `HttpMessageHandler` | `null` | Custom HTTP handler for refresh token requests |
| `BackchannelHandler` | `HttpMessageHandler` | `null` | Custom HTTP handler for backchannel communication |

### Auth0Client Constructor

| Constructor | Description |
|-------------|-------------|
| `Auth0Client(Auth0ClientOptions options)` | Create client with callback auto-derived from `NSBundle.MainBundle.BundleIdentifier` |

> **Note:** Unlike the Android SDK, the iOS SDK does NOT accept an Activity/context parameter.

### IAuth0Client Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `LoginAsync(extraParameters?, cancellationToken?)` | `Task<LoginResult>` | Launch ASWebAuthenticationSession for login |
| `LogoutAsync(federated?, extraParameters?, cancellationToken?)` | `Task<BrowserResultType>` | Launch browser for logout |
| `RefreshTokenAsync(refreshToken, cancellationToken?)` | `Task<RefreshTokenResult>` | Refresh tokens using a refresh token |
| `RefreshTokenAsync(refreshToken, extraParameters?, cancellationToken?)` | `Task<RefreshTokenResult>` | Refresh with extra parameters |
| `RefreshTokenAsync(refreshToken, scope?, extraParameters?, cancellationToken?)` | `Task<RefreshTokenResult>` | Refresh with specific scope |
| `GetUserInfoAsync(accessToken)` | `Task<UserInfoResult>` | Get user claims from /userinfo endpoint |
| `PrepareLoginAsync(extraParameters?, cancellationToken?)` | `Task<AuthorizeState>` | Prepare login URL and state (advanced) |
| `ProcessResponseAsync(data, state, extraParameters?, cancellationToken?)` | `Task<LoginResult>` | Process auth response manually (advanced) |

### ASWebAuthenticationSessionOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `PrefersEphemeralWebBrowserSession` | `bool` | `false` | When true, don't share cookies with Safari (no SSO, always prompt login) |

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

### AppDelegate.cs

```csharp
using Foundation;
using UIKit;
using Auth0.OidcClient;

namespace iOSSample
{
    [Register("AppDelegate")]
    public class AppDelegate : UIApplicationDelegate
    {
        public override UIWindow Window { get; set; }

        public override bool OpenUrl(UIApplication app, NSUrl url, NSDictionary options)
        {
            ActivityMediator.Instance.Send(url.AbsoluteString);

            return true;
        }

        public override bool FinishedLaunching(UIApplication application, NSDictionary launchOptions)
        {
            Window = new UIWindow(UIScreen.MainScreen.Bounds);
            Window.RootViewController = new MyViewController();
            Window.MakeKeyAndVisible();
            return true;
        }
    }
}
```

### MyViewController.cs

```csharp
using System;
using UIKit;
using Auth0.OidcClient;
using System.Text;
using System.Diagnostics;

namespace iOSSample
{
    public partial class MyViewController : UIViewController
    {
        private Auth0Client _client;

        public MyViewController() : base("MyViewController", null)
        {
        }

        public override void ViewDidLoad()
        {
            base.ViewDidLoad();
            LoginButton.TouchUpInside += LoginButton_TouchUpInside;
        }

        private async void LoginButton_TouchUpInside(object sender, EventArgs e)
        {
            _client = new Auth0Client(new Auth0ClientOptions
            {
                Domain = "YOUR_AUTH0_DOMAIN",
                ClientId = "YOUR_AUTH0_CLIENT_ID",
                Scope = "openid profile email offline_access"
            });

            var loginResult = await _client.LoginAsync();

            var sb = new StringBuilder();

            if (loginResult.IsError)
            {
                sb.AppendLine("An error occurred during login:");
                sb.AppendLine(loginResult.Error);
            }
            else
            {
                sb.AppendLine($"Name: {loginResult.User.FindFirst("name")?.Value}");
                sb.AppendLine($"Email: {loginResult.User.FindFirst("email")?.Value}");
                sb.AppendLine();
                sb.AppendLine("-- Claims --");
                foreach (var claim in loginResult.User.Claims)
                {
                    sb.AppendLine($"{claim.Type} = {claim.Value}");
                }
            }

            UserDetailsTextView.Text = sb.ToString();
        }
    }
}
```

### Info.plist (URL Scheme section)

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>None</string>
        <key>CFBundleURLName</key>
        <string>Auth0</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.auth0.iossample</string>
        </array>
    </dict>
</array>
```

## Testing Checklist

- [ ] Login flow: ASWebAuthenticationSession opens → authenticate → returns to app
- [ ] Callback received: `OpenUrl` triggered in AppDelegate
- [ ] User claims populated after login
- [ ] Logout flow: Browser opens → session cleared → returns to app
- [ ] Cancel: User cancels login → app handles `UserCancel` gracefully
- [ ] Physical device: Test on real iOS device (not just simulator)
- [ ] URL scheme: Verify `CFBundleURLSchemes` matches Bundle Identifier
- [ ] Dashboard config: Callback URL in Auth0 matches `{bundleId}://{domain}/ios/{bundleId}/callback`

## Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Callback never received | Missing URL scheme in Info.plist | Add `CFBundleURLSchemes` entry matching Bundle Identifier |
| App not opening after auth | `OpenUrl` not implemented in AppDelegate | Add `OpenUrl` override with `ActivityMediator.Instance.Send` |
| `UserCancel` on every attempt | URL scheme registered by another app | Use a unique Bundle Identifier as the scheme |
| `access_denied` error | Callback URL not in Allowed Callback URLs | Add exact URL to Auth0 Dashboard |
| `invalid_request` error | OIDC Conformant not enabled | Enable in Dashboard → App → Advanced Settings → OAuth |
| No SSO between sessions | `PrefersEphemeralWebBrowserSession` is true | Set to false (default) to share session with Safari |

## Security Considerations

- Domain and ClientId are public values — they are not secrets
- No client secret is needed for Native applications
- The SDK uses PKCE to secure the authorization code exchange
- Tokens should be stored securely if persisted (use iOS Keychain)
- ASWebAuthenticationSession is the recommended secure browser on iOS 12+
- `PrefersEphemeralWebBrowserSession = true` prevents SSO but also prevents session fixation attacks
