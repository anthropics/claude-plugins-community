---
name: auth0-winforms
description: >
  Use when adding Auth0 login, logout, or token management to a Windows Forms (WinForms) desktop application. Integrates Auth0.OidcClient.WinForms — use even if the user says "add login to my WinForms app" or "add Auth0 to my Windows desktop app".
license: Apache-2.0
metadata:
  author: Auth0 SDKs Team <auth0-sdk-cdt@okta.com>
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/auth0-oidc-client-net
---

# Auth0 WinForms Integration

Add Auth0 authentication to Windows Forms (WinForms) desktop applications. This skill integrates the `Auth0.OidcClient.WinForms` NuGet package which uses WebView2 to display the Auth0 login page in a popup form for secure OIDC-based login and logout flows with PKCE.

The SDK performs WebAuth (OIDC authorization code flow with PKCE) by opening the Auth0 Universal Login page inside a WebView2 control hosted in a WinForms Form. Unlike native mobile SDKs that require URL scheme registration in Info.plist or AndroidManifest.xml, the WinForms SDK handles the callback entirely within the WebView2 navigation events — no custom URL Types or protocol handlers are needed.

> **Agent instruction:** Before providing SDK setup instructions, fetch the latest release version by running:
> ```bash
> gh api repos/auth0/auth0-oidc-client-net/releases --jq '[.[] | select(.tag_name | startswith("winforms-")) | .tag_name | ltrimstr("winforms-")] | .[0]'
> ```
> Use the returned version in all dependency lines instead of any hardcoded version below.

## Prerequisites

- .NET 6.0 SDK or later (WinForms requires Windows)
- Visual Studio 2022 or JetBrains Rider with .NET desktop development workload
- Windows 10 or later
- Microsoft Edge WebView2 Runtime (included with Windows 11, installable on Windows 10)
- Auth0 account with a Native application configured
- Node.js 20+ (for Auth0 CLI automated setup)

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| .NET MAUI cross-platform app | `auth0-maui` |
| WPF desktop app | `auth0-wpf` |
| ASP.NET Core server-side web app | `auth0-aspnetcore-authentication` |
| ASP.NET Core Web API (JWT validation) | `auth0-aspnetcore-api` |
| iOS-only Swift app | `auth0-swift` |
| Android-only Kotlin app | `auth0-android` |

## Quick Start Workflow

> **Agent instruction:** Before starting, examine the user's project:
> 1. Identify the .NET version from the `.csproj` file (`TargetFramework`)
> 2. Check if there is already an existing authentication provider in the codebase — search for existing `Auth0Client` or `WebViewBrowser` usage and reuse if found
> 3. Note the project's namespace and directory conventions

1. **Install SDK**: `dotnet add package Auth0.OidcClient.WinForms`
2. **Configure Auth0**: See [Setup Guide](./references/setup.md) for automatic or manual configuration.
3. **Integrate authentication**: Add `Auth0Client` initialization and wire login/logout to button click handlers.
4. **Build and verify**: `dotnet build`

> **Agent instruction:** When writing the Auth0Client configuration:
> - Use the exact code patterns from this skill's integration guide.
> - The SDK uses WebView2 to show the login page in a popup form — no custom browser setup needed.
> - The default callback URL is `https://{yourDomain}/mobile` — this must be added to Auth0 Dashboard Allowed Callback URLs and Allowed Logout URLs.
> - Unlike native mobile SDKs that use `https://{domain}/ios/{bundleId}/callback` or similar platform-specific patterns, WinForms uses the simpler `https://{domain}/mobile` callback format.
>
> After writing configuration and code, verify the build succeeds:
> ```bash
> dotnet build
> ```
> If the build fails, attempt to fix the issue. After 5-6 failed attempts, ask the user for help.

## Callback URL Configuration

The WinForms SDK uses `https://{yourDomain}/mobile` as its default callback URL. This differs from mobile native SDKs:

- **Mobile SDKs** use platform-specific callbacks like `https://{domain}/ios/{bundleId}/callback` or `https://{domain}/android/{packageName}/callback`
- **WPF/WinForms** use the generic `https://{yourDomain}/mobile` callback

The callback is intercepted by the WebView2 control's `NavigationStarting` event — no system-level URL scheme registration is required. You do NOT need to configure Info.plist, AndroidManifest.xml, or Windows protocol handlers.

Configure in the Auth0 Dashboard:
- **Allowed Callback URLs**: `https://{yourDomain}/mobile`
- **Allowed Logout URLs**: `https://{yourDomain}/mobile`

## Done When

- [ ] `Auth0.OidcClient.WinForms` package installed
- [ ] `Auth0Client` configured with Domain and ClientId
- [ ] Login/logout flow working (WebView2 popup opens for authentication)
- [ ] User profile claims accessible after login
- [ ] Callback URL `https://{yourDomain}/mobile` registered in Auth0 Dashboard
- [ ] Build succeeds with no errors
- [ ] Tested on real device (physical Windows machine, not just remote desktop)

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 tenant configuration, SDK installation, callback URL setup
- **[Integration Patterns](./references/integration.md)** — Login/logout flows, token refresh, user profile, error handling
- **[API Reference & Testing](./references/api.md)** — Full `Auth0ClientOptions` reference, claims, testing checklist, troubleshooting

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| App type not set to **Native** in Auth0 Dashboard | Change application type to "Native" in Dashboard settings |
| Missing callback URL in Auth0 Dashboard | Add `https://{yourDomain}/mobile` to both Allowed Callback URLs AND Allowed Logout URLs |
| Using `https://` prefix in Domain config | Domain should be hostname only (e.g., `tenant.auth0.com`, not `https://tenant.auth0.com`) |
| WebView2 Runtime not installed | Install Microsoft Edge WebView2 Runtime on Windows 10 (included with Windows 11) |
| Not requesting `offline_access` scope for token refresh | Add `offline_access` to `Scope` in `Auth0ClientOptions` |
| Storing ClientSecret in code | Native apps do NOT use a Client Secret — remove it |
| Trying to register URL scheme in registry/manifest | WinForms uses WebView2 in-process — no URL scheme registration needed (unlike MAUI which needs AppxManifest) |

