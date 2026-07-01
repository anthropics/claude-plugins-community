---
name: auth0-maui
description: >
  Use when adding Auth0 login, logout, or token management to a .NET MAUI cross-platform app (iOS, Android, macOS, or Windows). Integrates Auth0.OidcClient.MAUI — use even if the user says "add login to my MAUI app".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# auth0-maui Integration

Add Auth0 authentication to .NET MAUI applications targeting iOS, Android, macOS, and Windows. This skill integrates the `Auth0.OidcClient.MAUI` NuGet package which uses the system browser via MAUI's `WebAuthenticator` for secure OIDC-based login and logout flows with PKCE.

> **Agent instruction:** Before providing SDK setup instructions, fetch the latest MAUI release version by running:
> ```bash
> gh api repos/auth0/auth0-oidc-client-net/releases --jq '[.[] | select(.tag_name | startswith("maui-")) | .tag_name | ltrimstr("maui-")] | .[0]'
> ```
> Use the returned version in all dependency lines instead of any hardcoded version below.

## Prerequisites

- .NET 8.0 SDK or later
- Visual Studio 2022 (17.8+) with MAUI workload, or JetBrains Rider with MAUI support
- For iOS: macOS with Xcode 15+
- For Android: Android SDK API 33+ (net8.0) or API 34+ (net9.0)
- For Windows: Windows 10 (10.0.19041.0)+
- Auth0 account with a Native application configured
- Node.js 20+ (for Auth0 CLI automated setup)

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| ASP.NET Core server-side web app | `auth0-aspnetcore-authentication` |
| ASP.NET Core Web API (JWT validation) | `auth0-aspnetcore-api` |
| React Native mobile app | `auth0-react-native` |
| iOS-only Swift app | `auth0-swift` |
| Android-only Kotlin app | `auth0-android` |
| Expo React Native app | `auth0-expo` |

## Quick Start Workflow

> **Agent instruction:** Before starting, examine the user's project:
> 1. Identify the .NET version from the `.csproj` file (`TargetFrameworks`)
> 2. Check for existing authentication implementations — search for existing login/logout handlers and hook into them if found
> 3. Note the project's namespace and directory conventions
> 4. Look for existing `Auth0Client` or `Auth0ClientOptions` usage to avoid duplicate configuration

1. **Install SDK**: `dotnet add package Auth0.OidcClient.MAUI`
2. **Configure Auth0**: See [Setup Guide](./references/setup.md) for automatic or manual configuration.
3. **Integrate authentication**: Add `Auth0Client` instantiation and wire login/logout to UI actions.
   - **IMPORTANT:** Always set `Scope = "openid profile email offline_access"` — the `offline_access` scope is required to receive a refresh token for silent token renewal.
4. **Persist tokens with SecureStorage**: After login, store the refresh token using `await SecureStorage.Default.SetAsync("refresh_token", loginResult.RefreshToken)`. On app startup, restore the session with `RefreshTokenAsync`. Clear on logout with `SecureStorage.Default.Remove("refresh_token")`.
5. **Register URL scheme**: Configure platform-specific callback handling:
   - Android: Create `WebAuthenticatorActivity` with IntentFilter for your custom scheme (e.g., `myapp`)
   - Windows (two steps required): (1) Add `<uap:Extension Category="windows.protocol"><uap:Protocol Name="myapp"/></uap:Extension>` to `Platforms/Windows/Package.appxmanifest`, AND (2) call `Activator.Default.CheckRedirectionActivation()` in `Platforms/Windows/App.xaml.cs`
   - iOS/macOS: No extra configuration needed
6. **Build and verify**: `dotnet build`

> **Agent instruction:** When writing the Auth0Client configuration:
> - **ALWAYS** include `offline_access` in the Scope string — without it, no refresh token is returned and the user must re-authenticate every time the access token expires.
> - **ALWAYS** implement token persistence using `SecureStorage.Default.SetAsync("refresh_token", ...)` after login and `SecureStorage.Default.GetAsync("refresh_token")` on app startup to restore sessions silently.
> - Clear stored tokens on logout with `SecureStorage.Default.Remove("refresh_token")`.
> - **ALWAYS** create/update `Platforms/Windows/Package.appxmanifest` to register the custom URL scheme protocol. Without this, Windows will not intercept the callback URL after authentication. Add a `<uap:Extension Category="windows.protocol"><uap:Protocol Name="myapp"/></uap:Extension>` inside the `<Extensions>` element of the `<Application>` node.
> - **ALWAYS** add `CheckRedirectionActivation()` in `Platforms/Windows/App.xaml.cs` as the first line in the constructor, before `InitializeComponent()`.
>
> After writing configuration and code, verify the build succeeds:
> ```bash
> dotnet build
> ```
> If the build fails, attempt to fix the issue. After 5-6 failed attempts, ask the user for help.

