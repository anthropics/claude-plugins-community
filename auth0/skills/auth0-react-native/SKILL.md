---
name: auth0-react-native
description: >
  Use when adding Auth0 login, logout, or biometric auth to a bare React Native app (not Expo). Integrates react-native-auth0 with native deep linking.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 React Native Integration

Add authentication to React Native and Expo mobile applications using react-native-auth0.

---

## Prerequisites

- React Native or Expo application
- Auth0 account and application configured as Native type
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Expo managed workflow** - Use `auth0-expo` skill for Expo apps with config plugin
- **React web applications** - Use `auth0-react` skill for SPAs (Vite/CRA)
- **React Server Components** - Use `auth0-nextjs` for Next.js applications
- **Non-React native apps** - Use platform-specific SDKs (Swift for iOS, Kotlin for Android)
- **Backend APIs** - Use JWT validation libraries for your server language

---

## Quick Start Workflow

### 1. Install SDK

**Expo:**
```bash
npx expo install react-native-auth0
```

**React Native CLI:**
```bash
npm install react-native-auth0
npx pod-install  # iOS only
```

### 2. Configure Environment

**For automated setup with Auth0 CLI**, see [Setup Guide](references/setup.md) for complete scripts.

**For manual setup:**

Create `.env`:

```bash
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your-client-id
```

### 3. Configure Native Platforms

**iOS** - Update `ios/{YourApp}/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>None</string>
    <key>CFBundleURLName</key>
    <string>auth0</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER).auth0</string>
    </array>
  </dict>
</array>
```

**Android** - Update `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name="com.auth0.android.provider.RedirectActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:host="YOUR_AUTH0_DOMAIN"
            android:pathPrefix="/android/${applicationId}/callback"
            android:scheme="${applicationId}" />
    </intent-filter>
</activity>
```

**Expo** - Update `app.json`:

```json
{
  "expo": {
    "scheme": "your-app-scheme",
    "ios": {
      "bundleIdentifier": "com.yourcompany.yourapp"
    },
    "android": {
      "package": "com.yourcompany.yourapp"
    }
  }
}
```

### 4. Add Authentication with Auth0Provider

Wrap your app with `Auth0Provider`:

```typescript
import React from 'react';
import { Auth0Provider } from 'react-native-auth0';
import App from './App';

export default function Root() {
  return (
    <Auth0Provider
      domain={process.env.AUTH0_DOMAIN}
      clientId={process.env.AUTH0_CLIENT_ID}
    >
      <App />
    </Auth0Provider>
  );
}
```

### 5. Use the useAuth0 Hook

```typescript
import React from 'react';
import { View, Button, Text, ActivityIndicator } from 'react-native';
import { useAuth0 } from 'react-native-auth0';

export default function App() {
  const { user, authorize, clearSession, isLoading } = useAuth0();

  const login = async () => {
    try {
      await authorize({
        scope: 'openid profile email'
      });
    } catch (error) {
      console.error('Login error:', error);
    }
  };

  const logout = async () => {
    try {
      await clearSession();
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  if (isLoading) {
    return <ActivityIndicator />;
  }

  return (
    <View>
      {user ? (
        <>
          <Text>Welcome, {user.name}!</Text>
          <Text>{user.email}</Text>
          <Button title="Logout" onPress={logout} />
        </>
      ) : (
        <Button title="Login" onPress={login} />
      )}
    </View>
  );
}
```

### 6. Test Authentication

**Expo:**
```bash
npx expo start
```

**React Native:**
```bash
npx react-native run-ios
# or
npx react-native run-android
```

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup, native configuration, deep linking
- **[Patterns Guide](references/patterns.md)** - Secure storage, biometric auth, token refresh
- **[API Reference](references/api.md)** - Complete SDK API, methods, configuration options

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgot to wrap app with Auth0Provider | All components using useAuth0() must be children of Auth0Provider |
| Forgot to configure deep linking | Add URL scheme to iOS Info.plist and Android AndroidManifest.xml (see Step 3) |
| Callback URL mismatch | Ensure callback URL in Auth0 Dashboard matches your app's URL scheme (e.g., `com.yourapp.auth0://YOUR_DOMAIN/ios/com.yourapp/callback`) |
| iOS build fails after install | Run `npx pod-install` to link native dependencies |
| App created as SPA type in Auth0 | Must be Native application type for mobile apps |
| Not handling auth errors | Wrap authorize/clearSession calls in try-catch blocks |
| Deep link not working on Android | Verify `android:exported="true"` is set on RedirectActivity |

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Core Hook API:**
- `useAuth0()` - Main hook for authentication
- `authorize()` - Initiate login
- `clearSession()` - Logout
- `user` - User profile object
- `getCredentials()` - Get tokens for API calls
- `isLoading` - Loading state

**Common Use Cases:**
- Login/Logout → See Step 5 above
- Secure token storage → Automatic with `Auth0Provider`
- Biometric authentication → [Patterns Guide](references/patterns.md#biometric-auth)
- API calls with tokens → [Patterns Guide](references/patterns.md#calling-apis)
- Token refresh → Automatic with `getCredentials()`

---

## References

- [Auth0 React Native SDK Documentation](https://auth0.com/docs/libraries/react-native-auth0)
- [Auth0 React Native Quickstart](https://auth0.com/docs/quickstart/native/react-native)
- [SDK GitHub Repository](https://github.com/auth0/react-native-auth0)
