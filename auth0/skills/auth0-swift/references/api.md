# API Reference & Testing — Auth0 Swift

## Configuration Reference

### Auth0.plist Keys

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `ClientId` | String | Yes | Your Auth0 application Client ID |
| `Domain` | String | Yes | Your Auth0 tenant domain (e.g., `tenant.auth0.com`) |

### Programmatic Initialization

Use when you cannot use `Auth0.plist` (e.g., reading credentials from environment):

```swift
// Web Auth with explicit credentials
Auth0
    .webAuth(clientId: "YOUR_CLIENT_ID", domain: "YOUR_DOMAIN")
    .start()

// Authentication API with explicit credentials
Auth0
    .authentication(clientId: "YOUR_CLIENT_ID", domain: "YOUR_DOMAIN")
    .login(usernameOrEmail: "user@example.com", password: "password",
           realmOrConnection: "Username-Password-Authentication",
           scope: "openid profile email")

// CredentialsManager with explicit credentials
let authentication = Auth0.authentication(clientId: "YOUR_CLIENT_ID", domain: "YOUR_DOMAIN")
let credentialsManager = CredentialsManager(authentication: authentication)
```

### WebAuth Builder Options

| Method | Type | Description |
|--------|------|-------------|
| `.useHTTPS()` | — | Use Universal Links (HTTPS) for callback — recommended |
| `.scope(_ scope: String)` | `String` | Space-separated OAuth scopes. Default: `"openid profile email"`. Add `"offline_access"` for refresh tokens |
| `.audience(_ audience: String)` | `String` | API audience (resource identifier). Required for API access tokens |
| `.parameters(_ params: [String: String])` | `[String: String]` | Additional authorize parameters (e.g., `["screen_hint": "signup"]`) |
| `.organization(_ organization: String)` | `String` | Auth0 Organization ID or name |
| `.invitationURL(_ url: URL)` | `URL` | Accept an organization invitation |
| `.redirectURL(_ url: URL)` | `URL` | Override the callback URL |
| `.provider(_ provider: WebAuthProvider)` | — | Use SFSafariViewController or custom provider |
| `.ephemeralSession()` | — | Do not persist session cookies (no SSO) |
| `.nonce(_ nonce: String)` | `String` | Override the auto-generated nonce |
| `.maxAge(_ maxAge: Int)` | `Int` | Maximum age (seconds) of allowed authentication |
| `.leeway(_ leeway: Int)` | `Int` | Clock skew tolerance in seconds for ID token validation |

### CredentialsManager Options

| Method | Type | Description |
|--------|------|-------------|
| `CredentialsManager(authentication:)` | — | Standard initialization |
| `CredentialsManager(authentication:maxRetries:)` | `Int` | Set retry attempts on transient errors |
| `CredentialsManager(authentication:storeKey:)` | `String` | Custom Keychain key for multi-account support |
| `.store(credentials:)` | `Bool` | Store credentials; returns `false` if Keychain write fails |
| `.credentials()` | `Credentials` (async) | Retrieve valid credentials; auto-renews if expired |
| `.credentials(minTTL:)` | `Credentials` (async) | Retrieve with minimum remaining TTL |
| `.canRenew()` | `Bool` | Returns `true` if a refresh token is available |
| `.hasValid(minTTL:)` | `Bool` | Returns `true` if access token is valid for at least `minTTL` seconds |
| `.clear()` | `Bool` | Remove credentials from Keychain |
| `.revoke(headers:)` | `Void` (async) | Revoke refresh token and clear credentials |
| `.enableBiometrics(withTitle:)` | — | Prompt biometric authentication when retrieving credentials |
| `.enableBiometrics(withTitle:policy:)` | — | Biometrics with custom `LAPolicy` |
| `.clearBiometricSession()` | — | Clear cached biometric session |
| `.isBiometricSessionValid()` | `Bool` | Check if biometric session is still valid |

### Biometric Policy Options

| Policy | Description |
|--------|-------------|
| `.default` | System manages prompts; allows reuse within a short window |
| `.always` | Fresh biometric prompt every time credentials are retrieved |
| `.session(timeoutInSeconds:)` | Reuse biometric auth for specified seconds (default 300) |
| `.appLifecycle(timeoutInSeconds:)` | Reuse for app lifecycle (default 3600 seconds / 1 hour) |

### Credentials Object

| Property | Type | Description |
|----------|------|-------------|
| `accessToken` | `String` | JWT access token for API calls |
| `tokenType` | `String` | Token type, usually `"Bearer"` |
| `idToken` | `String` | JWT ID token with user identity claims |
| `refreshToken` | `String?` | Refresh token (requires `offline_access` scope) |
| `expiresIn` | `Date` | Access token expiration date |
| `scope` | `String?` | Granted scopes |

---

## Claims Reference

### Standard OIDC Claims (from ID Token)

| Claim | Type | Description |
|-------|------|-------------|
| `sub` | String | User ID (e.g., `"auth0|64abc123"`) |
| `name` | String | Full display name |
| `given_name` | String | First name |
| `family_name` | String | Last name |
| `email` | String | Email address |
| `email_verified` | Bool | Whether email is verified |
| `picture` | String | Profile picture URL |
| `updated_at` | Date | Last profile update timestamp |
| `iss` | String | Issuer — your Auth0 domain |
| `aud` | String | Audience — your Client ID |
| `exp` | Date | Expiration time |
| `iat` | Date | Issued at time |

