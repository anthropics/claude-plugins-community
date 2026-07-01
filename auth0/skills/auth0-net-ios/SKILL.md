---
name: auth0-net-ios
description: >
  Use when adding Auth0 login or token management to a .NET iOS application. Integrates Auth0.OidcClient.iOS — use even if the user says "add login to my .NET iOS app" or references Xamarin iOS.
license: Apache-2.0
metadata:
  author: Auth0 SDKs Team <auth0-sdk-cdt@okta.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/auth0-oidc-client-net
---

# auth0-net-ios Integration

Add Auth0 authentication to .NET iOS applications. This skill integrates the `Auth0.OidcClient.iOS` NuGet package which uses `ASWebAuthenticationSession` for secure OIDC-based login and logout flows with PKCE.

> **Agent instruction:** Before providing SDK setup instructions, fetch the latest release version by running:
> ```bash
> gh api repos/auth0/auth0-oidc-client-net/releases --jq '[.[] | select(.tag_name | startswith("ios-")) | .tag_name | ltrimstr("ios-")] | .[0]'
> ```
> Use the returned version in all dependency lines instead of any hardcoded version below.

## Prerequisites

- .NET 8.0 SDK or later (.NET 9 also supported — use `net9.0-ios` target framework)
- JetBrains Rider or VS Code with C# Dev Kit (with iOS workload)
- macOS with Xcode 15+
- iOS 14.0+ deployment target
- Auth0 account with a Native application configured
- Node.js 20+ (for Auth0 CLI automated setup)

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| .NET MAUI cross-platform app (iOS + Android + Windows) | `auth0-maui` |
| .NET Android-only app | `auth0-net-android` |
| iOS-only Swift app | `auth0-swift` |
| ASP.NET Core server-side web app | `auth0-aspnetcore-authentication` |
| ASP.NET Core Web API (JWT validation) | `auth0-aspnetcore-api` |
| React Native mobile app | `auth0-react-native` |

## Quick Start Workflow

> **Agent instruction:** Before starting, examine the user's project:
> 1. Identify the .NET version from the `.csproj` file (`TargetFramework`)
> 2. Check for existing authentication implementations — search for existing login/logout handlers and hook into them if found (reuse existing UI elements like login buttons rather than creating duplicates)
> 3. Note the project's Bundle Identifier from `Info.plist` or `.csproj`
> 4. Look for existing `Auth0Client` or `Auth0ClientOptions` usage to avoid duplicate configuration

1. **Install SDK**: `dotnet add package Auth0.OidcClient.iOS`
2. **Configure Auth0**: See [Setup Guide](./references/setup.md) for automatic or manual configuration.
3. **Integrate authentication**: Add `Auth0Client` instantiation, register the URL scheme in `Info.plist`, and wire login/logout to UI actions.
4. **Handle callback**: Implement `OpenUrl` in `AppDelegate` and call `ActivityMediator.Instance.Send(url.AbsoluteString)`.
5. **Build and verify**: `dotnet build`

> **Agent instruction:** When writing the Auth0Client configuration:
> - The iOS SDK does NOT require passing an Activity context — just `new Auth0Client(options)`.
> - **Always set `Scope = "openid profile email offline_access"`** — the `offline_access` scope is required to receive refresh tokens, enabling silent token renewal without re-prompting the user.
> - The callback URL is automatically derived from the Bundle Identifier: `{BundleId}://{domain}/ios/{BundleId}/callback`.
> - The Bundle Identifier must be registered as a URL scheme in `Info.plist`.
> - The `AppDelegate` must handle `OpenUrl` and call `ActivityMediator.Instance.Send(url.AbsoluteString)`.
> - **Store tokens securely**: After successful login, persist `AccessToken` and `RefreshToken` using iOS Keychain (via `Security` framework or a wrapper like `KeychainAccess`). Never store tokens in `UserDefaults` or in-memory variables only.
>
> After writing configuration and code, verify the build succeeds:
> ```bash
> dotnet build
> ```
> If the build fails, attempt to fix the issue. After 5-6 failed attempts, ask the user for help.

## WebAuth — How Authentication Works

The SDK uses ASWebAuthenticationSession (the secure system browser). When `LoginAsync()` is called:

1. SDK constructs the `/authorize` URL with PKCE parameters (code verifier + challenge)
2. ASWebAuthenticationSession opens showing the Auth0 login page
3. User authenticates (login form, social connections, MFA, etc.)
4. Auth0 redirects to the native callback URL: `{BundleId}://{domain}/ios/{BundleId}/callback`
5. iOS intercepts the URL scheme and delivers it to `AppDelegate.OpenUrl`
6. `ActivityMediator.Instance.Send(url.AbsoluteString)` completes the token exchange
7. SDK returns `LoginResult` with access token, ID token, refresh token, and user claims

This is the standard OAuth 2.0 Authorization Code flow with PKCE, recommended for native mobile applications.

## Callback URL Configuration

The native callback URL for .NET iOS uses the Bundle Identifier as the scheme. The format is:

```text
YOUR_BUNDLE_IDENTIFIER://YOUR_AUTH0_DOMAIN/ios/YOUR_BUNDLE_IDENTIFIER/callback
```

