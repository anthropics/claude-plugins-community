---
skills: auth0-swift-major-migration
---

## Task

Migrate this iOS app from Auth0.swift v2 to v3. If you need to choose a target version, use the latest available v3 release.

Here is the current code:

**Package.swift dependency:**
```swift
.package(url: "https://github.com/auth0/Auth0.swift", from: "2.0.0")
```

**AuthenticationService.swift:**
```swift
import Auth0

class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

    init() { isAuthenticated = credentialsManager.canRenew() }

    func login() async {
        do {
            let credentials = try await Auth0.webAuth()
                .scope("openid profile email offline_access")
                .start()
            _ = credentialsManager.store(credentials: credentials)
            await MainActor.run { isAuthenticated = true }
        } catch WebAuthError.userCancelled { }
        catch { print("Login failed: \(error)") }
    }

    func logout() async {
        do { try await Auth0.webAuth().clearSession() }
        catch { print("Logout failed: \(error)") }
        _ = credentialsManager.clear()
        await MainActor.run { isAuthenticated = false }
    }

    func getUser() -> UserInfo? {
        return credentialsManager.user
    }
}
```

The project is in a clean git state and builds successfully on v2.