## Callback URL Configuration

The MAUI SDK uses a custom URL scheme for callbacks. The default pattern is:

```text
myapp://callback
```

Unlike other Auth0 native SDKs that use `https://{domain}/{platform}/{bundleId}/callback` or
`{bundleId}.auth0://{domain}/ios/{bundleId}/callback` patterns, MAUI uses a simpler custom scheme
approach. You can customize the scheme (e.g., `com.mycompany.myapp://callback`). Whatever scheme you choose must be:
1. Registered in Auth0 Dashboard under **Allowed Callback URLs** and **Allowed Logout URLs**
2. Configured in the platform-specific callback handler (Android `IntentFilter`, Windows `Package.appxmanifest`)
3. Set in `Auth0ClientOptions.RedirectUri` and `Auth0ClientOptions.PostLogoutRedirectUri`

> **Note:** For production apps, use a reverse-domain scheme (e.g., `com.yourcompany.yourapp://callback`) to reduce the risk of URL scheme hijacking.

## Done When

- [ ] `Auth0.OidcClient.MAUI` package installed
- [ ] `Auth0Client` configured with Domain, ClientId, and `Scope` including `offline_access`
- [ ] URL scheme registered on Android (WebAuthenticatorCallbackActivity) and Windows (Package.appxmanifest)
- [ ] Callback URL (`myapp://callback`) added to Auth0 Dashboard Allowed Callback URLs and Allowed Logout URLs
- [ ] Login/logout flow working
- [ ] Refresh token persisted via `SecureStorage.Default.SetAsync` after login
- [ ] Session restoration implemented via `SecureStorage.Default.GetAsync` + `RefreshTokenAsync` on app startup
- [ ] Build succeeds with no errors
- [ ] Tested on physical device or emulator/simulator

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 tenant configuration, SDK installation, platform-specific callback setup
- **[Integration Patterns](./references/integration.md)** — Login/logout flows, token refresh, user profile, error handling, MVVM patterns
- **[API Reference & Testing](./references/api.md)** — Full `Auth0ClientOptions` reference, claims, testing checklist, troubleshooting

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| App type not set to **Native** in Auth0 Dashboard | Change application type to "Native" in Dashboard settings |
| Missing callback URL in Auth0 Dashboard | Add `myapp://callback` (or your scheme) to Allowed Callback URLs AND Allowed Logout URLs |
| Android: Missing `WebAuthenticatorCallbackActivity` | Create activity class with `[IntentFilter]` matching your callback scheme |
| Windows: Not calling `CheckRedirectionActivation()` | Add `Activator.Default.CheckRedirectionActivation()` at start of Windows `App.xaml.cs`, before `InitializeComponent()` |
| Using `https://` prefix in Domain | Domain should be hostname only (e.g., `tenant.auth0.com`, not `https://tenant.auth0.com`) |
| Not requesting `offline_access` scope for token refresh | Add `offline_access` to `Scope` in `Auth0ClientOptions` to get a refresh token |
| RedirectUri/PostLogoutRedirectUri not matching Dashboard | Ensure the exact URI (scheme + path) matches what's configured in Auth0 Dashboard |
| Not registering URL scheme on Android/Windows | Register the custom URL scheme in platform-specific config (see Platform setup step) |
| Storing tokens in plain text | Use `SecureStorage` from MAUI Essentials for persisting refresh tokens |

## Testing Notes

> **Agent instruction:** Remind the user to test on a physical device in addition to emulators/simulators. Some WebAuthenticator behaviors (system browser integration, URL scheme interception) may differ on physical devices vs. emulators. Test the full login → callback → token flow on real hardware before shipping.

