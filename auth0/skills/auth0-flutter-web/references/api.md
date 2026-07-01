# API Reference & Testing — Auth0 Flutter Web

## Configuration Reference

### Auth0Web Constructor

```dart
Auth0Web(String domain, String clientId)
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `domain` | `String` | Yes | Your Auth0 tenant domain (e.g., `tenant.auth0.com`) |
| `clientId` | `String` | Yes | Your Auth0 application Client ID |

### Programmatic Initialization

```dart
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

// Basic initialization — domain and client ID are public SPA config (not secrets)
final auth0 = Auth0Web(
  'YOUR_AUTH0_DOMAIN',
  'YOUR_AUTH0_CLIENT_ID',
);
```

---

## Core API Methods

### onLoad()

Initializes the Auth0 client, processes any redirect callback, and restores cached sessions.

```dart
Future<Credentials?> onLoad({
  String? audience,
  Set<String>? scopes,
  String? issuer,
  int? leeway,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `audience` | `String?` | API audience to validate tokens against |
| `scopes` | `Set<String>?` | Scopes to request during session restoration |
| `issuer` | `String?` | Expected token issuer |
| `leeway` | `int?` | Clock skew tolerance in seconds |

**Returns:** `Credentials?` — credentials if session exists, `null` otherwise.

**Must be called:** Once on app startup (e.g., in `initState()`). If omitted, redirect login will not complete.

---

### loginWithRedirect()

Redirects the browser to Auth0 Universal Login.

```dart
Future<void> loginWithRedirect({
  Object? appState,
  String? audience,
  String? redirectUrl,
  String? organizationId,
  String? invitationUrl,
  int? maxAge,
  Set<String>? scopes,
  Map<String, String> parameters = const {},
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `appState` | `Object?` | Custom state preserved across the redirect (e.g., return URL) |
| `audience` | `String?` | API audience for the access token |
| `redirectUrl` | `String?` | Override callback URL (must match Dashboard config) |
| `organizationId` | `String?` | Auth0 Organization ID |
| `invitationUrl` | `String?` | Organization invitation URL |
| `maxAge` | `int?` | Maximum authentication age in seconds |
| `scopes` | `Set<String>?` | OAuth scopes. Default: `{'openid', 'profile', 'email'}` |
| `parameters` | `Map<String, String>` | Additional authorize parameters (e.g., `{'screen_hint': 'signup'}`) |

---

### loginWithPopup()

Opens Auth0 Universal Login in a popup window.

```dart
Future<Credentials> loginWithPopup({
  String? audience,
  String? organizationId,
  String? invitationUrl,
  int? maxAge,
  Set<String>? scopes,
  Object? popupWindow,
  int? timeoutInSeconds,
  Map<String, String> parameters = const {},
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `audience` | `String?` | API audience for the access token |
| `organizationId` | `String?` | Auth0 Organization ID |
| `invitationUrl` | `String?` | Organization invitation URL |
| `maxAge` | `int?` | Maximum authentication age in seconds |
| `scopes` | `Set<String>?` | OAuth scopes |
| `popupWindow` | `Object?` | Pre-opened popup window (for Safari compatibility) |
| `timeoutInSeconds` | `int?` | Timeout before cancelling popup flow |
| `parameters` | `Map<String, String>` | Additional authorize parameters |

**Returns:** `Credentials` — immediately available after popup completes.

> **Note:** Must be called from a direct user interaction (button click) to avoid popup blocking.

---

### credentials()

Retrieves cached credentials. Auto-refreshes if the access token is within 60 seconds of expiry.

```dart
Future<Credentials> credentials({
  String? audience,
  num? timeoutInSeconds,
  Set<String>? scopes,
  CacheMode? cacheMode,
  Map<String, String> parameters = const {},
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `audience` | `String?` | API audience (returns audience-specific token if cached) |
| `timeoutInSeconds` | `num?` | Timeout for token refresh |
| `scopes` | `Set<String>?` | Required scopes |
| `cacheMode` | `CacheMode?` | Cache behavior override |
| `parameters` | `Map<String, String>` | Additional parameters |

**Throws:** `WebException` with code `login_required` if no valid session exists.

---

### hasValidCredentials()

Checks if valid credentials exist in cache without triggering a refresh.

```dart
Future<bool> hasValidCredentials()
```

**Returns:** `true` if valid cached credentials exist, `false` otherwise.

---

### logout()

Redirects to Auth0 logout endpoint and clears local session.

```dart
Future<void> logout({
  bool? federated,
  String? returnToUrl,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `federated` | `bool?` | Also log out from the upstream identity provider |
| `returnToUrl` | `String?` | Where to redirect after logout (must match Dashboard config) |

---

### customTokenExchange()

RFC 8693 Token Exchange for external identity tokens.

```dart
Future<Credentials> customTokenExchange({
  String? audience,
  Set<String>? scopes,
  required String subjectToken,
  required String subjectTokenType,
  Map<String, String> additionalParameters = const {},
})
```

---

### appState (Property)

Retrieves the `appState` object passed to `loginWithRedirect()` after the redirect callback completes.

```dart
Object? get appState
```

---

## Credentials Class

| Property | Type | Description |
|----------|------|-------------|
| `accessToken` | `String` | JWT access token for API calls |
| `idToken` | `String` | JWT ID token with user identity claims |
| `refreshToken` | `String?` | Refresh token (requires `offline_access` scope + rotation enabled) |
| `expiresAt` | `DateTime` | Access token expiration timestamp |
| `scopes` | `Set<String>?` | Granted scopes |
| `user` | `UserProfile` | Decoded user profile from ID token |

### UserProfile Class

| Property | Type | Description |
|----------|------|-------------|
| `sub` | `String?` | User ID (e.g., `auth0\|64abc123`) |
| `name` | `String?` | Full display name |
| `givenName` | `String?` | First name |
| `familyName` | `String?` | Last name |
| `nickname` | `String?` | Nickname |
| `email` | `String?` | Email address |
| `emailVerified` | `bool?` | Whether email is verified |
| `pictureUrl` | `Uri?` | Profile picture URL |
| `updatedAt` | `DateTime?` | Last profile update timestamp |
| `customClaims` | `Map<String, dynamic>?` | Any additional claims from ID token |

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
final credentials = await auth0.credentials();
final customClaims = credentials.user.customClaims;
final roles = customClaims?['https://example.com/roles'] as List<dynamic>?;
```

---

## Testing Checklist

### Development Testing

- [ ] App loads without console errors
- [ ] Clicking "Log In" redirects to Auth0 Universal Login
- [ ] After login, user is redirected back and `onLoad()` returns credentials
- [ ] User profile (name, email, picture) displays correctly
- [ ] Clicking "Log Out" clears session and redirects back
- [ ] After logout, `hasValidCredentials()` returns `false`
- [ ] Refreshing the page restores the session (via `onLoad()`)
- [ ] `loginWithPopup()` opens a popup and returns credentials

### Production Testing

- [ ] Production URLs are in Auth0 Dashboard (Callback, Logout, Web Origins)
- [ ] HTTPS is used in production (required for secure cookies)
- [ ] Token refresh works (leave app idle > 1 hour, then interact)
- [ ] Multiple browser tabs don't cause session conflicts
- [ ] Incognito mode works (tests without cached state)

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `login_required` error on `credentials()` | No valid session | Call `loginWithRedirect()` or `loginWithPopup()` |
| Redirect login never completes | `onLoad()` not called on startup | Add `await auth0.onLoad()` to app initialization |
| `Callback URL mismatch` error | URL doesn't match Dashboard config | Verify `Allowed Callback URLs` includes your exact app URL with port |
| CORS error on token endpoint | Missing `Allowed Web Origins` | Add app URL to `Allowed Web Origins` in Auth0 Dashboard |
| `auth0_spa_js is not defined` | Missing script tag | Add Auth0 SPA JS `<script>` to `web/index.html` `<head>` |
| Popup blocked | Not called from user gesture | Ensure `loginWithPopup()` is inside a button's `onPressed` handler |
| Infinite redirect loop | `loginWithRedirect()` called unconditionally | Only call login if `onLoad()` returns null |
| Refresh token not returned | `offline_access` not in scopes OR rotation not enabled | Add `offline_access` scope and enable refresh token rotation in Dashboard |
| Session not persisting after refresh | Using `loginWithPopup()` without `onLoad()` on reload | Always call `onLoad()` on app startup regardless of login method |
| `TypeError: Cannot read properties of undefined` | Auth0 SPA JS not loaded yet | Ensure `defer` on script tag and `onLoad()` waits for DOM ready |