Where `YOUR_BUNDLE_IDENTIFIER` is the Bundle Identifier for your application, such as `com.mycompany.myapplication`. For example: `com.mycompany.myapp://tenant.us.auth0.com/ios/com.mycompany.myapp/callback`.

> **Note:** Some Auth0 native SDKs use `https://{domain}/ios/{bundleId}/callback` or `{bundleId}.auth0://{domain}/ios/{bundleId}/callback` as the callback URL format. The .NET iOS SDK uses the Bundle Identifier directly as the URL scheme.

Ensure that the Callback URL is in lowercase.

This URL must be:
1. Registered in Auth0 Dashboard under **Allowed Callback URLs** and **Allowed Logout URLs**
2. Registered as a URL scheme in `Info.plist` under `CFBundleURLSchemes`

## Done When

- [ ] `Auth0.OidcClient.iOS` package installed (latest stable version)
- [ ] `Auth0Client` configured with Domain, ClientId, and `Scope = "openid profile email offline_access"`
- [ ] URL scheme registered in `Info.plist` matching the Bundle Identifier
- [ ] `AppDelegate.OpenUrl` implemented with `ActivityMediator.Instance.Send(url.AbsoluteString)`
- [ ] Callback URL added to Auth0 Dashboard Allowed Callback URLs and Allowed Logout URLs
- [ ] Tokens stored securely using iOS Keychain (`Security` framework with `SecKeyChain.Add`)
- [ ] Login/logout flow working
- [ ] Build succeeds with no errors

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 tenant configuration, SDK installation, Info.plist URL scheme setup
- **[Integration Patterns](./references/integration.md)** — Login/logout flows, token access, user profile, error handling
- **[API Reference & Testing](./references/api.md)** — Full `Auth0ClientOptions` reference, claims, testing checklist, troubleshooting

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| App type not set to **Native** in Auth0 Dashboard | Change application type to "Native" in Dashboard settings |
| Missing callback URL in Auth0 Dashboard | Add `yourbundleid://{domain}/ios/yourbundleid/callback` to Allowed Callback URLs AND Allowed Logout URLs |
| Missing URL scheme in Info.plist | Add `CFBundleURLSchemes` entry matching your Bundle Identifier |
| Not handling `OpenUrl` in AppDelegate | Override `OpenUrl` and call `ActivityMediator.Instance.Send(url.AbsoluteString)` |
| Using `https://` prefix in Domain | Domain should be hostname only (e.g., `tenant.auth0.com`, not `https://tenant.auth0.com`) |
| Passing Activity context to Auth0Client (Android pattern) | iOS does not need context — just `new Auth0Client(options)` |
| URL scheme not matching Bundle Identifier | The CFBundleURLSchemes value must exactly match the Bundle Identifier |
| Storing tokens in `UserDefaults` or only in memory | Use iOS Keychain via the `Security` framework (`SecKeyChain.Add`) for token persistence |

## Testing Notes

> **Agent instruction:** Remind the user to test on a physical device in addition to simulators. Some WebAuth/ASWebAuthenticationSession behaviors may differ on physical devices vs. simulators. Test the full login → callback → token flow on real hardware before shipping.

**Physical Device Testing:**
- Login flow: ASWebAuthenticationSession opens → authenticate → returns to app
- Callback: `OpenUrl` fires in AppDelegate with correct URL
- Logout flow: Browser opens → session cleared → returns to app
- Cancel: User dismisses sheet → app handles `UserCancel` gracefully

## Related Skills

- **auth0-maui** — .NET MAUI cross-platform apps (iOS + Android + Windows)
- **auth0-net-android** — .NET Android-only apps
- **auth0-swift** — iOS-only Swift apps
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
});

var loginResult = await client.LoginAsync();
BrowserResultType browserResult = await client.LogoutAsync();
```

> **Agent instruction:** Always include `offline_access` in the scope to enable refresh tokens. This allows the app to silently refresh access tokens without forcing the user to re-authenticate.
>
> **Agent instruction:** After login, always persist tokens to the iOS Keychain using the `Security` framework (`SecKeyChain.Add` with `SecAccessible.WhenUnlockedThisDeviceOnly`). Never store tokens in `UserDefaults` or leave them only in memory. Clear tokens on logout. See [Integration Patterns](./references/integration.md) for the full `SecureTokenStorage` helper class.

### Required Platform Configuration

These two pieces are required for the callback to work — see [Setup Guide](./references/setup.md) for full code:

1. **Info.plist**: Add `CFBundleURLSchemes` entry matching the Bundle Identifier
2. **AppDelegate**: Override `OpenUrl` and call `ActivityMediator.Instance.Send(url.AbsoluteString)`

For login with extra parameters, error handling, token refresh, user claims access, and complete ViewController examples, see [Integration Patterns](./references/integration.md).

## References

- [.NET Android & iOS Quickstart](https://auth0.com/docs/quickstart/native/net-android-ios)
- [GitHub Repository](https://github.com/auth0/auth0-oidc-client-net)
- [NuGet Package — Auth0.OidcClient.iOS](https://www.nuget.org/packages/Auth0.OidcClient.iOS)
- [SDK API Documentation](https://auth0.github.io/auth0-oidc-client-net/documentation/intro.html)
- [Auth0 Native App Documentation](https://auth0.com/docs/get-started/auth0-overview/create-applications/native-apps)
