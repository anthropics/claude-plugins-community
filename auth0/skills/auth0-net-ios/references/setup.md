# auth0-net-ios Setup Guide

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

Below automates the setup using the Auth0 CLI. This creates a Native application configured for .NET iOS with the correct callback URLs.

**Before running this setup, ask the user for explicit confirmation to proceed.**

### Step 1: Check for existing Auth0 configuration

Check whether the project already has Auth0 credentials configured:

```bash
grep -r "Auth0ClientOptions\|Auth0Client\|YOUR_AUTH0_DOMAIN" --include="*.cs" . 2>/dev/null | head -5
```

If existing configuration is found, inform the user and ask whether to overwrite or keep existing credentials.

### Step 2: Determine Bundle Identifier

```bash
grep -r "CFBundleIdentifier\|BundleIdentifier\|ApplicationId" --include="*.plist" --include="*.csproj" . 2>/dev/null | head -5
```

Use the Bundle Identifier to construct callback URLs.

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

# Attempt to extract bundle identifier from project files
BUNDLE_ID=""

# Try .csproj ApplicationId first (most common in .NET iOS projects)
if [ -z "$BUNDLE_ID" ]; then
    BUNDLE_ID=$(grep -rh '<ApplicationId>' --include="*.csproj" . 2>/dev/null | head -1 | sed 's/.*<ApplicationId>\(.*\)<\/ApplicationId>.*/\1/' | xargs)
fi

# Try Info.plist CFBundleIdentifier
if [ -z "$BUNDLE_ID" ]; then
    BUNDLE_ID=$(grep -A1 'CFBundleIdentifier' --include="*.plist" -r . 2>/dev/null | grep '<string>' | head -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | xargs)
fi

# If still not found, prompt the user
if [ -z "$BUNDLE_ID" ] || [[ "$BUNDLE_ID" == *'$('* ]]; then
    echo "Could not detect Bundle Identifier from project files."
    read -p "Enter your Bundle Identifier (e.g., com.mycompany.myapplication): " BUNDLE_ID
    if [ -z "$BUNDLE_ID" ]; then
        echo "Error: Bundle Identifier is required."
        exit 1
    fi
fi

echo "Using Bundle Identifier: $BUNDLE_ID"

# Construct callback URL
CALLBACK_URL="$BUNDLE_ID://$DOMAIN/ios/$BUNDLE_ID/callback"

echo "Callback URL: $CALLBACK_URL"
echo ""

# Ask user to pick existing app or create new
echo "Existing Native applications:"
auth0 apps list --json 2>/dev/null | jq -r '.[] | select(.app_type == "native") | "\(.client_id) - \(.name)"' || echo "  (none found)"
echo ""
echo "Creating new Native application for .NET iOS..."

# Create the application
APP_JSON=$(auth0 apps create \
    --name "My .NET iOS App" \
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
2. Ensure the Bundle Identifier in `Info.plist` matches the `CFBundleURLSchemes` entry

## Manual Setup

If credentials are NOT in the prompt and user declines automated setup:

1. Ask for Auth0 Domain and Client ID
2. Ask for the application's Bundle Identifier (from `Info.plist`)
3. Write the Auth0Client configuration directly

**Auth0 Dashboard instructions:**
1. Go to [Auth0 Dashboard](https://manage.auth0.com/#/applications)
2. Create a new application, select **Native** as the type
3. In Settings → Application URIs:
   - **Allowed Callback URLs**: `yourbundleid://{domain}/ios/yourbundleid/callback`
   - **Allowed Logout URLs**: `yourbundleid://{domain}/ios/yourbundleid/callback`
4. Under Advanced Settings → OAuth: ensure "JsonWebToken Signature Algorithm" is `RS256` and "OIDC Conformant" is enabled
5. Note the **Domain** and **Client ID** values

## SDK Installation

Using Package Manager Console:

```text
Install-Package Auth0.OidcClient.iOS
```

Or using .NET CLI:

```bash
dotnet add package Auth0.OidcClient.iOS
```

## Platform Setup — Info.plist URL Scheme Registration

After installing the SDK, register the URL scheme so iOS can redirect back to your app after authentication.

### Step 1: Register URL scheme in Info.plist

Open your application's `Info.plist` file in Visual Studio for Mac, and go to the **Advanced** tab. Under **URL Types**, click the **Add URL Type** button. Set the **Identifier** as `Auth0`, the **URL Schemes** the same as your application's **Bundle Identifier**, and the **Role** as `None`.

This is the XML representation of the `Info.plist` entry:

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

> **Note:** The legacy overload `OpenUrl(UIApplication application, NSUrl url, string sourceApplication, NSObject annotation)` also works for older projects. Both deliver the callback URL to `ActivityMediator`.

## Post-Setup Steps

After installing the SDK and configuring Info.plist:

1. **Register URL scheme**: Add `CFBundleURLSchemes` entry in `Info.plist` matching your Bundle Identifier
2. **Handle callback**: Implement `OpenUrl` in `AppDelegate` and call `ActivityMediator.Instance.Send(url.AbsoluteString)`
3. **Verify Bundle Identifier**: Ensure the URL scheme, callback URL in Dashboard, and Bundle Identifier all match
4. **Build to verify**: Run `dotnet build` to confirm no compilation errors

## Post-Setup Verification

After configuration, verify:

1. The `CFBundleURLSchemes` in `Info.plist` matches the Bundle Identifier exactly
2. The callback URL in Auth0 Dashboard matches the pattern `{bundleId}://{domain}/ios/{bundleId}/callback`
3. The `AppDelegate` has the `OpenUrl` handler
4. Build succeeds: `dotnet build`

## Secret Management

.NET iOS apps are **Native** applications — no client secret is needed. Only `Domain` and `ClientId` are required. These are public values (visible in the app binary) and are not secrets.
