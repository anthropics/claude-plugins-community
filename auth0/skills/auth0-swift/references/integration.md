# Integration Patterns — Auth0 Swift

## Authentication Flow

```text
User taps "Log In"
    ↓
Auth0.webAuth().start()
    ↓
ASWebAuthenticationSession opens Auth0 Universal Login
    ↓ (user authenticates)
Auth0 redirects to {bundle}:// or https:// callback
    ↓
SDK exchanges code for tokens (PKCE)
    ↓
Credentials returned (accessToken, idToken, refreshToken)
    ↓
credentialsManager.store(credentials:) → Keychain
```

---

## Web Auth Login & Logout

### Basic Login (Async/Await)

```swift
import Auth0

func login() async throws -> Credentials {
    return try await Auth0
        .webAuth()
        .useHTTPS()                              // Use Universal Links callback
        .scope("openid profile email offline_access")
        .start()
}
```

### Basic Login (Completion Handler)

```swift
Auth0
    .webAuth()
    .useHTTPS()
    .scope("openid profile email offline_access")
    .start { result in
        switch result {
        case .success(let credentials):
            // Access token available at credentials.accessToken
            credentialsManager.store(credentials: credentials)
        case .failure(let error):
            print("Login failed: \(error)")
        }
    }
```

### Logout

```swift
// Step 1: Clear the Auth0 session cookie (prevents silent re-login)
try await Auth0
    .webAuth()
    .useHTTPS()
    .clearSession()

// Step 2: Clear locally stored credentials
let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
_ = credentialsManager.clear()
```

### Sign Up (Direct to Registration Screen)

```swift
try await Auth0
    .webAuth()
    .useHTTPS()
    .parameters(["screen_hint": "signup"])
    .start()
```

### Custom Scopes and Audience

```swift
// Request an access token for your API
try await Auth0
    .webAuth()
    .useHTTPS()
    .audience("https://your-api.example.com")
    .scope("openid profile email offline_access read:data")
    .start()
```

### Ephemeral Session (No SSO, No Cookie Persistence)

```swift
// Each login shows the login page — no session cookie stored
try await Auth0
    .webAuth()
    .useHTTPS()
    .ephemeralSession()
    .start()
```

---

## CredentialsManager

`CredentialsManager` handles secure Keychain storage and automatic token refresh.

### Basic Setup

```swift
// Initialize once (e.g., as a property on your auth service)
let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
```

### Store After Login

```swift
let credentials = try await Auth0.webAuth().start()
guard credentialsManager.store(credentials: credentials) else {
    throw AuthError.keychainWriteFailed
}
```

### Retrieve (Auto-Refreshes Expired Tokens)

```swift
do {
    let credentials = try await credentialsManager.credentials()
    callAPI(with: credentials.accessToken)
} catch CredentialsManagerError.noCredentialsAvailable {
    // No credentials stored — show login screen
    await showLogin()
} catch CredentialsManagerError.failedToRenewCredentials(let error) {
    // Refresh token expired or revoked — force re-login
    _ = credentialsManager.clear()
    await showLogin()
}
```

### Check Authentication State on Launch

```swift
func checkSession() -> Bool {
    // Returns true if a valid refresh token is stored
    return credentialsManager.canRenew()
}

// Check if access token is still valid without auto-refresh
func hasValidToken(minTTL: Int = 60) -> Bool {
    return credentialsManager.hasValid(minTTL: minTTL)
}
```

### Force Token Renewal

```swift
do {
    let credentials = try await credentialsManager.renew()
    // Renewed token available at credentials.accessToken
    _ = credentialsManager.store(credentials: credentials)
} catch {
    print("Renewal failed: \(error)")
}
```

### Revoke Refresh Token

```swift
// Revokes the refresh token on Auth0 and clears local credentials
try await credentialsManager.revoke()
```

---

## Biometric Protection

Protect credential retrieval with Face ID / Touch ID.

> **Physical device note:** Biometric authentication (Face ID / Touch ID) requires a real device. The iOS Simulator supports simulated biometrics but physical device testing is required before shipping to verify actual hardware behavior.

### Enable Biometrics

```swift
let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

// Basic — system-managed prompt reuse
credentialsManager.enableBiometrics(withTitle: "Authenticate to access your account")

// With session timeout (reuse for 5 minutes)
credentialsManager.enableBiometrics(
    withTitle: "Authenticate to access your account",
    policy: .session(timeoutInSeconds: 300)
)

// Require fresh biometric every time
credentialsManager.enableBiometrics(
    withTitle: "Authenticate to access your account",
    policy: .always
)

// App lifecycle (reset on app background/foreground)
credentialsManager.enableBiometrics(
    withTitle: "Authenticate to access your account",
    policy: .appLifecycle(timeoutInSeconds: 3600)
)
```

### Handle Biometric Errors

```swift
do {
    let credentials = try await credentialsManager.credentials()
    useCredentials(credentials)
} catch CredentialsManagerError.biometricsFailed {
    // Biometric auth failed — ask user to log in again
    _ = credentialsManager.clear()
    await login()
} catch CredentialsManagerError.noCredentialsAvailable {
    await login()
}
```

