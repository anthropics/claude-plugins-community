# auth0-winforms Setup Guide

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

Below automates the setup using the Auth0 CLI. This creates a Native application configured for WinForms with the correct callback URLs.

**Before running this setup, ask the user for explicit confirmation to proceed.**

### Step 1: Check for existing Auth0 configuration

Check whether the project already has Auth0 credentials configured:

```bash
grep -r "Auth0ClientOptions\|Auth0Client\|YOUR_AUTH0_DOMAIN\|yourDomain" --include="*.cs" . 2>/dev/null | head -5
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
read -rp "Enter an existing client_id to reuse, or press Enter to create a new app: " EXISTING_CLIENT_ID

if [ -n "$EXISTING_CLIENT_ID" ]; then
    APP_JSON=$(auth0 apps show "$EXISTING_CLIENT_ID" --json 2>/dev/null)
    if [ -z "$APP_JSON" ] || [ "$(echo "$APP_JSON" | jq -r '.client_id // empty')" = "" ]; then
        echo "Error: Could not retrieve app with client_id '$EXISTING_CLIENT_ID'."
        exit 1
    fi
    echo "Reusing existing application: $(echo "$APP_JSON" | jq -r '.name')"
else
    echo "Creating new Native application for WinForms..."
    APP_JSON=$(auth0 apps create \
        --name "My WinForms App" \
        --type native \
        --auth-method none \
        --callbacks "https://$DOMAIN/mobile" \
        --logout-urls "https://$DOMAIN/mobile" \
        --json)
fi

CLIENT_ID=$(echo "$APP_JSON" | jq -r '.client_id')

echo ""
echo "=== Auth0 Configuration ==="
echo "Domain:    $DOMAIN"
echo "Client ID: $CLIENT_ID"
echo ""
echo "Use these values in your Auth0Client configuration:"
echo ""
echo "_client = new Auth0Client(new Auth0ClientOptions"
echo "{"
echo "    Domain = \"$DOMAIN\","
echo "    ClientId = \"$CLIENT_ID\","
echo "    Scope = \"openid profile email offline_access\""
echo "});"
echo ""
echo "=== Setup Complete ==="
```

## Manual Setup

If the user provides credentials or prefers manual setup:

1. **Create a Native application** in the [Auth0 Dashboard](https://manage.auth0.com/#/applications):
   - Click "Create Application"
   - Name: Your app name
   - Type: **Native**
   - Click "Create"

2. **Configure application URLs** in the Settings tab:
   - **Allowed Callback URLs**: `https://{yourDomain}/mobile`
   - **Allowed Logout URLs**: `https://{yourDomain}/mobile`

3. **Note credentials** from the "Basic Information" section:
   - Domain (e.g., `your-tenant.auth0.com`)
   - Client ID

4. **Configure the SDK** in your code:

```csharp
_client = new Auth0Client(new Auth0ClientOptions
{
    Domain = "{yourDomain}",
    ClientId = "{yourClientId}",
    Scope = "openid profile email offline_access"
});
```

## Post-Setup Steps

### Verify WebView2 Runtime

The WinForms SDK requires the Microsoft Edge WebView2 Runtime. It is included with Windows 11 but may need to be installed separately on Windows 10:

- Download from: https://developer.microsoft.com/en-us/microsoft-edge/webview2/
- Or install via the Evergreen Bootstrapper in your app installer

### Verify Callback URLs

The default callback URL for the WinForms SDK is `https://{yourDomain}/mobile`. This URL must be:
1. Added to **Allowed Callback URLs** in the Auth0 Dashboard
2. Added to **Allowed Logout URLs** in the Auth0 Dashboard

### Verify Setup

After completing setup, run a build to confirm everything compiles:

```bash
dotnet build
```

## SDK Installation

Install the Auth0 OIDC Client WinForms package:

```bash
dotnet add package Auth0.OidcClient.WinForms
```

Or via the Package Manager Console:

```powershell
Install-Package Auth0.OidcClient.WinForms
```

Or add directly to your `.csproj`:

```xml
<ItemGroup>
    <PackageReference Include="Auth0.OidcClient.WinForms" Version="4.4.0" />
</ItemGroup>
```

> **Agent instruction:** Replace `4.4.0` with the version fetched from the GitHub API.

### Verify Installation

```bash
dotnet restore
dotnet build
```

## Secret Management

WinForms (Native) applications do **not** use a Client Secret. The Auth0 application must be configured as type "Native" with `token_endpoint_auth_method` set to `none`.

Credentials needed in code:
- **Domain** — Your Auth0 tenant domain (safe to include in source code)
- **Client ID** — Your application's Client ID (safe to include in source code)

> Neither Domain nor Client ID are secrets for native applications. They are embedded in the compiled app. Security comes from PKCE, not client secrets.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `auth0` CLI not found after install | Restart terminal or add install path to `$PATH` |
| `auth0 login` hangs | Try `auth0 login --no-input` or use `--domain` flag directly |
| Build error: WebView2 not found | Install Microsoft Edge WebView2 Runtime or add `Microsoft.Web.WebView2` NuGet package |
| NuGet restore fails | Run `dotnet nuget locals all --clear` then `dotnet restore` |