**Testing Checklist:**
- Login flow: System browser opens → authenticate → returns to app
- Logout flow: Browser opens → session cleared → returns to app
- Token refresh: `RefreshTokenAsync` with stored refresh token works
- Cancel: User cancels login → app handles `UserCancel` gracefully
- Physical device: Test on real iOS/Android device (not just simulator)
- Offline: Verify token refresh works when the app is restarted
- Multi-platform: Test on at least one mobile platform (iOS or Android) and Windows

## Related Skills

- **auth0-aspnetcore-authentication** — ASP.NET Core server-side web apps
- **auth0-aspnetcore-api** — ASP.NET Core Web API with JWT validation
- **auth0-android** — Android-native Kotlin apps
- **auth0-swift** — iOS/macOS Swift apps
- **auth0-react-native** — React Native mobile apps
- **auth0-net-android-ios** — .NET Android/iOS (non-MAUI)

## Quick Reference

```csharp
using Auth0.OidcClient;

// Initialize client
var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    RedirectUri = "myapp://callback",
    PostLogoutRedirectUri = "myapp://callback",
    Scope = "openid profile email offline_access"
});

// Login — opens system browser
var loginResult = await client.LoginAsync();
if (!loginResult.IsError)
{
    var user = loginResult.User;
    var accessToken = loginResult.AccessToken;
    var idToken = loginResult.IdentityToken;
    var refreshToken = loginResult.RefreshToken;

    // Access user claims
    var name = user.FindFirst("name")?.Value;
    var email = user.FindFirst("email")?.Value;

    // Persist refresh token securely for session restoration
    if (!string.IsNullOrEmpty(refreshToken))
        await SecureStorage.Default.SetAsync("refresh_token", refreshToken);
}

// Logout — clears Auth0 session and stored tokens
await client.LogoutAsync();
SecureStorage.Default.Remove("refresh_token");

// Restore session on app startup (no user interaction needed)
var savedToken = await SecureStorage.Default.GetAsync("refresh_token");
if (!string.IsNullOrEmpty(savedToken))
{
    var refreshResult = await client.RefreshTokenAsync(savedToken);
    if (!refreshResult.IsError)
    {
        var newAccessToken = refreshResult.AccessToken;
        // Update stored token if rotated
        if (!string.IsNullOrEmpty(refreshResult.RefreshToken))
            await SecureStorage.Default.SetAsync("refresh_token", refreshResult.RefreshToken);
    }
    else
    {
        // Refresh failed — clear and require re-login
        SecureStorage.Default.Remove("refresh_token");
    }
}

// Get user info from /userinfo endpoint
var userInfo = await client.GetUserInfoAsync(accessToken);

// Login with extra parameters (organization, audience, connection)
var orgLogin = await client.LoginAsync(new { organization = "org_abc123" });
var apiLogin = await client.LoginAsync(new { audience = "https://my-api.example.com" });
```

### Android Callback Activity (Required)

```csharp
[Activity(NoHistory = true, LaunchMode = LaunchMode.SingleTop, Exported = true)]
[IntentFilter(new[] { Intent.ActionView },
    Categories = new[] { Intent.CategoryDefault, Intent.CategoryBrowsable },
    DataScheme = CALLBACK_SCHEME)]
public class WebAuthenticatorActivity : Microsoft.Maui.Authentication.WebAuthenticatorCallbackActivity
{
    const string CALLBACK_SCHEME = "myapp";
}
```

### Windows Platform Setup (Required — Both Steps)

**Step 1: Register protocol in `Platforms/Windows/Package.appxmanifest`:**

```xml
<Extensions>
  <uap:Extension Category="windows.protocol">
    <uap:Protocol Name="myapp"/>
  </uap:Extension>
</Extensions>
```

**Step 2: Handle redirection in `Platforms/Windows/App.xaml.cs`:**

```csharp
// In Platforms/Windows/App.xaml.cs
public App()
{
    if (Auth0.OidcClient.Platforms.Windows.Activator.Default.CheckRedirectionActivation())
        return;
    this.InitializeComponent();
}
```

## References

- [Auth0 MAUI Quickstart](https://auth0.com/docs/quickstart/native/maui)
- [GitHub Repository](https://github.com/auth0/auth0-oidc-client-net)
- [NuGet Package](https://www.nuget.org/packages/Auth0.OidcClient.MAUI)
- [SDK API Documentation](https://auth0.github.io/auth0-oidc-client-net/documentation/intro.html)
- [Auth0 Native App Documentation](https://auth0.com/docs/get-started/auth0-overview/create-applications/native-apps)
