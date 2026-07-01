# Integration Patterns

## Authentication Flow

The Auth0 .NET Android SDK uses the Authorization Code flow with PKCE via Chrome Custom Tabs:

1. App calls `LoginAsync()` → SDK opens Chrome Custom Tab to Auth0's `/authorize` endpoint
2. User authenticates in the browser (login page, social connections, MFA, etc.)
3. Auth0 redirects to the callback URL (e.g., `com.mycompany.myapp://{domain}/android/com.mycompany.myapp/callback`)
4. Android's IntentFilter intercepts the URL and delivers it to your Activity via `OnNewIntent`
5. `ActivityMediator.Instance.Send(intent.DataString)` completes the flow
6. SDK exchanges the code for tokens (access token, ID token, refresh token)
7. `LoginResult` returned to the app with tokens and user claims

## Login

### Basic Login

To integrate Auth0 login into your application, instantiate an instance of the `Auth0Client` class, configuring the Auth0 Domain, Client ID, and scope. Always include `offline_access` to receive refresh tokens:

```csharp
using Auth0.OidcClient;

var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    Scope = "openid profile email offline_access"
}, this);
```

Then, call the `LoginAsync` method which will redirect the user to the login screen. You will typically do this in the event handler for a UI control such as a Login button.

```csharp
var loginResult = await client.LoginAsync();
```

### Complete Activity Example

```csharp
using Android.App;
using Android.Content;
using Android.OS;
using Android.Widget;
using AndroidX.Security.Crypto;
using Auth0.OidcClient;
using System;
using System.Diagnostics;

namespace AndroidSample
{
    [Activity(Label = "AndroidSample", MainLauncher = true, Icon = "@drawable/icon",
        LaunchMode = LaunchMode.SingleTask)]
    [IntentFilter(
        new[] { Intent.ActionView },
        Categories = new[] { Intent.CategoryDefault, Intent.CategoryBrowsable },
        DataScheme = "YOUR_ANDROID_PACKAGE_NAME",
        DataHost = "YOUR_AUTH0_DOMAIN",
        DataPathPrefix = "/android/YOUR_ANDROID_PACKAGE_NAME/callback")]
    public class MainActivity : Auth0ClientActivity
    {
        private Auth0Client _auth0Client;
        private ISharedPreferences _securePrefs;

        protected override void OnCreate(Bundle bundle)
        {
            base.OnCreate(bundle);

            _auth0Client = new Auth0Client(new Auth0ClientOptions
            {
                Domain = "YOUR_AUTH0_DOMAIN",
                ClientId = "YOUR_AUTH0_CLIENT_ID",
                Scope = "openid profile email offline_access"
            }, this);

            // Use EncryptedSharedPreferences for secure token storage
            _securePrefs = EncryptedSharedPreferences.Create(
                "auth0_tokens",
                MasterKeys.GetOrCreate(MasterKeys.Aes256GcmSpec),
                this,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.Aes256Siv,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.Aes256Gcm);

            SetContentView(Resource.Layout.Main);
            FindViewById<Button>(Resource.Id.LoginButton).Click += LoginButtonOnClick;
            FindViewById<Button>(Resource.Id.LogoutButton).Click += LogoutButtonOnClick;
        }

        private async void LoginButtonOnClick(object sender, EventArgs eventArgs)
        {
            var loginResult = await _auth0Client.LoginAsync();

            if (loginResult.IsError)
            {
                Debug.WriteLine($"An error occurred during login: {loginResult.Error}");
                return;
            }

            // Store tokens securely
            var editor = _securePrefs.Edit();
            editor.PutString("access_token", loginResult.AccessToken);
            editor.PutString("refresh_token", loginResult.RefreshToken);
            editor.Apply();


            Debug.WriteLine($"name: {loginResult.User.FindFirst(c => c.Type == "name")?.Value}");
            Debug.WriteLine($"email: {loginResult.User.FindFirst(c => c.Type == "email")?.Value}");
        }

        private async void LogoutButtonOnClick(object sender, EventArgs e)
        {
            BrowserResultType browserResult = await _auth0Client.LogoutAsync();

            // Clear stored tokens on logout
            var editor = _securePrefs.Edit();
            editor.Clear();
            editor.Apply();
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

After login, Auth0 redirects back to your app via the callback URL. The IntentFilter on your Activity intercepts this and delivers it via `OnNewIntent`. See [Setup Guide — Platform Setup](./setup.md#platform-setup--intentfilter-configuration) for IntentFilter configuration details.

Two approaches to handle the callback:
- **Extend `Auth0ClientActivity`** — handles `OnNewIntent` automatically
- **Override `OnNewIntent` manually** — call `ActivityMediator.Instance.Send(intent.DataString)`

## Error Handling

### Authentication Error

You can check the `IsError` property of the result to see whether the login has failed. The `ErrorMessage` will contain more information regarding the error which occurred.

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
| `UserCancel` | User closed the browser | Handle gracefully — show login button again |
| `HttpError` | Network connectivity issue | Show retry option |
| `Unknown` | Callback URL mismatch | Verify IntentFilter matches Dashboard callback URL |
| `AccessDenied` | User blocked or rule denied access | Check Auth0 logs for details |

## Accessing the User's Information

The returned login result will indicate whether authentication was successful and if so contain the tokens and claims of the user.

### Accessing the tokens

On successful login, the login result will contain the ID Token and Access Token in the `IdentityToken` and `AccessToken` properties respectively.

```csharp
var loginResult = await client.LoginAsync();

if (!loginResult.IsError)
{
    Debug.WriteLine($"Authentication successful. Token expiration: {loginResult.AccessTokenExpiration}");
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

## Token Refresh

To refresh tokens silently (requires `offline_access` scope):

```csharp
var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    Scope = "openid profile email offline_access"
}, this);

// After login, store the refresh token
var loginResult = await client.LoginAsync();
var refreshToken = loginResult.RefreshToken;

// Later, refresh the tokens
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

## Secure Token Storage

Tokens must be stored securely. Never use plain `SharedPreferences` or in-memory variables for production apps. Use `EncryptedSharedPreferences` from AndroidX Security.

First, install the required package:

```bash
dotnet add package Xamarin.AndroidX.Security.SecurityCrypto
```

Then use it in your code:

```csharp
using AndroidX.Security.Crypto;

// Initialize encrypted storage
var securePrefs = EncryptedSharedPreferences.Create(
    "auth0_tokens",
    MasterKeys.GetOrCreate(MasterKeys.Aes256GcmSpec),
    this,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.Aes256Siv,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.Aes256Gcm);

// Store tokens after login
var editor = securePrefs.Edit();
editor.PutString("access_token", loginResult.AccessToken);
editor.PutString("refresh_token", loginResult.RefreshToken);
editor.Apply();

// Retrieve tokens
var storedAccessToken = securePrefs.GetString("access_token", null);
var storedRefreshToken = securePrefs.GetString("refresh_token", null);

// Clear on logout
securePrefs.Edit().Clear().Apply();
```

Alternatively, if using .NET MAUI Essentials compatibility, use `SecureStorage`:

```csharp
// Store
await SecureStorage.SetAsync("access_token", loginResult.AccessToken);
await SecureStorage.SetAsync("refresh_token", loginResult.RefreshToken);

// Retrieve
var accessToken = await SecureStorage.GetAsync("access_token");

// Clear on logout
SecureStorage.RemoveAll();
```
