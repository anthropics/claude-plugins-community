# Auth0 Android Testing & Reference

## Testing Checklist

Before deploying your Auth0 Android integration, verify:

- [ ] **Emulator Testing**
  - [ ] Login flow completes end-to-end
  - [ ] Logout clears credentials
  - [ ] Credentials persist after app restart
  - [ ] Token refresh works when token expires
  - [ ] Error messages display correctly

- [ ] **Physical Device Testing**
  - [ ] Login flow works on actual device
  - [ ] Custom Tabs browser opens correctly
  - [ ] Deep link callback works (https:// or custom scheme)
  - [ ] Biometric authentication prompts appear (if implemented)
  - [ ] App Links work with https:// scheme

- [ ] **Auth0 Configuration**
  - [ ] Callback URL matches exactly in Auth0 Dashboard
  - [ ] Logout URL configured in Auth0 Dashboard
  - [ ] Application type is "Native" (not SPA or Machine-to-Machine)
  - [ ] Client ID and domain are correct

- [ ] **Security**
  - [ ] Credentials stored via SecureCredentialsManager
  - [ ] No tokens logged to console
  - [ ] INTERNET permission added to manifest
  - [ ] ProGuard rules not stripping Auth0 classes

- [ ] **Edge Cases**
  - [ ] User cancels login mid-flow
  - [ ] Network timeout during login
  - [ ] Device goes to sleep during login
  - [ ] Token refresh fails gracefully
  - [ ] MFA challenges work (if enabled)

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Deep link not working after login | Callback URL mismatch or manifest placeholders not set | Verify callback URL format: `https://{DOMAIN}/android/{PACKAGE}/callback`. Ensure `auth0Domain` and `auth0Scheme` in manifest placeholders. Rebuild and reinstall app. |
| "Invalid state" error on redirect | Authentication session timed out or was invalidated | This can happen after long delays or device sleep. Redirect user to login again. For testing, keep login window active. |
| Custom Tabs browser not opening | No browser available on device or Custom Tabs disabled | Check `error.isBrowserAppNotAvailable`. Ensure device has Chrome or compatible browser. Fallback to system browser if needed. |
| Biometric prompt not showing | Min API < 21, biometric not enrolled, or options not set | Set min SDK to 21+. Enroll fingerprint/face on device. Verify `LocalAuthenticationOptions` and `BiometricPolicy` configuration. Check `setDeviceCredentialFallback(true)` for PIN/password fallback. |
| Token refresh fails and user can't access APIs | Refresh token expired (typically after 30 days of inactivity) | Catch `CredentialsManagerException` with code `REFRESH_FAILED`. Trigger `WebAuthProvider.login()` to re-authenticate. Inform user they need to log in again. |
| ProGuard/R8 strips Auth0 classes and crashes | ProGuard rules not applied | Auth0 rules are bundled automatically. If issues occur, add `-keep class com.auth0.** { *; }` to your `proguard-rules.pro` or disable minification for testing. |
| Login works on emulator but fails on physical device | Certificate pinning or network differences | Ensure device has valid time/date. Check network connectivity. For HTTPS scheme, verify Digital Asset Links are set up for your domain. |
| Credentials lost after app update | Shared storage encrypted with device key that changed | This is expected behavior after major system updates. Gracefully handle `NO_CREDENTIALS` and redirect to login. |

## Security Considerations

### PKCE Enabled by Default

The Auth0 Android SDK automatically enables PKCE (Proof Key for Code Exchange) for all authorization flows. PKCE provides an extra layer of security for native apps and is always used by `WebAuthProvider`.

### Secure Credential Storage

Always use `SecureCredentialsManager` for token storage:

```kotlin
val authentication = AuthenticationAPIClient(account)
val storage = SharedPreferencesStorage(context)
val manager = SecureCredentialsManager(context, authentication, storage)
manager.saveCredentials(credentials)  // Encrypted at rest
```

Never store tokens in:
- Plain `SharedPreferences` — Not encrypted
- `DataStore` without encryption — Unencrypted
- App-level files — Accessible to other apps

### HTTPS Scheme Recommended

Prefer `https://` scheme over custom schemes:

```gradle
manifestPlaceholders = [
    auth0Domain: "@string/com_auth0_domain",
    auth0Scheme: "@string/com_auth0_scheme"
]
```

Benefits:
- Leverages Android App Links for secure deep linking
- Requires Digital Asset Links verification
- No prompt when opening links
- More difficult to intercept

Custom schemes are lower security but work if HTTPS is not feasible.

### Never Log Tokens

Do not log access tokens, ID tokens, or refresh tokens:

```kotlin
// BAD
Log.d("Auth0", "Token: ${credentials.accessToken}")

// GOOD
Log.d("Auth0", "Authentication successful")
```

Logs may be accessible via `adb logcat` or included in crash reports.

### Validate Tokens

Always call `.validateClaims()` when using direct API calls:

```kotlin
authentication.login(...)
    .validateClaims()  // Validates ID token claims
    .start(callback)
```

This verifies:
- Token signature
- Token expiration
- Audience (aud) claim
- Issuer (iss) claim

`WebAuthProvider` validates automatically, but direct API calls do not.

### Biometric Protection

When storing credentials with biometric protection, use strong authentication:

```kotlin
val options = LocalAuthenticationOptions.Builder()
    .setAuthenticationLevel(AuthenticationLevel.STRONG)
    .setPolicy(BiometricPolicy.Always)
    .build()
```

Avoid:
- `AuthenticationLevel.WEAK` for sensitive operations
- `BiometricPolicy.Never` when protecting credentials
- `setDeviceCredentialFallback(true)` with WEAK level

## API Reference

### Auth0

Entry point for SDK initialization:

```kotlin
// From strings.xml
val account = Auth0.getInstance(context)

// Direct
val account = Auth0.getInstance("CLIENT_ID", "DOMAIN")
```

### WebAuthProvider

Browser-based OAuth 2.0 flow:

```kotlin
WebAuthProvider.login(account)
    .withScheme(getString(R.string.com_auth0_scheme))
    .withScope("openid profile email")
    .withAudience("https://api.example.com")
    .withConnection("google-oauth2")
    .withOrganization("org_id")
    .withInvitation("invitation_id")
    .withPrompt("login")  // "login" or "none"
    .withCustomTabsOptions(customTabs)
    .start(context, callback)

WebAuthProvider.logout(account)
    .withScheme(getString(R.string.com_auth0_scheme))
    .start(context, callback)
```

### AuthenticationAPIClient

Direct API calls:

```kotlin
val authentication = AuthenticationAPIClient(account)

authentication.login(email, password, realm)
authentication.signUp(email, password, username, connection)
authentication.passwordlessWithEmail(email, type)
authentication.loginWithEmail(email, code)
authentication.mfaClient(mfaToken)
```

### SecureCredentialsManager

Secure credential storage:

```kotlin
val authentication = AuthenticationAPIClient(account)
val storage = SharedPreferencesStorage(context)
val manager = SecureCredentialsManager(context, authentication, storage)

manager.saveCredentials(credentials)
manager.hasValidCredentials(): Boolean
manager.getCredentials(callback)
manager.clearCredentials()
```

### Credentials

User tokens and metadata:

```kotlin
val accessToken = credentials.accessToken      // OAuth 2.0 access token
val idToken = credentials.idToken              // OpenID Connect ID token
val refreshToken = credentials.refreshToken    // Refresh token
val expiresAt = credentials.expiresAt          // Expiration timestamp
val scope = credentials.scope                  // Granted scopes
val type = credentials.type                    // "Bearer"

// ID token claims
val sub = credentials.claims["sub"]            // Subject (user ID)
val name = credentials.claims["name"]
val email = credentials.claims["email"]
val emailVerified = credentials.claims["email_verified"]
```

### LocalAuthenticationOptions

Biometric authentication configuration:

```kotlin
LocalAuthenticationOptions.Builder()
    .setTitle("Authenticate")
    .setDescription("Verify your identity")
    .setAuthenticationLevel(AuthenticationLevel.STRONG)
    .setNegativeButtonText("Cancel")
    .setDeviceCredentialFallback(true)
    .setPolicy(BiometricPolicy.Session(300))
    .build()
```

### Exception Handling

```kotlin
// AuthenticationException
error.isMultifactorRequired: Boolean
error.isBrowserAppNotAvailable: Boolean
error.isAuthenticationCanceled: Boolean
error.statusCode: Int
error.message: String?

// CredentialsManagerException
error.code: String  // "NO_CREDENTIALS", "CREDENTIALS_EXPIRED", "REFRESH_FAILED"
error.message: String?
```

## Related Skills

- [auth0-mfa](/auth0-mfa) — Configure multi-factor authentication
- [auth0-quickstart](/auth0-quickstart) — Set up an Auth0 account and application
- [auth0-swift](/auth0-swift) — iOS/macOS authentication
- [auth0-react-native](/auth0-react-native) — React Native authentication

## References

- [Auth0 Android SDK Documentation](https://auth0.com/docs/libraries/auth0-android)
- [Auth0 Android Quickstart](https://auth0.com/docs/quickstart/native/android)
- [Auth0 Android GitHub Repository](https://github.com/auth0/auth0-android)
- [Android SDK Javadoc](https://auth0.com/docs/references/android)
- [Sample App](https://github.com/auth0-samples/auth0-android-sample)
- [Android Security Best Practices](https://developer.android.com/privacy-and-security)
