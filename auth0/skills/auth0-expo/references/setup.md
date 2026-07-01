# auth0-expo Setup Guide

## Table of Contents

- [Auth0 Configuration](#auth0-configuration) — Credential check, automatic vs manual setup
- [Expo Dev Client Requirement](#expo-dev-client-requirement) — Why Expo Go doesn't work, install steps
- [Post-Setup Steps](#post-setup-steps) — Verify plugin config, callback URLs, regenerate native projects
- [SDK Installation](#sdk-installation) — Version compatibility
- [Using HTTPS Callback URLs](#using-https-callback-urls-android-app-links) — Android App Links
- [Multiple Domain Support](#multiple-domain-support) — Staging/production configs
- [Secret Management](#secret-management) — What to store, what not to store, dynamic config
- [EAS Build Configuration](#eas-build-configuration) — Development and production builds
- [Verification](#verification) — Plugin, build, and auth flow checks

## Auth0 Configuration

> **Agent instruction:**
>
> **Important:** Never echo Auth0 credentials (domain, client ID) in your response text. Write them directly into config files using the Write or Edit tool.
>
> **Credential check (always first):**
> If the user's prompt already provides Auth0 credentials (domain, client ID), use them directly — do NOT call `AskUserQuestion` to re-confirm. Go straight to writing the app.json config and proceeding with integration.
>
> **If credentials are NOT provided**, use `AskUserQuestion` to ask:
> "How would you like to configure Auth0 for this Expo project?"
> - Option A: "Automatic setup (recommended)" — uses the Auth0 CLI to create your app
> - Option B: "Manual setup" — provide Auth0 credentials manually
>
> **If Automatic Setup (Option A):**
>
> 1. **Pre-flight checks:**
>    - Verify Auth0 CLI is installed: `command -v auth0`
>    - Verify logged in: `auth0 tenants list --csv --no-input`
>    - If any check fails, guide user to install/login, or fall back to manual setup
>
> 2. **Read the project's app.json** to extract:
>    - `expo.name` (for the Auth0 app name)
>    - `expo.scheme` (custom scheme — if missing, derive one from app name, lowercase, no special chars)
>    - `expo.ios.bundleIdentifier` (for iOS callback URL)
>    - `expo.android.package` (for Android callback URL)
>
> 3. **Create the Auth0 Native application:**
>    ```bash
>    auth0 apps create \
>      --name "APP_NAME-expo" \
>      --type native \
>      --auth-method none \
>      --callbacks "SCHEME://DOMAIN/ios/BUNDLE_ID/callback,SCHEME://DOMAIN/android/PACKAGE/callback" \
>      --logout-urls "SCHEME://DOMAIN/ios/BUNDLE_ID/callback,SCHEME://DOMAIN/android/PACKAGE/callback" \
>      --json --no-input
>    ```
>    Parse the JSON output to extract `client_id` and `domain`.
>
> 4. **Enable database connection** for the new client:
>    ```bash
>    auth0 api get "connections" --query "name=Username-Password-Authentication" --no-input
>    ```
>    Parse the response to extract the connection `id` and its current `enabled_clients` array. Append the new client_id to the existing array and patch:
>    ```bash
>    auth0 api patch "connections/CONNECTION_ID" --data '{"enabled_clients":["EXISTING_IDS...", "NEW_CLIENT_ID"]}' --no-input
>    ```
>    If it doesn't exist, create it:
>    ```bash
>    auth0 api post "connections" --data '{"strategy":"auth0","name":"Username-Password-Authentication","enabled_clients":["CLIENT_ID"]}' --no-input
>    ```
>
> 5. **Write the plugin config to app.json** using the Edit tool — add `react-native-auth0` to the plugins array with the domain and custom scheme. Do not echo credentials in your response.
>
> **If Manual Setup (Option B):**
>
> Ask the user for their Auth0 credentials:
> - Auth0 Domain (e.g., `your-tenant.auth0.com`)
> - Client ID (32-character alphanumeric string)
>
> Then write the configuration to app.json using the Edit tool and proceed with integration.

## Expo Dev Client Requirement

The `react-native-auth0` SDK uses native modules and **does not work with Expo Go**. A custom Expo development client is required.

> **Agent instruction:** Before proceeding with Auth0 SDK installation, check the project's `package.json` for `expo-dev-client` in `dependencies` or `devDependencies`. If not found, ask the user how they'd like to proceed (install automatically or set it up themselves). See SKILL.md step 1 for the full agent instruction.

### Check for expo-dev-client

```bash
# Check if expo-dev-client is in the project
cat package.json | grep expo-dev-client
```

### Install expo-dev-client (if missing)

```bash
npx expo install expo-dev-client
```

After installing, the development workflow changes from `npx expo start` (Expo Go) to:

```bash
npx expo run:ios
# or
npx expo run:android
```

For cloud builds, use EAS Build with a development profile:

```bash
eas build --profile development --platform ios
eas build --profile development --platform android
```

## Post-Setup Steps

After Auth0 is configured (via automatic or manual setup), complete these steps:

### 1. Verify app.json Plugin Configuration

Ensure `app.json` contains the react-native-auth0 plugin:

```json
{
  "expo": {
    "ios": {
      "bundleIdentifier": "com.yourcompany.yourapp"
    },
    "android": {
      "package": "com.yourcompany.yourapp"
    },
    "plugins": [
      [
        "react-native-auth0",
        {
          "domain": "your-tenant.auth0.com",
          "customScheme": "auth0sample"
        }
      ]
    ]
  }
}
```

The `customScheme` must be:
- All lowercase
- No special characters
- Unique to your application
- Passed to `authorize()` and `clearSession()` calls

### 2. Configure Callback URLs in Auth0 Dashboard

Go to [Auth0 Dashboard > Applications](https://manage.auth0.com/#/applications), select your application, and add the following:

**Allowed Callback URLs:**
```text
auth0sample://your-tenant.auth0.com/ios/com.yourcompany.yourapp/callback,
auth0sample://your-tenant.auth0.com/android/com.yourcompany.yourapp/callback
```

**Allowed Logout URLs:**
```text
auth0sample://your-tenant.auth0.com/ios/com.yourcompany.yourapp/callback,
auth0sample://your-tenant.auth0.com/android/com.yourcompany.yourapp/callback
```

Replace `auth0sample` with your `customScheme`, `your-tenant.auth0.com` with your domain, and `com.yourcompany.yourapp` with your bundle ID / package name.

All values must be **lowercase** with **no trailing slash**.

### 3. Regenerate Native Projects

After modifying app.json, regenerate the native projects:

```bash
npx expo prebuild --clean
```

This applies the Auth0 config plugin, which configures:
- **iOS**: URL scheme in Info.plist and AppDelegate linking handler
- **Android**: manifest placeholders for auth0Domain and auth0Scheme in build.gradle

## SDK Installation

```bash
npx expo install react-native-auth0
```

This installs the SDK with the correct version for your Expo SDK.

For older Expo versions:
- Expo 53+: Use react-native-auth0 v5.x
- Expo < 53: Use react-native-auth0 v4.x (`npx expo install react-native-auth0@4`)

## Using HTTPS Callback URLs (Android App Links)

For enhanced security, you can use HTTPS callback URLs with Android App Links:

```json
{
  "expo": {
    "plugins": [
      [
        "react-native-auth0",
        {
          "domain": "your-tenant.auth0.com",
          "customScheme": "https"
        }
      ]
    ]
  }
}
```

When using `customScheme: "https"`, the plugin automatically adds `android:autoVerify="true"` to the Android manifest intent-filter.

You must also configure Android App Links in the Auth0 Dashboard:
1. Go to **Applications > your app > Show Advanced Settings > Device Settings**
2. Add your Android Package Name and SHA256 fingerprint

## Multiple Domain Support

To support multiple Auth0 domains (e.g., for staging/production), pass an array to the plugin:

```json
{
  "expo": {
    "plugins": [
      [
        "react-native-auth0",
        [
          {
            "domain": "staging.auth0.com",
            "customScheme": "auth0staging"
          },
          {
            "domain": "production.auth0.com",
            "customScheme": "auth0prod"
          }
        ]
      ]
    ]
  }
}
```

## Secret Management

Expo / React Native mobile apps do **not** use a Client Secret. The Auth0 Native application type uses PKCE (Proof Key for Code Exchange) for secure authentication without exposing secrets.

**What to store in code / config:**
- Auth0 Domain — in `app.json` plugin config and `Auth0Provider` props
- Auth0 Client ID — in `Auth0Provider` props only (not in app.json)
- Custom Scheme — in `app.json` plugin config and `authorize`/`clearSession` options

**What NOT to store:**
- Never include Client Secret in mobile apps
- Never commit sensitive tokens to source control

For environment-specific configuration, use `app.config.js` (dynamic config):

```javascript
export default ({ config }) => ({
  ...config,
  plugins: [
    [
      'react-native-auth0',
      {
        domain: process.env.AUTH0_DOMAIN || 'dev.auth0.com',
        customScheme: process.env.AUTH0_SCHEME || 'auth0dev',
      },
    ],
  ],
});
```

## EAS Build Configuration

For production builds with EAS:

```bash
npm install -g eas-cli
eas build --platform all
```

Create `eas.json` if it doesn't exist:

```json
{
  "cli": {
    "version": ">= 3.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal"
    },
    "production": {}
  }
}
```

For development builds (used instead of Expo Go):

```bash
eas build --profile development --platform ios
eas build --profile development --platform android
```

## Verification

After setup, verify the integration:

1. **Plugin applied correctly:**
   ```bash
   npx expo prebuild --clean
   ```
   Check that `ios/{AppName}/Info.plist` contains the URL scheme and `android/app/build.gradle` contains `manifestPlaceholders`.

2. **Build succeeds:**
   ```bash
   npx expo run:ios
   # or
   npx expo run:android
   ```

3. **Auth flow works:**
   - Tap Login — browser opens with Auth0 Universal Login
   - Complete login — app receives credentials and shows user info
   - Tap Logout — session is cleared
