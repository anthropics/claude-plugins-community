---
name: auth0-net-android
description: >
  Use when adding Auth0 login or token management to a .NET Android application. Integrates Auth0.OidcClient.AndroidX — use even if the user says "add login to my .NET Android app" or references Xamarin Android.
license: Apache-2.0
metadata:
  author: Auth0 SDKs Team <auth0-sdk-cdt@okta.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/auth0-oidc-client-net
---

# auth0-net-android Integration

Add Auth0 authentication to .NET Android applications. This skill integrates the `Auth0.OidcClient.AndroidX` NuGet package which uses Chrome Custom Tabs for secure OIDC-based login and logout flows with PKCE.

> **Agent instruction:** Before providing SDK setup instructions, fetch the latest release version by running:
> ```bash
> gh api repos/auth0/auth0-oidc-client-net/releases --jq '[.[] | select(.tag_name | startswith("androidx-")) | .tag_name | ltrimstr("androidx-")] | .[0]'
> ```
> Use the returned version in all dependency lines instead of any hardcoded version below.

## Prerequisites

- .NET 8.0 SDK or later
- Visual Studio 2022 (17.8+) with .NET Android workload, or JetBrains Rider
- Android SDK API 21+ (minimum), API 34+ recommended for net9.0-android
- Auth0 account with a Native application configured
- Node.js 20+ (for Auth0 CLI automated setup)

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| .NET MAUI cross-platform app (iOS + Android + Windows) | `auth0-maui` |
| .NET iOS-only app | `auth0-net-ios` |
| Android-only Kotlin app | `auth0-android` |
| ASP.NET Core server-side web app | `auth0-aspnetcore-authentication` |
| ASP.NET Core Web API (JWT validation) | `auth0-aspnetcore-api` |
| React Native mobile app | `auth0-react-native` |

## Quick Start Workflow

> **Agent instruction:** Before starting, examine the user's project:
> 1. Identify the .NET version from the `.csproj` file (`TargetFramework`)
> 2. Check for existing authentication implementations — search for existing login/logout handlers and hook into them if found (reuse existing UI elements like login buttons rather than creating duplicates)
> 3. Note the project's namespace and package name from the `.csproj` or `AndroidManifest.xml`
> 4. Look for existing `Auth0Client` or `Auth0ClientOptions` usage to avoid duplicate configuration

1. **Install SDK**: `dotnet add package Auth0.OidcClient.AndroidX`
2. **Configure Auth0**: See [Setup Guide](./references/setup.md) for automatic or manual configuration.
3. **Integrate authentication**: Add `Auth0Client` instantiation, configure the `IntentFilter` on your Activity, and wire login/logout to UI actions.
4. **Handle callback**: Override `OnNewIntent` and call `ActivityMediator.Instance.Send(intent.DataString)` to complete the authentication flow.
5. **Build and verify**: `dotnet build`

> **Agent instruction:** When writing the Auth0Client configuration:
> - Pass `this` (the Activity) as the second argument to `Auth0Client` constructor.
> - **Always set `Scope = "openid profile email offline_access"`** — the `offline_access` scope is required to receive refresh tokens, enabling silent token renewal without re-prompting the user.
> - The callback URL format is `YOUR_ANDROID_PACKAGE_NAME://YOUR_AUTH0_DOMAIN/android/YOUR_ANDROID_PACKAGE_NAME/callback` — all lowercase.
> - The `DataScheme` in the `IntentFilter` must be lowercase or Android will not receive callbacks.
> - Set `LaunchMode = LaunchMode.SingleTask` on the Activity to prevent duplicate instances. Do NOT use `SingleTop` — it does not correctly handle the callback redirect and will create duplicate Activity instances.
> - The Activity should either extend `Auth0ClientActivity` OR manually override `OnNewIntent` and call `ActivityMediator.Instance.Send(intent.DataString)`.
> - **Store tokens securely**: After successful login, persist `AccessToken` and `RefreshToken` using `SecureStorage` (MAUI/Essentials) or `EncryptedSharedPreferences` (AndroidX Security — requires `dotnet add package Xamarin.AndroidX.Security.SecurityCrypto`). Never store tokens in plain `SharedPreferences` or in-memory variables only.
>
> After writing configuration and code, verify the build succeeds:
> ```bash
> dotnet build
> ```
> If the build fails, attempt to fix the issue. After 5-6 failed attempts, ask the user for help.

