# Integration Patterns

## Authentication Flow

The Auth0 MAUI SDK uses the Authorization Code flow with PKCE via the system browser:

1. App calls `LoginAsync()` → SDK opens system browser to Auth0's `/authorize` endpoint
2. User authenticates in the browser (login page, social connections, MFA, etc.)
3. Auth0 redirects to the callback URL (e.g., `myapp://callback`) with an authorization code
4. Platform-specific handler intercepts the URL and returns control to the app
5. SDK exchanges the code for tokens (access token, ID token, refresh token)
6. `LoginResult` returned to the app with tokens and user claims

## Login

### Basic Login

```csharp
var loginResult = await client.LoginAsync();

if (loginResult.IsError)
{
    // Handle error (user cancelled, network issue, etc.)
    Console.WriteLine($"Login error: {loginResult.ErrorDescription}");
    return;
}

// Access user information
var user = loginResult.User;
var name = user.FindFirst("name")?.Value;
var email = user.FindFirst("email")?.Value;
var picture = user.FindFirst("picture")?.Value;

// Access tokens
var accessToken = loginResult.AccessToken;
var idToken = loginResult.IdentityToken;
var refreshToken = loginResult.RefreshToken; // Requires offline_access scope
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

### Login with Custom Scopes

Configure scopes at client creation:

```csharp
var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    RedirectUri = "myapp://callback",
    PostLogoutRedirectUri = "myapp://callback",
    Scope = "openid profile email offline_access read:messages"
});
```

## Logout

### Basic Logout

```csharp
var result = await client.LogoutAsync();

if (result == BrowserResultType.Success)
{
    // Logged out successfully — clear local state
}
```

### Federated Logout

To also log the user out of their identity provider (e.g., Google, Microsoft):

```csharp
await client.LogoutAsync(federated: true);
```

## Token Refresh

To refresh tokens silently without user interaction, you need:
1. The `offline_access` scope in your initial configuration
2. The refresh token from the login result

```csharp
// After initial login, store the refresh token
var refreshToken = loginResult.RefreshToken;

// When the access token expires, refresh it
var refreshResult = await client.RefreshTokenAsync(refreshToken);

if (!refreshResult.IsError)
{
    var newAccessToken = refreshResult.AccessToken;
    var newIdToken = refreshResult.IdentityToken;

    // If refresh token rotation is enabled, save the new refresh token
    if (!string.IsNullOrEmpty(refreshResult.RefreshToken))
    {
        refreshToken = refreshResult.RefreshToken;
    }
}
else
{
    // Refresh failed — re-authenticate the user
    var loginResult = await client.LoginAsync();
}
```

### Secure Token Storage with MAUI SecureStorage

```csharp
// After login — persist refresh token
if (!string.IsNullOrEmpty(loginResult.RefreshToken))
{
    await SecureStorage.Default.SetAsync("auth0_refresh_token", loginResult.RefreshToken);
}

// On app startup — try to restore session
var storedRefreshToken = await SecureStorage.Default.GetAsync("auth0_refresh_token");
if (!string.IsNullOrEmpty(storedRefreshToken))
{
    var refreshResult = await client.RefreshTokenAsync(storedRefreshToken);
    if (!refreshResult.IsError)
    {
        // Session restored — user is logged in
        // Update stored token if rotated
        if (!string.IsNullOrEmpty(refreshResult.RefreshToken))
        {
            await SecureStorage.Default.SetAsync("auth0_refresh_token", refreshResult.RefreshToken);
        }
    }
    else
    {
        // Refresh failed — clear stored token, require login
        SecureStorage.Default.Remove("auth0_refresh_token");
    }
}

// On logout — clear stored tokens
SecureStorage.Default.Remove("auth0_refresh_token");
```

## User Profile

### Accessing Claims from LoginResult

```csharp
var loginResult = await client.LoginAsync();
if (!loginResult.IsError)
{
    var claims = loginResult.User.Claims;
    foreach (var claim in claims)
    {
        Console.WriteLine($"{claim.Type}: {claim.Value}");
    }

    // Common claims
    var sub = loginResult.User.FindFirst("sub")?.Value;
    var name = loginResult.User.FindFirst("name")?.Value;
    var email = loginResult.User.FindFirst("email")?.Value;
    var emailVerified = loginResult.User.FindFirst("email_verified")?.Value;
    var picture = loginResult.User.FindFirst("picture")?.Value;
}
```

### Getting Fresh User Info

If `LoadProfile` is set to `false` or you need updated user info after initial login:

```csharp
var userInfo = await client.GetUserInfoAsync(accessToken);
// userInfo.Claims contains the latest user profile data
```

## Organizations

### Login with Organization

```csharp
var loginResult = await client.LoginAsync(new { organization = "org_myOrg" });

// Verify the organization claim in the ID token
var orgId = loginResult.User.FindFirst("org_id")?.Value;
```

### Accept Organization Invitation

```csharp
var loginResult = await client.LoginAsync(new
{
    organization = "org_myOrg",
    invitation = "inv_abc123"
});
```

## Error Handling

### Login Errors

```csharp
var loginResult = await client.LoginAsync();