### Info.plist Permission (Required)

Add to your app's `Info.plist`:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Authenticate to access your account securely.</string>
```

---

## Error Handling

### Web Auth Errors

```swift
do {
    let credentials = try await Auth0.webAuth().start()
} catch WebAuthError.userCancelled {
    // User tapped Cancel — no action needed, just return to UI
} catch WebAuthError.noCredentialsAvailable {
    print("No credentials available — unexpected after login")
} catch WebAuthError.pkceNotAllowed {
    print("PKCE not enabled — check Auth0 Dashboard → Application → Advanced Settings → OAuth")
} catch {
    // Other error (network, configuration)
    print("Web Auth error: \(error)")
}
```

### CredentialsManager Errors

```swift
do {
    let credentials = try await credentialsManager.credentials()
} catch CredentialsManagerError.noCredentialsAvailable {
    // First launch or after logout
    await showLoginScreen()
} catch CredentialsManagerError.failedToRenewCredentials(let renewalError) {
    // Refresh token expired — must re-authenticate
    _ = credentialsManager.clear()
    await showLoginScreen()
} catch CredentialsManagerError.biometricsFailed {
    // Face ID / Touch ID failed
    await showBiometricFailureMessage()
} catch CredentialsManagerError.cannotAccessKeychainItem {
    // Keychain access denied (e.g., device locked, missing entitlements)
    print("Keychain error: \(error)")
}
```

### Authentication API Errors

```swift
Auth0
    .authentication()
    .login(usernameOrEmail: "user@example.com",
           password: "password",
           realmOrConnection: "Username-Password-Authentication",
           scope: "openid profile email offline_access")
    .start { result in
        switch result {
        case .success(let credentials):
            // Access token available at credentials.accessToken
            credentialsManager.store(credentials: credentials)
        case .failure(let error) where error.isMultifactorRequired:
            // Extract MFA token for MFA challenge flow
            if let mfaPayload = error.mfaRequiredErrorPayload {
                startMFAChallenge(mfaToken: mfaPayload.mfaToken)
            }
        case .failure(let error) where error.isNetworkError:
            showNetworkError()
        case .failure(let error):
            print("Auth error code: \(error.code), description: \(error.localizedDescription)")
        }
    }
```

---

## MFA (Multi-Factor Authentication)

### Handling MFA Required Error

```swift
// When login returns isMultifactorRequired = true, challenge with OTP
func verifyMFA(mfaToken: String, otp: String) async throws -> Credentials {
    return try await Auth0
        .authentication()
        .multifactorChallenge(mfaToken: mfaToken, types: ["otp"])
        .start()
}
```

---

## Organizations

### Login to a Specific Organization

```swift
try await Auth0
    .webAuth()
    .useHTTPS()
    .organization("YOUR_ORG_ID")
    .start()
```

### Accept Organization Invitation

```swift
// Handle invitation URL from deep link
func handleInvitation(url: URL) async {
    try? await Auth0
        .webAuth()
        .useHTTPS()
        .invitationURL(url)
        .start()
}
```

---

## Platform-Specific Patterns

### SwiftUI App Lifecycle (Recommended)

```swift
// MyApp.swift
import SwiftUI
import Auth0

@main
struct MyApp: App {
    @StateObject private var auth = AuthenticationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}

// ContentView.swift
struct ContentView: View {
    @EnvironmentObject var auth: AuthenticationService

    var body: some View {
        Group {
            if auth.isAuthenticated {
                HomeView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            auth.checkSession()
        }
    }
}
```

### UIKit App Lifecycle

```swift
// AppDelegate.swift
import UIKit
import Auth0

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Required for SFSafariViewController or custom URL scheme
        return WebAuthentication.resume(with: url)
    }
}

// SceneDelegate.swift (if using scenes)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        WebAuthentication.resume(with: url)
    }
}
```

### Using SFSafariViewController (Instead of ASWebAuthenticationSession)

```swift
// For apps that cannot use ASWebAuthenticationSession
Auth0
    .webAuth()
    .provider(WebAuthentication.safariProvider())
    .start { result in
        switch result {
        case .success(let credentials):
            print("Login success")
        case .failure(let error):
            print("Login failed: \(error)")
        }
    }
```

> **Note:** SFSafariViewController requires `WebAuthentication.resume(with:)` to be called from `AppDelegate` or `SceneDelegate` (see UIKit pattern above).

---

## App Groups (Shared Keychain Access)

To share credentials between your app and extensions (widgets, share extensions):

```swift
// Use a custom storeKey to write to a shared Keychain group
let credentialsManager = CredentialsManager(
    authentication: Auth0.authentication(),
    storeKey: "com.yourcompany.sharedCredentials"
)

// Configure Keychain sharing in Xcode:
// Target → Signing & Capabilities → + Capability → Keychain Sharing
// Add a shared Keychain group name
```

---

## Calling Your API with the Access Token

```swift
func fetchData() async throws -> [Item] {
    let credentials = try await credentialsManager.credentials()

    var request = URLRequest(url: URL(string: "https://your-api.example.com/items")!)
    request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode([Item].self, from: data)
}
```