### Auth0-Specific Claims

| Claim | Type | Description |
|-------|------|-------------|
| `https://example.com/permissions` | `[String]` | User permissions (added via Auth0 Actions) |
| `https://example.com/roles` | `[String]` | User roles (added via Auth0 Actions) |
| `org_id` | String | Organization ID |
| `org_name` | String | Organization name |

### Decoding Claims

```swift
import Auth0

// Decode ID token claims
if let claims = try? IDTokenClaimsValidation().validate(credentials.idToken) {
    print("User ID: \(claims.subject)")
    print("Email: \(claims.email ?? "none")")
}

// Or decode manually with JWT libraries
// The ID token is a standard JWT — decode payload with any JWT library
```

---

## Testing Checklist

> **Physical device note:** Web Auth (ASWebAuthenticationSession) works in the iOS Simulator, but biometric authentication (Face ID / Touch ID) requires a real device. Test biometric flows on a physical device before shipping. Simulator has limitations for camera-based Face ID and some Keychain access control scenarios.

- [ ] `Auth0.plist` is present in the Xcode project and added to the app target
- [ ] Both `https://` Universal Link and `{bundle}://` custom scheme URLs are in Auth0 Dashboard Callback URLs
- [ ] App builds without errors: `xcodebuild build -scheme SCHEME -destination "platform=iOS Simulator,name=iPhone 16"`
- [ ] Login opens system browser (ASWebAuthenticationSession) and redirects back to app
- [ ] `credentialsManager.store(credentials:)` returns `true` after login
- [ ] `credentialsManager.canRenew()` returns `true` after storing credentials with `offline_access`
- [ ] `credentialsManager.credentials()` returns valid access token without re-login (token auto-refresh)
- [ ] Logout clears session cookie (subsequent login shows login prompt, not silent SSO)
- [ ] `credentialsManager.clear()` returns `true` after logout
- [ ] Error cases are handled: `userCancelled`, `noCredentialsAvailable`, `failedToRenewCredentials`
- [ ] Biometric prompt appears (if enabled) before credentials are returned
- [ ] App state persists across launches (credentials survive app restart)

---

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `Auth0.plist not found` | File not added to target | Right-click `Auth0.plist` → Add Files → check app target |
| `No such module 'Auth0'` | Package not installed or wrong target | Verify SPM package in Xcode → Package Dependencies; re-resolve |
| `Redirect to app fails` | Callback URL mismatch | Ensure URL in Auth0 Dashboard matches bundle ID exactly |
| `Cannot open URL` (iOS) | Missing URL scheme | Add `$(PRODUCT_BUNDLE_IDENTIFIER)` to URL Schemes in Info tab |
| Login shows blank screen | Universal Links not configured | Use `.useHTTPS()` only if Universal Links are configured, else omit it |
| Token not renewable | Missing `offline_access` scope | Add `"offline_access"` to `.scope()` call |
| `biometricsFailed` error | No biometric enrolled or cancelled | Fall back to re-login |
| `cannotAccessKeychainItem` | Keychain entitlements missing | Verify app has Keychain Sharing capability or correct entitlements |
| Crash on macOS | Missing network entitlement | Add "Outgoing Connections (Client)" capability in Signing & Capabilities |
| Build fails on Swift 6 | Concurrency issues | Ensure callbacks are dispatched on `@MainActor` for UI updates |

---

## Security Considerations

- **No client secret**: Native apps use PKCE (Proof Key for Code Exchange) — no client secret is required or used. Do not add a client secret to `Auth0.plist`.
- **Keychain storage**: Always use `CredentialsManager` for token storage. Never use `UserDefaults` or plain files. Tokens in `UserDefaults` are readable by other apps on jailbroken devices.
- **Universal Links vs custom scheme**: Universal Links (`https://`) are recommended for production as they cannot be intercepted by malicious apps. Custom schemes (`{bundle}://`) are acceptable but less secure.
- **Scope minimization**: Request only the scopes your app needs. Avoid requesting permissions you do not use.
- **Refresh token rotation**: Enable Refresh Token Rotation in Auth0 Dashboard (Applications → Advanced Settings → OAuth) to detect token theft.
- **Biometric storage**: When using `enableBiometrics()`, the Keychain entry uses `kSecAccessControlBiometryCurrentSet` which invalidates the entry if new biometrics are enrolled — protecting against biometric spoofing.
- **Certificate pinning**: For extra security, use a custom `URLSession` with certificate pinning when calling your API with the access token.
- **App Transport Security**: Ensure `NSAllowsArbitraryLoads` is not set to `true` in production builds.

---

## Related Skills

- [auth0-android](/auth0-android) — Auth0 authentication for Android/Kotlin apps
- [auth0-flutter](/auth0-flutter) — Cross-platform iOS + Android authentication with Flutter
- [auth0-react-native](/auth0-react-native) — Cross-platform iOS + Android authentication with React Native
- [auth0-quickstart](/auth0-quickstart) — Set up an Auth0 account and application
- [auth0-mfa](/auth0-mfa) — Configure multi-factor authentication
