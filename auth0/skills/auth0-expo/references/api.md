# auth0-expo API Reference & Testing

## Table of Contents

- [Configuration Reference](#configuration-reference) — Auth0Provider props, authorize/clearSession/getCredentials options
- [Expo Config Plugin Reference](#expo-config-plugin-reference) — app.json plugin fields and auto-configuration
- [User Profile Claims](#user-profile-claims) — Standard OIDC claims
- [Credentials Object](#credentials-object) — Token properties
- [Testing Checklist](#testing-checklist) — Dev build, platform-specific, Auth0 config, EAS
- [Common Issues](#common-issues) — Error table with causes and solutions
- [Security Considerations](#security-considerations) — PKCE, secure storage, custom scheme, tokens, network

## Configuration Reference

### Auth0Provider Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| `domain` | `string` | Yes | Auth0 tenant domain (e.g., `your-tenant.auth0.com`) |
| `clientId` | `string` | Yes | Auth0 application Client ID |
| `localAuthenticationOptions` | `LocalAuthenticationOptions` | No | Biometric authentication configuration |
| `maxRetries` | `number` | No | Credential renewal retry count (iOS only, default: 0) |
| `useDPoP` | `boolean` | No | Enable DPoP token binding (default: true) |
| `headers` | `Record<string, string>` | No | Custom headers for all API requests |

### authorize() Options

**First argument (parameters):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `scope` | `string` | OAuth scopes (default: `openid profile email`) |
| `audience` | `string` | API identifier for access token |
| `organization` | `string` | Organization ID for enterprise login |
| `invitationUrl` | `string` | Organization invitation URL |
| `connection` | `string` | Force a specific connection (e.g., `google-oauth2`) |
| `additionalParameters` | `object` | Extra parameters for the /authorize endpoint |

**Second argument (options):**

| Option | Type | Description |
|--------|------|-------------|
| `customScheme` | `string` | **Required for Expo.** URL scheme matching app.json plugin config. |

### clearSession() Options

| Option | Type | Description |
|--------|------|-------------|
| `customScheme` | `string` | **Required for Expo.** Must match the scheme used in authorize(). |
| `federated` | `boolean` | If true, also logs out from the identity provider |

### getCredentials() Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `scope` | `string` | Minimum required scope |
| `minTtl` | `number` | Minimum time-to-live in seconds for the access token |
| `parameters` | `object` | Additional parameters |
| `forceRefresh` | `boolean` | Force token refresh even if not expired |

## Expo Config Plugin Reference

### app.json Plugin Configuration

```json
["react-native-auth0", {
  "domain": "your-tenant.auth0.com",
  "customScheme": "auth0sample"
}]
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `domain` | `string` | Yes | Auth0 tenant domain |
| `customScheme` | `string` | No | Custom URL scheme (lowercase, no special chars). If `"https"`, enables Android App Links with `autoVerify`. |

**What the plugin configures automatically:**
- **iOS**: Adds URL scheme to Info.plist (`CFBundleURLSchemes`), adds deep linking handler to AppDelegate
- **Android**: Sets `manifestPlaceholders` (`auth0Domain`, `auth0Scheme`) in build.gradle

## User Profile Claims

| Claim | Type | Description |
|-------|------|-------------|
| `sub` | `string` | Unique user identifier |
| `name` | `string` | Full name |
| `nickname` | `string` | Display name |
| `email` | `string` | Email address |
| `email_verified` | `boolean` | Whether email is verified |
| `picture` | `string` | Profile picture URL |
| `updated_at` | `string` | Last profile update timestamp |
| `org_id` | `string` | Organization ID (if using Organizations) |

## Credentials Object

| Property | Type | Description |
|----------|------|-------------|
| `accessToken` | `string` | Access token for API calls |
| `idToken` | `string` | ID token with user claims |
| `refreshToken` | `string` | Refresh token (if `offline_access` requested) |
| `tokenType` | `string` | Token type (`Bearer` or `DPoP`) |
| `expiresAt` | `number` | Token expiration timestamp |
| `scope` | `string` | Granted scopes |

## Testing Checklist

### Development Build Testing

- [ ] Login flow: Tap login → browser opens → complete login → app shows user info
- [ ] Logout flow: Tap logout → session cleared → app shows login button
- [ ] Credential persistence: Close app → reopen → user remains logged in
- [ ] Token refresh: Wait for token expiry → `getCredentials()` returns fresh token
- [ ] Error handling: Cancel login → app handles USER_CANCELLED gracefully
- [ ] Loading state: `isLoading` is true until auth state is determined

### Platform-Specific Testing

- [ ] **iOS Simulator**: Login/logout works, URL scheme redirects correctly
- [ ] **Android Emulator**: Login/logout works, custom scheme callback received
- [ ] **Physical iOS Device**: Test on a real physical device — Face ID / Touch ID prompts work (if biometrics enabled). Note: biometric authentication is not available on simulators.
- [ ] **Physical Android Device**: Test on a real physical device — fingerprint / PIN prompts work (if biometrics enabled). Test deep link redirection from browser back to app.

### Auth0 Configuration Testing

- [ ] Callback URL matches exactly (lowercase, no trailing slash)
- [ ] Application type is **Native** in Auth0 Dashboard
- [ ] Allowed Callback URLs include both iOS and Android URLs
- [ ] Allowed Logout URLs include both iOS and Android URLs
- [ ] OIDC Conformant toggle is enabled in Advanced OAuth settings

### EAS Build Testing

- [ ] Development build: `eas build --profile development` succeeds
- [ ] Config plugin applied: Native files contain Auth0 configuration after prebuild
- [ ] Production build: `eas build --profile production` succeeds

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Invariant Violation: Native module cannot be null" | Using Expo Go instead of development build | Run `npx expo run:ios` or `npx expo run:android`, or create a development build with EAS |
| App hangs after login | Callback URL mismatch | Verify callback URL is lowercase, no trailing slash, and matches Auth0 Dashboard exactly |
| Login opens but redirects fail | Missing customScheme in authorize call | Pass `{ customScheme: 'your-scheme' }` as second argument to `authorize()` |
| "PKCE not allowed" error | App type is not Native | Change application type to **Native** in Auth0 Dashboard |
| Blank screen after authentication | React Navigation interference | Ensure Auth0Provider wraps the entire navigation container |
| Android build fails with manifest errors | Conflicting auth0Domain placeholders | Remove manual manifest changes — let the Expo config plugin handle it |
| iOS build fails with pod errors | Stale native projects | Run `npx expo prebuild --clean` to regenerate native code |
| Token refresh fails silently | Missing `offline_access` scope | Include `offline_access` in the scope parameter during login |
| Biometric prompt not showing | Simulator limitation | Test biometrics on a physical device — simulators have limited biometric support |

## Security Considerations

### PKCE (Proof Key for Code Exchange)

The SDK uses PKCE by default for all Web Auth flows. PKCE protects against authorization code interception attacks. No additional configuration is needed.

### Secure Credential Storage

Credentials are stored securely:
- **iOS**: Encrypted in the Keychain
- **Android**: Encrypted in SharedPreferences via SecureCredentialsManager

Never store tokens manually in AsyncStorage, MMKV, or other unencrypted storage.

### Custom Scheme Security

Custom URL schemes can be subject to [client impersonation attacks](https://datatracker.ietf.org/doc/html/rfc8252#section-8.6). For production apps, consider using:
- **Android App Links** (`customScheme: "https"`) — requires SHA256 fingerprint configuration
- **iOS Universal Links** — requires Associated Domains and Apple Developer account

### Token Handling Best Practices

- Never log tokens to the console in production builds
- Use `getCredentials()` to access tokens — it auto-refreshes expired tokens
- Request `offline_access` scope for refresh token support
- Do not store tokens in React state — use `getCredentials()` on demand
- Enable DPoP for enhanced token security (enabled by default)

### Network Security

- All Auth0 API communication uses HTTPS
- The SDK validates ID token signatures, issuer, audience, and nonce
- Enable certificate pinning for additional security in high-security environments

## Related Skills

- [auth0-quickstart](/auth0-quickstart) — Set up an Auth0 account and application
- [auth0-react-native](/auth0-react-native) — Bare React Native CLI projects
- [auth0-mfa](/auth0-mfa) — Configure multi-factor authentication

## References

- [react-native-auth0 API Docs](https://auth0.github.io/react-native-auth0/)
- [Auth0 Expo Quickstart](https://auth0.com/docs/quickstart/native/react-native-expo/interactive)
- [Expo Config Plugins Guide](https://docs.expo.dev/guides/config-plugins/)
- [Auth0 Universal Login](https://auth0.com/docs/authenticate/login/auth0-universal-login)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
