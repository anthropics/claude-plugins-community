# Integration Patterns

## Authentication Flow

The Auth0 .NET iOS SDK uses the Authorization Code flow with PKCE via ASWebAuthenticationSession:

1. App calls `LoginAsync()` → SDK opens ASWebAuthenticationSession to Auth0's `/authorize` endpoint
2. User authenticates in the browser (login page, social connections, MFA, etc.)
3. Auth0 redirects to the callback URL (e.g., `com.mycompany.myapp://{domain}/ios/com.mycompany.myapp/callback`)
4. iOS intercepts the URL scheme and delivers it to `AppDelegate.OpenUrl`
5. `ActivityMediator.Instance.Send(url.AbsoluteString)` completes the flow
6. SDK exchanges the code for tokens (access token, ID token, refresh token)
7. `LoginResult` returned to the app with tokens and user claims

## Login

### Basic Login

To integrate Auth0 login into your application, instantiate an instance of the `Auth0Client` class, configuring the Auth0 Domain and Client ID:

```csharp
using Auth0.OidcClient;

var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID"
});
```

Then, call the `LoginAsync` method which will redirect the user to the login screen. You will typically do this in the event handler for a UI control such as a Login button.

```csharp
var loginResult = await client.LoginAsync();
```

### Complete ViewController Example

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

            if (loginResult.IsError)
            {
                Debug.WriteLine($"An error occurred during login: {loginResult.Error}");
                return;
            }

            Debug.WriteLine($"name: {loginResult.User.FindFirst(c => c.Type == "name")?.Value}");
            Debug.WriteLine($"email: {loginResult.User.FindFirst(c => c.Type == "email")?.Value}");
        }
    }
}
```

### Login with Extra Parameters

```csharp
// Force a specific identity provider
var loginResult = await client.LoginAsync(new { connection = "google-oauth2" });

// Login with an organization
var loginResult = await client.LoginAsync(new { organization = "org_abc123" });

// Login with invitation
var loginResult = await client.LoginAsync(new
{
    organization = "org_abc123",
    invitation = "inv_xyz789"
});

// Prompt for signup instead of login
var loginResult = await client.LoginAsync(new { screen_hint = "signup" });

// Request an API audience
var loginResult = await client.LoginAsync(new
{
    audience = "https://my-api.example.com"
});
```

## Handling the Callback

After a user has logged in, they will be redirected back to your application at the **Callback URL** that was registered.

### Step 1: Register URL scheme in Info.plist

Register the URL scheme for your Callback URL which your application should handle:

1. Open your application's `Info.plist` file in Visual Studio for Mac, and go to the **Advanced** tab.
2. Under **URL Types**, click the **Add URL Type** button
3. Set the **Identifier** as `Auth0`, the **URL Schemes** the same as your application's **Bundle Identifier**, and the **Role** as `None`

This is an example of the XML representation of your `Info.plist` file after you have added the URL Type:

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
            <string>YOUR_BUNDLE_IDENTIFIER</string>
        </array>
    </dict>
</array>
```

### Step 2: Handle callback in AppDelegate

You need to handle the Callback URL in the `OpenUrl` event in your `AppDelegate` class. You need to notify the Auth0 OIDC Client to finish the authentication flow by calling the `Send` method of the `ActivityMediator` singleton, passing along the URL that was sent in:

```csharp
using Auth0.OidcClient;

[Register("AppDelegate")]
public class AppDelegate : UIApplicationDelegate
{
    // Modern signature (preferred for .NET 8+/iOS 9+)
    public override bool OpenUrl(UIApplication app, NSUrl url, NSDictionary options)
    {
        ActivityMediator.Instance.Send(url.AbsoluteString);

        return true;
    }
}
```

> **Note:** The legacy overload `OpenUrl(UIApplication application, NSUrl url, string sourceApplication, NSObject annotation)` also works for older projects.

## Error Handling

### Authentication Error

You can check the `IsError` property of the result to see whether the login has failed. Inspect `LoginResult.Error` for the error type and `LoginResult.ErrorDescription` for human-readable details.

```csharp
var loginResult = await client.LoginAsync();

if (loginResult.IsError)
{
    Debug.WriteLine($"An error occurred during login: {loginResult.Error}");
}
```

### Common Error Scenarios

| Error | Cause | Fix |
|-------|-------|-----|
| `UserCancel` | User closed the browser/dismissed the sheet | Handle gracefully — show login button again |
| `HttpError` | Network connectivity issue | Show retry option |
| `Unknown` | Callback URL mismatch | Verify Info.plist URL scheme matches Dashboard callback URL |
| `AccessDenied` | User blocked or rule denied access | Check Auth0 logs for details |

## Accessing the User's Information

The returned login result will indicate whether authentication was successful and if so contain the tokens and claims of the user.

### Accessing the tokens

On successful login, the login result will contain the ID Token and Access Token in the `IdentityToken` and `AccessToken` properties respectively.

```csharp
var loginResult = await client.LoginAsync();

if (!loginResult.IsError)
{
    Debug.WriteLine($"Login successful");
}
```

### Obtaining the User Information

