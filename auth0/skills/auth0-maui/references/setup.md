# auth0-maui Setup Guide

## Auth0 Configuration

> **Agent instruction:**
>
> **Credential check (always first):**
> If the user's prompt already provides Auth0 credentials (domain, client ID), use them directly — do NOT ask the user to re-confirm. Go straight to writing the Auth0Client configuration and proceeding with integration.
>
> If credentials are NOT in the prompt, ask the user:
> - Question: "How would you like to configure Auth0 for this project?"
> - Options: "Automatic setup (Recommended) — Auth0 CLI creates the app and writes credentials" / "Manual setup — I'll provide my credentials"
>
> Follow the matching section below based on their choice.

## Quick Setup (Automated)

Below automates the setup using the Auth0 CLI. This creates a Native application configured for MAUI with the correct callback URLs.

**Before running this setup, ask the user for explicit confirmation to proceed.**

### Step 1: Check for existing Auth0 configuration

Check whether the project already has Auth0 credentials configured:

```bash
grep -r "Auth0ClientOptions\|Auth0Client\|YOUR_AUTH0_DOMAIN" --include="*.cs" . 2>/dev/null | head -5
```

If existing configuration is found, inform the user and ask whether to overwrite or keep existing credentials.

### Step 2: Run automated setup (only after confirmation)

```bash
#!/bin/bash
set -e

# Check if Auth0 CLI is installed
if ! command -v auth0 &> /dev/null; then
    echo "Auth0 CLI not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install auth0
    else
        curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh -s -- -b /usr/local/bin
    fi
fi

# Check if already logged in
if ! auth0 tenants list &> /dev/null; then
    echo "Please log in to your Auth0 tenant:"
    auth0 login
fi

# Get tenant domain
DOMAIN=$(auth0 tenants list --json 2>/dev/null | jq -r '.[0].domain // empty')
if [ -z "$DOMAIN" ]; then
    echo "Error: Could not determine Auth0 domain. Run 'auth0 login' first."
    exit 1
fi

echo "Using Auth0 tenant: $DOMAIN"
echo ""

# Ask user to pick existing app or create new
echo "Existing Native applications:"
auth0 apps list --json 2>/dev/null | jq -r '.[] | select(.app_type == "native") | "\(.client_id) - \(.name)"' || echo "  (none found)"
echo ""
echo "Creating new Native application for MAUI..."

# Create the application
APP_JSON=$(auth0 apps create \
    --name "My MAUI App" \
    --type native \
    --auth-method none \
    --callbacks "myapp://callback" \
    --logout-urls "myapp://callback" \
    --json)

CLIENT_ID=$(echo "$APP_JSON" | jq -r '.client_id')

echo ""
echo "=== Auth0 Configuration ==="
echo "Domain:    $DOMAIN"
echo "Client ID: $CLIENT_ID"
echo ""
echo "Use these values in your Auth0Client configuration:"
echo ""
echo "var client = new Auth0Client(new Auth0ClientOptions"
echo "{"
echo "    Domain = \"$DOMAIN\","
echo "    ClientId = \"$CLIENT_ID\","
echo "    RedirectUri = \"myapp://callback\","
echo "    PostLogoutRedirectUri = \"myapp://callback\","
echo "    Scope = \"openid profile email offline_access\""
echo "});"
echo ""
echo "=== Setup Complete ==="
```

After the script runs, remind the user to:
- Set up the Android `WebAuthenticatorCallbackActivity` (see Post-Setup Steps)
- Set up the Windows protocol in `Package.appxmanifest` (see Post-Setup Steps)
- The callback scheme (`myapp`) can be customized — update both code and Auth0 Dashboard if changed

## Manual Setup

If the user provides credentials or prefers manual setup:

1. **Create a Native application** in the [Auth0 Dashboard](https://manage.auth0.com/#/applications):
   - Click "Create Application"
   - Name: Your app name
   - Type: **Native**
   - Click "Create"

2. **Configure application URLs** in the Settings tab:
   - **Allowed Callback URLs**: `myapp://callback`
   - **Allowed Logout URLs**: `myapp://callback`

3. **Verify OAuth settings** under "Advanced Settings" → "OAuth" tab:
   - "JsonWebToken Signature Algorithm" set to **RS256**
   - "OIDC Conformant" is **enabled**

4. **Note credentials** from the "Basic Information" section:
   - Domain (e.g., `your-tenant.auth0.com`)
   - Client ID

5. **Configure the SDK** in your code:

```csharp
var client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "YOUR_AUTH0_DOMAIN",
    ClientId = "YOUR_AUTH0_CLIENT_ID",
    RedirectUri = "myapp://callback",
    PostLogoutRedirectUri = "myapp://callback",
    Scope = "openid profile email offline_access"
});
```

## Post-Setup Steps (Required for All Paths)

### Android: Register Callback Activity

Create a new file (e.g., `Platforms/Android/WebAuthenticatorActivity.cs`):

```csharp
using Android.App;
using Android.Content;
using Android.Content.PM;

namespace MyMauiApp.Platforms.Android;

[Activity(NoHistory = true, LaunchMode = LaunchMode.SingleTop, Exported = true)]
[IntentFilter(new[] { Intent.ActionView },
    Categories = new[] { Intent.CategoryDefault, Intent.CategoryBrowsable },
    DataScheme = CALLBACK_SCHEME)]
public class WebAuthenticatorActivity : Microsoft.Maui.Authentication.WebAuthenticatorCallbackActivity
{
    const string CALLBACK_SCHEME = "myapp";
}
```

> **Important:** The `DataScheme` value must match the scheme portion of your `RedirectUri` (e.g., `myapp` for `myapp://callback`).

### Windows: Register Protocol and Handle Activation

1. **Add protocol to `Platforms/Windows/Package.appxmanifest`**:

```xml
<Applications>
  <Application Id="App" Executable="$targetnametoken$.exe" EntryPoint="$targetentrypoint$">
    <Extensions>
      <uap:Extension Category="windows.protocol">
        <uap:Protocol Name="myapp"/>
      </uap:Extension>
    </Extensions>
  </Application>
</Applications>
```

2. **Handle redirection in `Platforms/Windows/App.xaml.cs`**:

```csharp
using Auth0.OidcClient.Platforms.Windows;

namespace MyMauiApp.WinUI;

public partial class App : MauiWinUIApplication
{
    public App()
    {
        if (Activator.Default.CheckRedirectionActivation())
            return;

        this.InitializeComponent();
    }

    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
```

> **Critical:** `CheckRedirectionActivation()` must be called **before** `InitializeComponent()`. If called after, the app may launch a new instance instead of handling the callback.

### iOS / macOS

No additional platform configuration is required for iOS and macOS. MAUI's `WebAuthenticator` handles the callback automatically via Universal Links and ASWebAuthenticationSession.

### Verify Setup

After completing platform-specific setup, run a build to confirm everything compiles:

```bash
dotnet build
```

## SDK Installation

Install the Auth0 OIDC Client MAUI package:

```bash
dotnet add package Auth0.OidcClient.MAUI
```

Or add directly to your `.csproj`:

```xml
<ItemGroup>
    <PackageReference Include="Auth0.OidcClient.MAUI" Version="1.4.0" />
</ItemGroup>
```

> **Agent instruction:** Replace `1.4.0` with the version fetched from the GitHub API.

### Verify Installation

```bash
dotnet restore
dotnet build
```

## Secret Management

MAUI (Native) applications do **not** use a Client Secret. The Auth0 application must be configured as type "Native" with `token_endpoint_auth_method` set to `none`.

Credentials needed in code:
- **Domain** — Your Auth0 tenant domain (safe to include in source code)
- **Client ID** — Your application's Client ID (safe to include in source code)

> Neither Domain nor Client ID are secrets for native applications. They are embedded in the compiled app and visible in network traffic. Security comes from PKCE, not client secrets.

For storing **user tokens** securely at runtime, use MAUI's `SecureStorage`:

```csharp
// Store refresh token
await SecureStorage.Default.SetAsync("refresh_token", loginResult.RefreshToken);

// Retrieve refresh token
var storedToken = await SecureStorage.Default.GetAsync("refresh_token");
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `auth0` CLI not found after install | Restart terminal or add install path to `$PATH` |
| `auth0 login` hangs | Try `auth0 login --no-input` or use `--domain` flag directly |
| Build error: "Platform not supported" | Ensure `.csproj` includes MAUI target frameworks (`net8.0-android`, `net8.0-ios`, etc.) |
| NuGet restore fails | Run `dotnet nuget locals all --clear` then `dotnet restore` |
| Android emulator can't reach Auth0 | Ensure emulator has internet access; use `10.0.2.2` for localhost APIs |

## Verification

After setup, verify the integration is working:

1. Build the project: `dotnet build`
2. Run on a target platform (e.g., Android emulator or iOS simulator)
3. Tap login → Auth0 login page opens in system browser
4. Authenticate → redirected back to app with user info
5. Tap logout → session cleared, redirected back