## WebAuth — How Authentication Works

The SDK uses the WebAuth pattern via Chrome Custom Tabs (the system browser). When `LoginAsync()` is called, the SDK:

1. Constructs the `/authorize` URL with PKCE parameters
2. Opens Chrome Custom Tabs with the authorization URL
3. After authentication, Auth0 redirects to the native callback URL
4. The Android system matches the URL scheme and delivers it to your Activity via `OnNewIntent`
5. `ActivityMediator` completes the token exchange

This is the standard OAuth 2.0 Authorization Code flow with PKCE, recommended for native mobile applications.

## Callback URL Configuration

The native callback URL for .NET Android uses the package name as the scheme. The format is:

```text
YOUR_ANDROID_PACKAGE_NAME://YOUR_AUTH0_DOMAIN/android/YOUR_ANDROID_PACKAGE_NAME/callback
```

Where `YOUR_ANDROID_PACKAGE_NAME` is the Package Name for your application, such as `com.mycompany.myapplication`. For example: `com.mycompany.myapp://tenant.us.auth0.com/android/com.mycompany.myapp/callback`.

> **Note:** Some Auth0 native SDKs use `https://{domain}/android/{package}/callback` as the callback URL format. The .NET Android SDK uses the package name as the URL scheme instead.

Ensure that the Callback URL is in lowercase.

This URL must be:
1. Registered in Auth0 Dashboard under **Allowed Callback URLs** and **Allowed Logout URLs**
2. Matched by the `IntentFilter` attributes (`DataScheme`, `DataHost`, `DataPathPrefix`) on your Activity

## Done When

- [ ] `Auth0.OidcClient.AndroidX` package installed (latest stable version)
- [ ] `Auth0Client` configured with Domain, ClientId, and `Scope = "openid profile email offline_access"`
- [ ] `IntentFilter` configured on Activity with correct DataScheme, DataHost, DataPathPrefix
- [ ] `LaunchMode = LaunchMode.SingleTask` set on Activity
- [ ] `OnNewIntent` handled with `ActivityMediator.Instance.Send(intent.DataString)`
- [ ] Callback URL added to Auth0 Dashboard Allowed Callback URLs and Allowed Logout URLs
- [ ] Tokens stored securely (SecureStorage or EncryptedSharedPreferences)
- [ ] Login/logout flow working
- [ ] Build succeeds with no errors

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 tenant configuration, SDK installation, IntentFilter setup
- **[Integration Patterns](./references/integration.md)** — Login/logout flows, token access, user profile, error handling
- **[API Reference & Testing](./references/api.md)** — Full `Auth0ClientOptions` reference, claims, testing checklist, troubleshooting

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| App type not set to **Native** in Auth0 Dashboard | Change application type to "Native" in Dashboard settings |
| Missing callback URL in Auth0 Dashboard | Add `yourpackagename://{domain}/android/yourpackagename/callback` to Allowed Callback URLs AND Allowed Logout URLs |
| `DataScheme` not lowercase | Android requires the scheme to be lowercase — use lowercase package name |
| Missing `LaunchMode.SingleTask` | Set `LaunchMode = LaunchMode.SingleTask` on the Activity to prevent duplicate instances |
| Not handling `OnNewIntent` | Override `OnNewIntent` and call `ActivityMediator.Instance.Send(intent.DataString)` |
| Using `https://` prefix in Domain | Domain should be hostname only (e.g., `tenant.auth0.com`, not `https://tenant.auth0.com`) |
| Not passing Activity context to Auth0Client | Pass `this` as second parameter: `new Auth0Client(options, this)` |
| IntentFilter DataHost/DataPathPrefix mismatch | Ensure DataHost matches your Auth0 domain and DataPathPrefix is `/android/yourpackagename/callback` |
| Missing `offline_access` scope | Always include `offline_access` in Scope to receive refresh tokens for silent renewal |
| Using `LaunchMode.SingleTop` instead of `SingleTask` | Must use `LaunchMode.SingleTask` — `SingleTop` does not correctly handle the Auth0 callback redirect |
| Storing tokens in plain SharedPreferences | Use `SecureStorage` or `EncryptedSharedPreferences` from AndroidX Security library |

