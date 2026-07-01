# Integration Patterns

## Authentication Flow

The Auth0 WPF SDK uses the Authorization Code flow with PKCE via WebView2:

1. App calls `LoginAsync()` → SDK opens a WebView2 popup window navigated to Auth0's `/authorize` endpoint
2. User authenticates in the WebView2 window (login page, social connections, MFA, etc.)
3. Auth0 redirects to the callback URL (`https://{yourDomain}/mobile`)
4. SDK intercepts the navigation, extracts the authorization code, and closes the window
5. SDK exchanges the code for tokens (access token, ID token, refresh token)
6. `LoginResult` returned to the app with tokens and user claims

## Login

### Basic Login (from quickstart)

**MainWindow.xaml:**

```xml
<Window x:Class="MyApp.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Auth0 WPF App" Height="450" Width="800">
    <Grid>
        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
            <Button x:Name="LoginButton" Content="Login" Width="200" Height="40"
                    Margin="10" Click="LoginButton_Click" FontSize="16"/>
            <Button x:Name="LogoutButton" Content="Logout" Width="200" Height="40"
                    Margin="10" Click="LogoutButton_Click" FontSize="16"/>
        </StackPanel>
    </Grid>
</Window>
```

**MainWindow.xaml.cs:**

```csharp
using System.Windows;
using Auth0.OidcClient;
using System.Diagnostics;

namespace MyApp;

public partial class MainWindow : Window
{
    private Auth0Client _client;

    public MainWindow()
    {
        InitializeComponent();

        _client = new Auth0Client(new Auth0ClientOptions
        {
            Domain = "{yourDomain}",
            ClientId = "{yourClientId}",
            Scope = "openid profile email offline_access"
        });
    }

    private async void LoginButton_Click(object sender, RoutedEventArgs e)
    {
        var loginResult = await _client.LoginAsync();

        if (loginResult.IsError)
        {
            Debug.WriteLine($"An error occurred during login: {loginResult.Error}");
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

    private async void LogoutButton_Click(object sender, RoutedEventArgs e)
    {
        await _client.LogoutAsync();
    }
}
```

### Login with Extra Parameters

```csharp
// Force a specific identity provider
var loginResult = await _client.LoginAsync(new { connection = "google-oauth2" });

// Login with an organization
var loginResult = await _client.LoginAsync(new { organization = "org_abc123" });

// Prompt for signup instead of login
var loginResult = await _client.LoginAsync(new { screen_hint = "signup" });

// Request an API audience
var loginResult = await _client.LoginAsync(new
{
    audience = "https://my-api.example.com"
});
```

## Logout

### Basic Logout

```csharp
private async void LogoutButton_Click(object sender, RoutedEventArgs e)
{
    await _client.LogoutAsync();
}
```

## User Profile

### Accessing Claims from LoginResult

```csharp
if (loginResult.IsError == false)
{
    var user = loginResult.User;
    var name = user.FindFirst(c => c.Type == "name")?.Value;
    var email = user.FindFirst(c => c.Type == "email")?.Value;
    var picture = user.FindFirst(c => c.Type == "picture")?.Value;

    Debug.WriteLine($"name: {name}");
    Debug.WriteLine($"email: {email}");
}

foreach (var claim in loginResult.User.Claims)
{
    Debug.WriteLine($"{claim.Type} = {claim.Value}");
}
```

## Token Refresh

To refresh tokens silently without user interaction, you need:
1. The `offline_access` scope in your initial configuration
2. The refresh token from the login result

```csharp
var refreshToken = loginResult.RefreshToken;
var refreshResult = await _client.RefreshTokenAsync(refreshToken);

if (refreshResult.IsError == false)
{
    var newAccessToken = refreshResult.AccessToken;
}
```

### Complete Token Refresh Pattern

```csharp
// After login, store the refresh token
var refreshToken = loginResult.RefreshToken;

// When the access token expires, refresh it
var refreshResult = await _client.RefreshTokenAsync(refreshToken);

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
    var loginResult = await _client.LoginAsync();
}
```

## Error Handling

### Login Errors

```csharp
var loginResult = await _client.LoginAsync();

if (loginResult.IsError)
{
    Debug.WriteLine($"An error occurred during login: {loginResult.Error}");
    Debug.WriteLine($"Description: {loginResult.ErrorDescription}");
    return;
}

Debug.WriteLine($"id_token: {loginResult.IdentityToken}");
Debug.WriteLine($"access_token: {loginResult.AccessToken}");
```

## Calling an API with the Access Token

To call a protected API, request an audience during login and use the access token:

```csharp
_client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "{yourDomain}",
    ClientId = "{yourClientId}",
    Scope = "openid profile email offline_access"
});

var loginResult = await _client.LoginAsync(new
{
    audience = "https://my-api.example.com"
});

// Use the access token to call your API
using var httpClient = new HttpClient();
httpClient.DefaultRequestHeaders.Authorization =
    new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", loginResult.AccessToken);

var response = await httpClient.GetAsync("https://my-api.example.com/data");
```

## Custom WebView2 Window

You can customize the WebView2 popup window appearance:

```csharp
using Auth0.OidcClient;
using System.Windows;

_client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "{yourDomain}",
    ClientId = "{yourClientId}",
    Scope = "openid profile email offline_access",
    Browser = new WebViewBrowser(
        title: "Login to My App",
        width: 800,
        height: 600
    )
});
```

Or provide a completely custom window factory:

```csharp
_client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "{yourDomain}",
    ClientId = "{yourClientId}",
    Scope = "openid profile email offline_access",
    Browser = new WebViewBrowser(() => new Window
    {
        Title = "Login",
        Width = 800,
        Height = 600,
        WindowStartupLocation = WindowStartupLocation.CenterScreen
    })
});
```
