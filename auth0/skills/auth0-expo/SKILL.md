---
name: auth0-expo
description: >
  Use when adding Auth0 login, logout, or session management to an Expo app. Integrates react-native-auth0 with the Expo Config Plugin for native iOS/Android builds — use even if the user says "add login to my Expo app" without mentioning the SDK. Do not use for bare React Native CLI projects.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
    requires:
      bins:
        - gh
---

# Auth0 Expo Integration

Add authentication to Expo (React Native) applications using `react-native-auth0` with the Expo Config Plugin.

## Prerequisites

- Expo SDK 53 or higher (react-native-auth0 v5.x requires Expo 53+)
- React 19 and React Native 0.78.0 or higher
- Auth0 account with a **Native** application configured
- If Auth0 is not set up yet, use the `auth0-quickstart` skill first
- **Not compatible with Expo Go** — requires custom development client or EAS Build

## When NOT to Use

| Use Case | Recommended Skill |
|----------|------------------|
| Bare React Native CLI project (no Expo) | `auth0-react-native` |
| React web SPA (Vite/CRA) | `auth0-react` |
| Next.js application | `auth0-nextjs` |
| Vue.js SPA | `auth0-vue` |
| Angular SPA | `auth0-angular` |
| Express.js backend | `auth0-express` |
| Native Android (Kotlin/Java) | `auth0-android` |
| Backend API (JWT validation) | `auth0-fastify-api` or `auth0-express` |

## Quick Start Workflow

### 1. Configure Auth0

**For automated setup with Auth0 CLI**, see [Setup Guide](./references/setup.md) for complete scripts.

