# auth0-net-android Setup Guide

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

Below automates the setup using the Auth0 CLI. This creates a Native application configured for .NET Android with the correct callback URLs.

**Before running this setup, ask the user for explicit confirmation to proceed.**

### Step 1: Check for existing Auth0 configuration

Check whether the project already has Auth0 credentials configured:

```bash
grep -r "Auth0ClientOptions\|Auth0Client\|YOUR_AUTH0_DOMAIN" --include="*.cs" . 2>/dev/null | head -5
```

If existing configuration is found, inform the user and ask whether to overwrite or keep existing credentials.

### Step 2: Determine package name

```bash
grep -r "applicationId\|ApplicationId\|<RootNamespace>" --include="*.csproj" --include="*.xml" . 2>/dev/null | head -5
```

Use the package name to construct callback URLs. The package name must be lowercase.

### Step 3: Run automated setup (only after confirmation)

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

# Set package name (replace with actual package name)
PACKAGE_NAME="com.mycompany.myapplication"

# Construct callback URL
CALLBACK_URL="$PACKAGE_NAME://$DOMAIN/android/$PACKAGE_NAME/callback"

echo "Callback URL: $CALLBACK_URL"
echo ""

# Ask user to pick existing app or create new
echo "Existing Native applications:"
auth0 apps list --json 2>/dev/null | jq -r '.[] | select(.app_type == "native") | "\(.client_id) - \(.name)"' || echo "  (none found)"
echo ""
echo "Creating new Native application for .NET Android..."

# Create the application
APP_JSON=$(auth0 apps create \
    --name "My .NET Android App" \
    --type native \
    --auth-method none \
    --callbacks "$CALLBACK_URL" \
    --logout-urls "$CALLBACK_URL" \
    --json)

CLIENT_ID=$(echo "$APP_JSON" | jq -r '.client_id')

echo ""
echo "=== Auth0 Configuration ==="
echo "Domain:       $DOMAIN"
echo "Client ID:    $CLIENT_ID"
echo "Callback URL: $CALLBACK_URL"
echo ""
echo "=== Setup Complete ==="
```

After the script runs, remind the user to:
1. Replace `YOUR_AUTH0_DOMAIN` and `YOUR_AUTH0_CLIENT_ID` placeholders in code with the output values
2. Replace `YOUR_ANDROID_PACKAGE_NAME` in the IntentFilter with their actual lowercase package name

## Manual Setup

If credentials are NOT in the prompt and user declines automated setup:

1. Ask for Auth0 Domain and Client ID
2. Ask for the application's Package Name (from `.csproj` or `AndroidManifest.xml`)
3. Write the Auth0Client configuration directly into the Activity

**Auth0 Dashboard instructions:**
1. Go to [Auth0 Dashboard](https://manage.auth0.com/#/applications)
2. Create a new application, select **Native** as the type
3. In Settings → Application URIs:
   - **Allowed Callback URLs**: `yourpackagename://{domain}/android/yourpackagename/callback`
   - **Allowed Logout URLs**: `yourpackagename://{domain}/android/yourpackagename/callback`
4. Under Advanced Settings → OAuth: ensure "JsonWebToken Signature Algorithm" is `RS256` and "OIDC Conformant" is enabled
5. Note the **Domain** and **Client ID** values

## SDK Installation

Install the AndroidX package (required for .NET 6+):

Using Package Manager Console:

```text
Install-Package Auth0.OidcClient.AndroidX
```

Or using .NET CLI:

```bash
dotnet add package Auth0.OidcClient.AndroidX
```

> **Note:** `Auth0.OidcClient.Android` (non-AndroidX) relies on deprecated support libraries and does not work on .NET 6+. Always use `Auth0.OidcClient.AndroidX`.

## Platform Setup — IntentFilter Configuration

After installing the SDK, configure the Activity to handle the Auth0 callback. There are two approaches:

**Option A: Extend `Auth0ClientActivity`** (recommended — handles callback automatically):

```csharp
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
    // Auth0ClientActivity handles OnNewIntent automatically
}
```

**Option B: Manual `OnNewIntent` override:**

Use the same Activity/IntentFilter attributes as above, but extend `Activity` and override `OnNewIntent`:

```csharp
protected override async void OnNewIntent(Intent intent)
{
    base.OnNewIntent(intent);
    Auth0.OidcClient.ActivityMediator.Instance.Send(intent.DataString);
}
```

**Key requirements:**
- Replace `YOUR_ANDROID_PACKAGE_NAME` with the actual lowercase package name (e.g., `com.mycompany.myapplication`)
- All `DataScheme`, `DataHost`, and `DataPathPrefix` values must be lowercase
- `LaunchMode = LaunchMode.SingleTask` is required — prevents duplicate Activity instances on callback

## Post-Setup Steps

After installing the SDK and configuring the IntentFilter:

1. **Register URL scheme**: Configure the `IntentFilter` on your Activity with correct `DataScheme` (lowercase package name), `DataHost` (Auth0 domain), and `DataPathPrefix` (`/android/{packagename}/callback`)
2. **Set LaunchMode**: Add `LaunchMode = LaunchMode.SingleTask` to the Activity attribute
3. **Handle callback**: Override `OnNewIntent` and call `ActivityMediator.Instance.Send(intent.DataString)`, or extend `Auth0ClientActivity`
4. **Add INTERNET permission**: Ensure `AndroidManifest.xml` has `<uses-permission android:name="android.permission.INTERNET" />`
5. **Build to verify**: Run `dotnet build` to confirm no compilation errors

## Post-Setup Verification

After configuration, verify:

1. The `DataScheme` in IntentFilter is lowercase
2. The callback URL in Auth0 Dashboard matches the IntentFilter pattern exactly
3. `LaunchMode.SingleTask` is set on the Activity
4. Build succeeds: `dotnet build`

## Secret Management

.NET Android apps are **Native** applications — no client secret is needed. Only `Domain` and `ClientId` are required. These are public values (visible in the app binary) and are not secrets.
