# API Reference & Testing — Auth0 Flutter Native (iOS/Android)

## Configuration Reference

### Auth0 Constructor

```dart
Auth0(String domain, String clientId, {
  UserAgent? userAgent,
  LocalAuthentication? localAuthentication,
})
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `domain` | `String` | Yes | Your Auth0 tenant domain (e.g., `tenant.auth0.com`) |
| `clientId` | `String` | Yes | Your Auth0 application Client ID |
| `localAuthentication` | `LocalAuthentication?` | No | Enables biometric protection of stored credentials |
| `userAgent` | `UserAgent?` | No | Custom telemetry user agent |

### Programmatic Initialization

```dart
import 'package:auth0_flutter/auth0_flutter.dart';

// Basic initialization
final auth0 = Auth0('YOUR_DOMAIN', 'YOUR_CLIENT_ID');

// With biometric protection
final auth0WithBiometrics = Auth0(
  'YOUR_DOMAIN',
  'YOUR_CLIENT_ID',
  localAuthentication: const LocalAuthentication(title: 'Authenticate'),
);
```

---

## Web Authentication API

Access via `auth0.webAuthentication()` or `auth0.webAuthentication(scheme: '...')`.

### login()

Launches Universal Login in the system browser and stores the resulting credentials.

```dart
Future<Credentials> login({
  String? audience,
  Set<String> scopes = const {'openid', 'profile', 'email'},
  String? redirectUrl,
  String? organizationId,
  String? invitationUrl,
  String? scheme,
  bool? useHTTPS,
  IdTokenValidationConfig? idTokenValidationConfig,
  Map<String, String> parameters = const {},
  bool useEphemeralSession = false,
  SafariViewController? safariViewController,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `audience` | `String?` | API audience for the access token |
| `scopes` | `Set<String>` | OAuth scopes. Add `offline_access` for refresh tokens |
| `redirectUrl` | `String?` | Override the callback URL (must match Dashboard config) |
| `organizationId` | `String?` | Auth0 Organization ID |
| `invitationUrl` | `String?` | Organization invitation URL |
| `useHTTPS` | `bool?` | Use Universal Links / App Links (iOS 17.4+, Android) instead of a custom scheme |
| `parameters` | `Map<String, String>` | Extra authorize parameters (e.g., `{'screen_hint': 'signup'}`) |
| `useEphemeralSession` | `bool` | iOS only — do not persist the browser session cookie |

**Returns:** `Credentials` — and persists them via the CredentialsManager.

### logout()

Clears the session in the browser.

```dart
Future<void> logout({
  String? returnTo,
  String? scheme,
  bool? useHTTPS,
  SafariViewController? safariViewController,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `returnTo` | `String?` | Where to return after logout (must match Allowed Logout URLs) |
| `useHTTPS` | `bool?` | Use Universal Links / App Links for the logout callback |

> **Note:** `logout()` only clears the Auth0 browser session. Call `credentialsManager.clearCredentials()` to also wipe the stored tokens.

---

## CredentialsManager API

Access via `auth0.credentialsManager`.

### credentials()

Returns stored credentials, automatically renewing the access token with the refresh token if it is expired.

```dart
Future<Credentials> credentials({
  String? scopes,
  int minTtl = 0,
  Map<String, String> parameters = const {},
  String? audience,
})
```

**Throws:** `CredentialsManagerException` — inspect `isNoCredentialsFound`, `isTokenRenewFailed`, `isRetryable`.

### hasValidCredentials()

```dart
Future<bool> hasValidCredentials({int minTtl = 0})
```

**Returns:** `true` if valid (or renewable) credentials are stored.

### storeCredentials()

```dart
Future<bool> storeCredentials(Credentials credentials)
```

### clearCredentials()

```dart
Future<bool> clearCredentials()
```

### user()

```dart
Future<UserProfile?> user()
```

**Returns:** the decoded `UserProfile` from the stored ID token, or `null`.

### ssoCredentials()

```dart
Future<SSOCredentials> ssoCredentials({Map<String, String> parameters = const {}})
```

Exchanges the stored refresh token for SSO credentials (native-to-web SSO).

---

## Authentication API (auth0.api)

Low-level Authentication API access for advanced flows.

```dart
// Renew with a refresh token
Future<Credentials> renewCredentials({required String refreshToken, ...})

// Fetch the user profile from /userinfo
Future<UserProfile> userProfile({required String accessToken})
```

---

## Credentials Class

| Property | Type | Description |
|----------|------|-------------|
| `accessToken` | `String` | JWT/opaque access token for API calls |
| `idToken` | `String` | JWT ID token with user identity claims |
| `refreshToken` | `String?` | Refresh token (requires `offline_access` scope) |
| `expiresAt` | `DateTime` | Access token expiration timestamp |
| `scopes` | `Set<String>` | Granted scopes |
| `tokenType` | `String` | Usually `Bearer` |
| `user` | `UserProfile` | Decoded user profile from the ID token |

### UserProfile Class

| Property | Type | Description |
|----------|------|-------------|
| `sub` | `String` | User ID (e.g., `auth0\|64abc123`) |
| `name` | `String?` | Full display name |
| `givenName` | `String?` | First name |
| `familyName` | `String?` | Last name |
| `nickname` | `String?` | Nickname |
| `email` | `String?` | Email address |
| `isEmailVerified` | `bool?` | Whether email is verified |
| `pictureUrl` | `Uri?` | Profile picture URL |
| `updatedAt` | `DateTime?` | Last profile update timestamp |
| `customClaims` | `Map<String, dynamic>?` | Any additional claims from the ID token |

---

## Claims Reference

### Standard OIDC Claims (from ID Token)

| Claim | Type | Description |
|-------|------|-------------|
| `sub` | String | User ID (e.g., `auth0\|64abc123`) |
| `name` | String | Full display name |
| `given_name` | String | First name |
| `family_name` | String | Last name |
| `email` | String | Email address |
| `email_verified` | Bool | Whether email is verified |
| `picture` | String | Profile picture URL |
| `updated_at` | String | Last profile update timestamp (ISO 8601) |
| `iss` | String | Issuer — your Auth0 domain |
| `aud` | String | Audience — your Client ID |
| `exp` | Number | Expiration time (Unix timestamp) |
| `iat` | Number | Issued at time (Unix timestamp) |

### Auth0-Specific Claims

| Claim | Type | Description |
|-------|------|-------------|
| `https://example.com/permissions` | `List<String>` | User permissions (added via Auth0 Actions) |
| `https://example.com/roles` | `List<String>` | User roles (added via Auth0 Actions) |
| `org_id` | String | Organization ID |
| `org_name` | String | Organization name |

### Accessing Custom Claims

```dart
final userProfile = await auth0.credentialsManager.user();
final roles = userProfile?.customClaims?['https://example.com/roles'] as List<dynamic>?;
```

---

## Exception Types

### WebAuthenticationException

Thrown by `webAuthentication().login()` / `logout()`.

| Property | Description |
|----------|-------------|
| `code` | Error code (e.g., `a0.authentication_canceled`) |
| `message` | Human-readable message |
| `isUserCancelledException` | `true` when the user dismissed the browser |

### CredentialsManagerException

Thrown by `credentialsManager` methods.

| Property | Description |
|----------|-------------|
| `isNoCredentialsFound` | No credentials are stored |
| `isNoRefreshTokenFound` | No refresh token available to renew with (request `offline_access`) |
| `isTokenRenewFailed` | Refresh-token renewal failed (revoked/expired) |
| `message` | Human-readable message |

---

## Testing Checklist

### Development Testing

- [ ] App launches without errors
- [ ] Tapping "Log In" opens the system browser at Auth0 Universal Login
- [ ] After login, the browser returns to the app and credentials are stored
- [ ] User profile (name, email, picture) displays correctly
- [ ] Tapping "Log Out" clears the session and stored credentials
- [ ] Relaunching the app restores the session via `hasValidCredentials()` + `credentials()`
- [ ] Login on a custom scheme (if configured) returns correctly
- [ ] Biometric prompt appears before credentials are returned (if `localAuthentication` is set)

### Production Testing

- [ ] Android and iOS callback/logout URLs are in Auth0 Dashboard
- [ ] Android release build with the correct `applicationId` returns to the app
- [ ] iOS Associated Domains is configured for the production bundle ID
- [ ] Refresh token renewal works (leave app idle past access-token expiry, then call an API)
- [ ] `offline_access` is requested so refresh tokens are issued

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Android build fails referencing `auth0Domain` | Missing `manifestPlaceholders` | Add `auth0Domain` + `auth0Scheme` to `android/app/build.gradle` `defaultConfig` |
| Browser opens but never returns to the app | Callback URL mismatch | Register `https://DOMAIN/android/PACKAGE/callback` and `https://DOMAIN/ios/BUNDLE/callback` exactly |
| `Callback URL mismatch` error in browser | Scheme/host differs from Dashboard | Ensure the scheme (`https` vs custom) matches both Gradle/plist and the Dashboard URL |
| Login returns but session not restored on relaunch | Not calling `credentialsManager.credentials()` on startup | Call `hasValidCredentials()` + `credentials()` in `initState()` |
| Refresh token is null | `offline_access` not requested | Add `'offline_access'` to the `scopes` set |
| Biometric prompt never shows (Android) | `MainActivity` extends `FlutterActivity` | Change it to extend `FlutterFragmentActivity` |
| Custom scheme login fails on Android | Uppercase letters in scheme | Use only lowercase letters in the custom scheme |
| `CredentialsManagerException` on `credentials()` | Refresh failed or no credentials | Inspect `isNoCredentialsFound` / `isTokenRenewFailed`; clear and re-login |
| Using `Auth0Web` / `auth0_flutter_web.dart` | Wrong platform API | Mobile uses the `Auth0` class from `auth0_flutter.dart` only |

---

## Security Considerations

- **No client secret** is used or stored in the mobile app — PKCE secures the flow.
- Tokens are stored in the **Android Keystore / iOS Keychain** by the CredentialsManager — never in plain `SharedPreferences` / `NSUserDefaults`.
- Use **biometric protection** (`LocalAuthentication`) for apps handling sensitive data.
- Always request `offline_access` so short-lived access tokens can be silently renewed instead of forcing re-login.
- Prefer **HTTPS App Links / Universal Links** (`auth0Scheme: "https"`) over custom schemes to prevent scheme hijacking by other apps.