**For manual setup**, configure a **Native** application in the [Auth0 Dashboard](https://manage.auth0.com/) and note your Domain and Client ID.

### 2. Verify Expo Dev Client

> **Agent instruction:** Before installing the Auth0 SDK, check if the project has `expo-dev-client` installed. Read the project's `package.json` and look for `expo-dev-client` in `dependencies` or `devDependencies`.
>
> - **If `expo-dev-client` is found:** Proceed to step 3.
> - **If `expo-dev-client` is NOT found:** Use `AskUserQuestion` with the following message:
>
>   "The `react-native-auth0` SDK requires a custom Expo development client — it does **not** work with Expo Go. Your project does not have `expo-dev-client` installed.
>
>   How would you like to proceed?
>   1. **Install it for me** — I'll run `npx expo install expo-dev-client` and continue setup
>   2. **I'll set it up myself** — skip this step and continue to Auth0 SDK installation"
>
>   If the user picks option 1, run:
>   ```bash
>   npx expo install expo-dev-client
>   ```
>   Then proceed to step 3. If option 2, proceed to step 3 directly.

### 3. Install SDK

```bash
npx expo install react-native-auth0
```

### 4. Configure Expo Config Plugin

Add the react-native-auth0 plugin to `app.json` (or `app.config.js`) with your Auth0 domain and a custom scheme. Also ensure `bundleIdentifier` (iOS) and `package` (Android) are set:

```json
{
  "expo": {
    "ios": { "bundleIdentifier": "com.yourcompany.yourapp" },
    "android": { "package": "com.yourcompany.yourapp" },
    "plugins": [
      ["react-native-auth0", {
        "domain": "YOUR_AUTH0_DOMAIN",
        "customScheme": "YOUR_CUSTOM_SCHEME"
      }]
    ]
  }
}
```

The `customScheme` must be all lowercase with no special characters (e.g., `auth0sample`). See [**Setup Guide**](./references/setup.md) for HTTPS callbacks, multiple domains, EAS Build, and secret management.

### 5. Configure Callback URLs

Add to **Allowed Callback URLs** and **Allowed Logout URLs** in the [Auth0 Dashboard](https://manage.auth0.com/):

```text
YOUR_CUSTOM_SCHEME://YOUR_AUTH0_DOMAIN/ios/YOUR_BUNDLE_ID/callback,
YOUR_CUSTOM_SCHEME://YOUR_AUTH0_DOMAIN/android/YOUR_PACKAGE/callback
```

All values must be **lowercase** with **no trailing slash**. For HTTPS callback URLs (App Links / Universal Links), see [Setup Guide](./references/setup.md#using-https-callback-urls-android-app-links).

### 6. Add Authentication with Auth0Provider

Wrap your app with `Auth0Provider` and use the `useAuth0` hook:

> **Agent instruction:** Before adding new UI elements, search the project for existing click handlers for login, logout, sign-in, or sign-out buttons. If existing handlers are found, hook the Auth0 code into them. Only create new buttons if no existing handlers are found.

```typescript
import React from 'react';
import { Auth0Provider, useAuth0 } from 'react-native-auth0';
import { View, Button, Text, ActivityIndicator } from 'react-native';

function HomeScreen() {
  const { authorize, clearSession, user, isLoading, error } = useAuth0();

  const login = async () => {
    try {
      await authorize(
        { scope: 'openid profile email' },
        { customScheme: 'YOUR_CUSTOM_SCHEME' }
      );
    } catch (e) {
      console.error('Login error:', e);
    }
  };

  const logout = async () => {
    try {
      await clearSession({ customScheme: 'YOUR_CUSTOM_SCHEME' });
    } catch (e) {
      console.error('Logout error:', e);
    }
  };

  if (isLoading) {
    return <ActivityIndicator size="large" />;
  }

  return (
    <View>
      {user ? (
        <>
          <Text>Welcome, {user.name}!</Text>
          <Text>{user.email}</Text>
          <Button title="Log Out" onPress={logout} />
        </>
      ) : (
        <Button title="Log In" onPress={login} />
      )}
      {error && <Text>{error.message}</Text>}
    </View>
  );
}

export default function App() {
  return (
    <Auth0Provider
      domain="YOUR_AUTH0_DOMAIN"
      clientId="YOUR_AUTH0_CLIENT_ID"
    >
      <HomeScreen />
    </Auth0Provider>
  );
}
```

### 7. Build & Verify

> **Agent instruction:** After completing the integration, build the project to verify it compiles:
> ```bash
> npx expo prebuild --clean
> npx expo run:ios
> # or
> npx expo run:android
> ```
> If the build fails, analyze the error output. Common integration build failures include:
> - **"Invariant Violation: Native module cannot be null"**: Using Expo Go instead of a development build — run `npx expo run:ios` or `npx expo run:android` instead of `npx expo start`
> - **Plugin not applied**: Missing `react-native-auth0` in app.json plugins array — verify the plugin configuration
> - **Pod install fails (iOS)**: Run `npx expo prebuild --clean` to regenerate native projects
> - **Manifest merge failure (Android)**: Conflicting auth0Domain placeholder — ensure only the config plugin sets the domain
>
> Re-run the build after each fix. Track the number of build-fix iterations.
>
> **Failcheck:** If the build still fails after 5–6 fix attempts, stop and ask the user using `AskUserQuestion`:
> _"The build is still failing after several fix attempts. How would you like to proceed?"_
> - **Let the skill continue fixing iteratively**
> - **Fix it manually** — show the remaining errors
> - **Skip build verification** — proceed without a successful build

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Dev client requirement, automated setup, Expo config plugin, callback URLs, EAS Build, secret management
- **[Integration Patterns](./references/integration.md)** — Login/logout, credential management, biometric auth, token refresh, organizations, DPoP, error handling
- **[API Reference & Testing](./references/api.md)** — Configuration options, useAuth0 hook API, testing checklist, common issues, security

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using Expo Go instead of development build | react-native-auth0 requires native code. Use `npx expo run:ios` / `npx expo run:android` or create a development build with EAS. |
| Missing `customScheme` in authorize/clearSession calls | Pass `{ customScheme: 'your-scheme' }` as the second argument to `authorize()` and `clearSession()`. Must match the value in app.json plugin config. |
| Callback URL mismatch | Ensure callback URL is all lowercase, no trailing slash, and matches Auth0 Dashboard exactly: `{customScheme}://{domain}/ios/{bundleId}/callback` |
| App type not set to Native | The Auth0 application must be type **Native** in the Dashboard, not SPA or Regular Web. |
| Missing bundleIdentifier or package in app.json | Both `expo.ios.bundleIdentifier` and `expo.android.package` must be set in app.json for callback URLs to work. |
| Forgot to wrap app with Auth0Provider | All components using `useAuth0()` must be children of `Auth0Provider`. |
| Using react-native-auth0 v5.x with Expo < 53 | Version 5.x requires Expo 53+. Use v4.x for older Expo versions. |
| Not testing on physical device | Biometric authentication (Face ID, fingerprint) only works on a physical device, not simulators. Always test the full auth flow on a real device before release. |

## Related Skills

- [auth0-quickstart](/auth0-quickstart) — Set up an Auth0 account and application
- [auth0-react-native](/auth0-react-native) — Bare React Native CLI projects
- [auth0-mfa](/auth0-mfa) — Configure multi-factor authentication
- [auth0-cli](/auth0-cli) — Manage Auth0 resources from the terminal

## References

- [Auth0 Expo Quickstart](https://auth0.com/docs/quickstart/native/react-native-expo/interactive)
- [react-native-auth0 GitHub Repository](https://github.com/auth0/react-native-auth0)
- [react-native-auth0 API Documentation](https://auth0.github.io/react-native-auth0/)
- [Expo Sample App](https://github.com/auth0-samples/auth0-react-native-sample/tree/master/00-Login-Expo)
- [EXAMPLES.md](https://github.com/auth0/react-native-auth0/blob/master/EXAMPLES.md)