## Testing Notes

> **Agent instruction:** Remind the user to test on a physical device in addition to emulators. Some WebAuth behaviors (Chrome Custom Tabs, URL scheme interception) may differ on physical devices vs. emulators. Test the full login → callback → token flow on real hardware before shipping.

**Physical Device Testing:**
- Login flow: Chrome Custom Tab opens → authenticate → returns to app
- Callback: `OnNewIntent` fires with correct intent data
- Logout flow: Browser opens → session cleared → returns to app
- Cancel: User presses back → app handles `UserCancel` gracefully

## Related Skills

- **auth0-maui** — .NET MAUI cross-platform apps (iOS + Android + Windows)
- **auth0-net-ios** — .NET iOS-only apps
- **auth0-android** — Android-native Kotlin apps
- **auth0-aspnetcore-authentication** — ASP.NET Core server-side web apps
- **auth0-aspnetcore-api** — ASP.NET Core Web API with JWT validation

## Quick Reference

```csharp
using Auth0.OidcClient;

var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    Scope = "openid profile email offline_access"
}, this);
```

### Login

```csharp
var loginResult = await client.LoginAsync();
```

### Handle Errors

```csharp
var loginResult = await client.LoginAsync();

if (loginResult.IsError)
{
    Debug.WriteLine($"An error occurred during login: {loginResult.Error}");
}
```

### Access Tokens

```csharp
var loginResult = await client.LoginAsync();

if (!loginResult.IsError)
{
    Debug.WriteLine($"Authentication successful.");
}
```

### User Information

```csharp
if (!loginResult.IsError)
{
    Debug.WriteLine($"name: {loginResult.User.FindFirst(c => c.Type == "name")?.Value}");
    Debug.WriteLine($"email: {loginResult.User.FindFirst(c => c.Type == "email")?.Value}");
}
```

### List All Claims

```csharp
if (!loginResult.IsError)
{
    foreach (var claim in loginResult.User.Claims)
    {
        Debug.WriteLine($"{claim.Type} = {claim.Value}");
    }
}
```

### Logout

```csharp
BrowserResultType browserResult = await client.LogoutAsync();
```

### Activity with IntentFilter (Required)

```csharp
[Activity(Label = "AndroidSample", MainLauncher = true, Icon = "@drawable/icon",
    LaunchMode = LaunchMode.SingleTask)]
[IntentFilter(
    new[] { Intent.ActionView },
    Categories = new[] { Intent.CategoryDefault, Intent.CategoryBrowsable },
    DataScheme = "YOUR_ANDROID_PACKAGE_NAME",
    DataHost = "YOUR_AUTH0_DOMAIN",
    DataPathPrefix = "/android/YOUR_ANDROID_PACKAGE_NAME/callback")]
public class MainActivity : Activity
{
    // Code omitted
}
```

### Handle Callback in OnNewIntent (Required)

```csharp
protected override async void OnNewIntent(Intent intent)
{
    base.OnNewIntent(intent);

    Auth0.OidcClient.ActivityMediator.Instance.Send(intent.DataString);
}
```

## References

- [.NET Android & iOS Quickstart](https://auth0.com/docs/quickstart/native/net-android-ios)
- [GitHub Repository](https://github.com/auth0/auth0-oidc-client-net)
- [NuGet Package — Auth0.OidcClient.AndroidX](https://www.nuget.org/packages/Auth0.OidcClient.AndroidX)
- [SDK API Documentation](https://auth0.github.io/auth0-oidc-client-net/documentation/intro.html)