On successful login, the login result will contain the user information in the `User` property, which is a `ClaimsPrincipal`.

To obtain information about the user, you can query the claims. You can, for example, obtain the user's name and email address from the `name` and `email` claims:

```csharp
if (!loginResult.IsError)
{
    Debug.WriteLine($"name: {loginResult.User.FindFirst(c => c.Type == "name")?.Value}");
    Debug.WriteLine($"email: {loginResult.User.FindFirst(c => c.Type == "email")?.Value}");
}
```

You can obtain a list of all the claims contained in the ID Token by iterating through the `Claims` collection:

```csharp
if (!loginResult.IsError)
{
    foreach (var claim in loginResult.User.Claims)
    {
        Debug.WriteLine($"{claim.Type} = {claim.Value}");
    }
}
```

## Logout

To log the user out call the `LogoutAsync` method.

```csharp
BrowserResultType browserResult = await client.LogoutAsync();
```

### Federated Logout

To also log the user out of their identity provider:

```csharp
var browserResult = await client.LogoutAsync(federated: true);
```

## Secure Token Storage (iOS Keychain)

**Always persist tokens in the iOS Keychain** — never store them in `UserDefaults`, plain files, or in-memory variables only. The `Security` framework provides direct Keychain access in .NET iOS:

```csharp
using Security;
using Foundation;

public static class SecureTokenStorage
{
    private const string ServiceName = "com.mycompany.myapp.auth0";

    public static void SaveToken(string key, string token)
    {
        // Remove any existing entry first
        var removeQuery = new SecRecord(SecKind.GenericPassword)
        {
            Service = ServiceName,
            Account = key
        };
        SecKeyChain.Remove(removeQuery);

        // Add the new token
        var record = new SecRecord(SecKind.GenericPassword)
        {
            Service = ServiceName,
            Account = key,
            ValueData = NSData.FromString(token),
            Accessible = SecAccessible.WhenUnlockedThisDeviceOnly
        };
        SecKeyChain.Add(record);
    }

    public static string? GetToken(string key)
    {
        var query = new SecRecord(SecKind.GenericPassword)
        {
            Service = ServiceName,
            Account = key
        };

        var status = SecKeyChain.QueryAsRecord(query, out var match);
        if (status == SecStatusCode.Success && match?.ValueData != null)
        {
            return NSString.FromData(match.ValueData, NSStringEncoding.UTF8)?.ToString();
        }
        return null;
    }

    public static void RemoveToken(string key)
    {
        var query = new SecRecord(SecKind.GenericPassword)
        {
            Service = ServiceName,
            Account = key
        };
        SecKeyChain.Remove(query);
    }
}
```

### Storing tokens after login

```csharp
var loginResult = await client.LoginAsync();

if (!loginResult.IsError)
{
    SecureTokenStorage.SaveToken("access_token", loginResult.AccessToken);
    SecureTokenStorage.SaveToken("id_token", loginResult.IdentityToken);

    if (!string.IsNullOrEmpty(loginResult.RefreshToken))
    {
        SecureTokenStorage.SaveToken("refresh_token", loginResult.RefreshToken);
    }
}
```

### Clearing tokens on logout

```csharp
await client.LogoutAsync();

SecureTokenStorage.RemoveToken("access_token");
SecureTokenStorage.RemoveToken("id_token");
SecureTokenStorage.RemoveToken("refresh_token");
```

## Token Refresh

To refresh tokens silently (requires `offline_access` scope):

```csharp
var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    Scope = "openid profile email offline_access"
});

// After login, store the refresh token securely
var loginResult = await client.LoginAsync();
if (!loginResult.IsError)
{
    SecureTokenStorage.SaveToken("refresh_token", loginResult.RefreshToken);
}

// Later, refresh the tokens using the stored refresh token
var storedRefreshToken = SecureTokenStorage.GetToken("refresh_token");
if (storedRefreshToken != null)
{
    var refreshResult = await client.RefreshTokenAsync(storedRefreshToken);
    if (!refreshResult.IsError)
    {
        SecureTokenStorage.SaveToken("access_token", refreshResult.AccessToken);
        // Update stored refresh token if rotated
        if (!string.IsNullOrEmpty(refreshResult.RefreshToken))
        {
            SecureTokenStorage.SaveToken("refresh_token", refreshResult.RefreshToken);
        }
    }
}
```

## ASWebAuthenticationSession Options

For custom browser configuration (e.g., ephemeral sessions that don't share cookies):

```csharp
var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    Browser = new ASWebAuthenticationSessionBrowser(
        new ASWebAuthenticationSessionOptions
        {
            PrefersEphemeralWebBrowserSession = true
        }
    )
});
```

Setting `PrefersEphemeralWebBrowserSession = true` means the browser won't share cookies with Safari, so the user will always be prompted to log in (no SSO).

## Get User Info from /userinfo Endpoint

```csharp
var userInfo = await client.GetUserInfoAsync(accessToken);

if (!userInfo.IsError)
{
    foreach (var claim in userInfo.Claims)
    {
        Debug.WriteLine($"{claim.Type} = {claim.Value}");
    }
}
```