if (loginResult.IsError)
{
    switch (loginResult.Error)
    {
        case "access_denied":
            // User denied consent or was blocked by a rule
            await DisplayAlert("Access Denied", "You do not have permission to access this application.", "OK");
            break;
        default:
            if (loginResult.ErrorDescription?.Contains("canceled") == true ||
                loginResult.ErrorDescription?.Contains("cancelled") == true)
            {
                // User cancelled the login
                // No action needed — just show login button again
            }
            else
            {
                await DisplayAlert("Login Error", loginResult.ErrorDescription ?? "An unknown error occurred.", "OK");
            }
            break;
    }
}
```

### Logout Errors

```csharp
var result = await client.LogoutAsync();

switch (result)
{
    case BrowserResultType.Success:
        // Logout successful
        break;
    case BrowserResultType.UserCancel:
        // User cancelled — may still be logged in
        break;
    case BrowserResultType.HttpError:
    case BrowserResultType.UnknownError:
        // Logout failed — clear local state anyway
        SecureStorage.Default.Remove("auth0_refresh_token");
        break;
}
```

### Refresh Token Errors

```csharp
var refreshResult = await client.RefreshTokenAsync(refreshToken);

if (refreshResult.IsError)
{
    // Token may be expired or revoked — require re-authentication
    SecureStorage.Default.Remove("auth0_refresh_token");
    var loginResult = await client.LoginAsync();
}
```

## Platform-Specific Patterns

### MVVM Pattern (Recommended for MAUI)

```csharp
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

public partial class AuthViewModel : ObservableObject
{
    private readonly Auth0Client _auth0Client;

    [ObservableProperty]
    private bool _isAuthenticated;

    [ObservableProperty]
    private string _userName;

    [ObservableProperty]
    private string _userEmail;

    private string _refreshToken;

    public AuthViewModel()
    {
        _auth0Client = new Auth0Client(new Auth0ClientOptions
        {
            Domain = "YOUR_AUTH0_DOMAIN",
            ClientId = "YOUR_AUTH0_CLIENT_ID",
            RedirectUri = "myapp://callback",
            PostLogoutRedirectUri = "myapp://callback",
            Scope = "openid profile email offline_access"
        });
    }

    [RelayCommand]
    private async Task LoginAsync()
    {
        var result = await _auth0Client.LoginAsync();
        if (!result.IsError)
        {
            IsAuthenticated = true;
            UserName = result.User.FindFirst("name")?.Value;
            UserEmail = result.User.FindFirst("email")?.Value;
            _refreshToken = result.RefreshToken;

            if (!string.IsNullOrEmpty(_refreshToken))
            {
                await SecureStorage.Default.SetAsync("refresh_token", _refreshToken);
            }
        }
    }

    [RelayCommand]
    private async Task LogoutAsync()
    {
        await _auth0Client.LogoutAsync();
        IsAuthenticated = false;
        UserName = null;
        UserEmail = null;
        SecureStorage.Default.Remove("refresh_token");
    }

    [RelayCommand]
    private async Task TryRestoreSessionAsync()
    {
        var storedToken = await SecureStorage.Default.GetAsync("refresh_token");
        if (string.IsNullOrEmpty(storedToken)) return;

        var refreshResult = await _auth0Client.RefreshTokenAsync(storedToken);
        if (!refreshResult.IsError)
        {
            IsAuthenticated = true;
            // Optionally fetch user info
            var userInfo = await _auth0Client.GetUserInfoAsync(refreshResult.AccessToken);
            UserName = userInfo.Claims.FirstOrDefault(c => c.Type == "name")?.Value;
            UserEmail = userInfo.Claims.FirstOrDefault(c => c.Type == "email")?.Value;

            if (!string.IsNullOrEmpty(refreshResult.RefreshToken))
            {
                await SecureStorage.Default.SetAsync("refresh_token", refreshResult.RefreshToken);
            }
        }
        else
        {
            SecureStorage.Default.Remove("refresh_token");
        }
    }
}
```

### Dependency Injection with MauiProgram

Register the Auth0Client as a service:

```csharp
// MauiProgram.cs
public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder.UseMauiApp<App>();

        // Register Auth0 client
        builder.Services.AddSingleton(new Auth0Client(new Auth0ClientOptions
        {
            Domain = "YOUR_AUTH0_DOMAIN",
            ClientId = "YOUR_AUTH0_CLIENT_ID",
            RedirectUri = "myapp://callback",
            PostLogoutRedirectUri = "myapp://callback",
            Scope = "openid profile email offline_access"
        }));

        builder.Services.AddTransient<MainPage>();

        return builder.Build();
    }
}
```

Then inject in pages/view models:

```csharp
public partial class MainPage : ContentPage
{
    private readonly Auth0Client _auth0Client;

    public MainPage(Auth0Client auth0Client)
    {
        InitializeComponent();
        _auth0Client = auth0Client;
    }
}
```

## Calling an API with the Access Token

To call a protected API, request an audience during login and use the access token:

```csharp
// Login with API audience
var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    RedirectUri = "myapp://callback",
    PostLogoutRedirectUri = "myapp://callback",
    Scope = "openid profile email offline_access"
});

var loginResult = await client.LoginAsync(new
{
    audience = "https://my-api.example.com"
});

// Use the access token to call your API
using var httpClient = new HttpClient();
httpClient.DefaultRequestHeaders.Authorization =
    new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", loginResult.AccessToken);

var response = await httpClient.GetAsync("https://my-api.example.com/data");
```