## Testing Notes

> **Agent instruction:** Remind the user to test on a physical device. Some WebView2 behaviors (popup windows, certificate handling) may differ in remote desktop or virtual machine environments vs. physical Windows machines. Test the full login → WebView2 → callback → token flow on real hardware before shipping.

**Testing Checklist:**
- Login flow: Click login → WebView2 popup opens → authenticate → popup closes → user info displayed
- Logout flow: Click logout → WebView2 popup opens → session cleared → popup closes
- Token refresh: `RefreshTokenAsync` with stored refresh token works
- Cancel: User closes WebView2 form → app handles `UserCancel` gracefully
- Physical device: Test on a real Windows machine (not just virtual environment)
- Multiple logins: Verify login works after logout (no stale state)

## Related Skills

- **auth0-wpf** — WPF desktop apps
- **auth0-maui** — .NET MAUI cross-platform apps
- **auth0-aspnetcore-authentication** — ASP.NET Core server-side web apps
- **auth0-aspnetcore-api** — ASP.NET Core Web API with JWT validation

## Quick Reference

```csharp
using Auth0.OidcClient;
using System.Diagnostics;

// Initialize client
var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "{yourDomain}",
    ClientId = "{yourClientId}",
    Scope = "openid profile email offline_access"
});

// Login — opens WebView2 popup form (WebAuth flow with PKCE)
var loginResult = await client.LoginAsync();
if (loginResult.IsError == false)
{
    var user = loginResult.User;
    var name = user.FindFirst(c => c.Type == "name")?.Value;
    var email = user.FindFirst(c => c.Type == "email")?.Value;
    var picture = user.FindFirst(c => c.Type == "picture")?.Value;

    Debug.WriteLine($"name: {name}");
    Debug.WriteLine($"email: {email}");

    foreach (var claim in loginResult.User.Claims)
    {
        Debug.WriteLine($"{claim.Type} = {claim.Value}");
    }
}

// Logout
await client.LogoutAsync();

// Refresh token (requires offline_access scope)
var refreshToken = loginResult.RefreshToken;
var refreshResult = await client.RefreshTokenAsync(refreshToken);
if (refreshResult.IsError == false)
{
    var newAccessToken = refreshResult.AccessToken;
}
```

### Form1.cs (WinForms Complete Example)

```csharp
using Auth0.OidcClient;
using System.Diagnostics;

namespace MyApp;

public partial class Form1 : Form
{
    private Auth0Client _client;
    private Button loginButton;
    private Button logoutButton;

    public Form1()
    {
        InitializeComponent();

        _client = new Auth0Client(new Auth0ClientOptions
        {
            Domain = "{yourDomain}",
            ClientId = "{yourClientId}",
            Scope = "openid profile email offline_access"
        });

        loginButton = new Button
        {
            Text = "Log In",
            Width = 120,
            Height = 40,
            Left = (ClientSize.Width - 120) / 2,
            Top = (ClientSize.Height - 40) / 2
        };
        loginButton.Click += loginButton_Click;
        Controls.Add(loginButton);

        logoutButton = new Button
        {
            Text = "Log Out",
            Width = 120,
            Height = 40,
            Left = (ClientSize.Width - 120) / 2,
            Top = (ClientSize.Height - 40) / 2 + 50
        };
        logoutButton.Click += logoutButton_Click;
        Controls.Add(logoutButton);
    }

    private async void loginButton_Click(object sender, EventArgs e)
    {
        var loginResult = await _client.LoginAsync();

        if (loginResult.IsError)
        {
            Debug.WriteLine($"Error: {loginResult.Error}");
            Debug.WriteLine($"Description: {loginResult.ErrorDescription}");
            return;
        }

        var user = loginResult.User;
        var name = user.FindFirst(c => c.Type == "name")?.Value;
        var email = user.FindFirst(c => c.Type == "email")?.Value;
        var picture = user.FindFirst(c => c.Type == "picture")?.Value;

        Debug.WriteLine($"name: {name}");
        Debug.WriteLine($"email: {email}");

        foreach (var claim in loginResult.User.Claims)
        {
            Debug.WriteLine($"{claim.Type} = {claim.Value}");
        }
    }

    private async void logoutButton_Click(object sender, EventArgs e)
    {
        await _client.LogoutAsync();
    }
}
```

## References

- [Auth0 WPF/WinForms Quickstart](https://auth0.com/docs/quickstart/native/wpf-winforms)
- [GitHub Repository](https://github.com/auth0/auth0-oidc-client-net)
- [NuGet Package](https://www.nuget.org/packages/Auth0.OidcClient.WinForms)
- [SDK API Documentation](https://auth0.github.io/auth0-oidc-client-net/documentation/intro.html)
- [Auth0 Native App Documentation](https://auth0.com/docs/get-started/auth0-overview/create-applications/native-apps)
