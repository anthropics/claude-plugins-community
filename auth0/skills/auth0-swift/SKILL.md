---
name: auth0-swift
description: >
  Use when adding Auth0 login, logout, or biometric-protected credential storage to an iOS, macOS, tvOS, watchOS, or visionOS app. Integrates Auth0.swift — use even if the user says "add login to my iOS app" or "add login to my Swift app".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Swift Integration

Auth0.swift is the official Auth0 SDK for Apple platforms (iOS, macOS, tvOS, watchOS, visionOS). This skill adds complete native authentication to Swift apps using Web Auth (system browser redirect), secure Keychain credential storage via `CredentialsManager`, and optional biometric protection.

## When NOT to Use

- **Android apps**: Use [auth0-android](/auth0-android)
- **React Native apps**: Use [auth0-react-native](/auth0-react-native)
- **Flutter apps**: Use the native Flutter Auth0 SDK
- **Web SPAs** (React, Angular, Vue): Use [auth0-react](/auth0-react), [auth0-angular](/auth0-angular), or [auth0-vue](/auth0-vue)
- **Node.js/Express servers**: Use [auth0-express](/auth0-express)

## Prerequisites

- **iOS** 14.0+ / **macOS** 11.0+ / tvOS 14.0+ / watchOS 7.0+ / visionOS 1.0+
- **Xcode** 16.x
- **Swift** 6.0+
- Auth0 account — [Sign up free](https://auth0.com/signup)
- Auth0 CLI — `brew install auth0/auth0-cli/auth0` (for automated setup)

## Quick Start Workflow

> **Agent instruction:** Follow these steps in order. If you encounter an error at any step, attempt to fix it up to 5 times before calling `AskUserQuestion` to ask the user for guidance. Always search existing code first — if there are existing login/logout handlers, hook into them rather than creating new ones.
>
> **IMPORTANT — Credential privacy:** Never echo Auth0 credentials (domain, client ID, client secret) in your response text or terminal output. Write them directly into config files using the Write or Edit tool. When running Auth0 CLI commands that produce output containing these values, redirect output to a file and read it programmatically. For example:
> ```bash
> auth0 apps create ... --json --no-input > /tmp/auth0-output.json 2>&1
> ```
> Then use the Read tool on `/tmp/auth0-output.json` to extract needed values and write them directly into `Auth0.plist` or other config files — never echo them in response text or terminal. When confirming the active tenant with the user, use a masked format (e.g., `your-te****.us.auth0.com`).

### Step 1 — Install SDK

> **Agent instruction:** Check the project directory for an existing package manager file:
> - `Podfile` present → **CocoaPods**
> - `Cartfile` present → **Carthage**
> - `Package.swift` present → **Swift Package Manager**
>
> If none are found, ask via `AskUserQuestion`: _"Which dependency manager does your project use — Swift Package Manager, CocoaPods, or Carthage?"_
>
> **Swift Package Manager — `Package.swift` project:** Run this command in the project root to add the dependency automatically, then add `"Auth0"` to the target's `dependencies` array in `Package.swift`:
> ```bash
> swift package add-dependency https://github.com/auth0/Auth0.swift --from 2.18.0
> ```
>
> **Swift Package Manager — Xcode project (`.xcodeproj`, no `Package.swift`):** The CLI command does not apply. Instruct the user to add the package via Xcode: File → Add Package Dependencies → `https://github.com/auth0/Auth0.swift` → Up to Next Major Version from `2.18.0`.
>
> **CocoaPods or Carthage:** Follow the matching installation steps in [Setup Guide](./references/setup.md#sdk-installation). Do not just show the instructions — perform the file edits and run the commands.

### Step 2 — Configure Auth0

> **Agent instruction:**
> - **If Auth0 credentials (domain AND client ID) are already in the user's prompt:** Write `Auth0.plist` directly with those values — do NOT ask the user any questions, do NOT hardcode them in Swift source files, and do NOT pass them as arguments to `Auth0.webAuth()` or `Auth0.authentication()`. The SDK reads `Auth0.plist` automatically — always use the no-argument form `Auth0.webAuth()`. Then proceed to Step 3.
> - **If an `Auth0.plist` file already exists in the project:** Read it to extract `ClientId` and `Domain`, then proceed to Step 3.
> - **If no `Auth0.plist` exists and no credentials were provided:** Ask the user via `AskUserQuestion`: _"How would you like to configure Auth0?"_
>   - **Automatic (Auth0 CLI)** — I'll create the application, set callback URLs, and configure everything using the Auth0 CLI.
>   - **Manual** — You provide a pre-configured `Auth0.plist` file and I'll add it to your project.
>
> If the user chooses **automatic**: Follow [Setup Guide — Automated Setup via Auth0 CLI](./references/setup.md#automated-setup-via-auth0-cli).
> If the user chooses **manual**: Follow [Setup Guide — Manual Setup](./references/setup.md#manual-setup-user-provided-auth0plist).
>
> **`Auth0.plist` format:**
> ```xml
> <?xml version="1.0" encoding="UTF-8"?>
> <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
> <plist version="1.0">
> <dict>
>   <key>ClientId</key>
>   <string>YOUR_CLIENT_ID</string>
>   <key>Domain</key>
>   <string>YOUR_DOMAIN</string>
> </dict>
> </plist>
> ```
> Place `Auth0.plist` in the same directory as the app's Swift source files so the SDK can find it automatically.

### Step 3 — Configure Callback URLs

> **Agent instruction:**
> 1. Read `Auth0.plist` to obtain `ClientId` and `Domain`.
> 2. Extract the bundle identifier from `project.pbxproj`: search for `PRODUCT_BUNDLE_IDENTIFIER`, skip values containing `$(` or `Tests`.
> 3. Ask the user via `AskUserQuestion`: _"Which callback URL scheme would you like to use?"_
>    - **Custom scheme** (`{bundle}://`) — simpler, works on all Apple platforms
>    - **HTTPS Universal Links** — recommended for production; prevents URL scheme hijacking
>
> Then follow **only** the matching path below.

#### Path A — Custom Scheme

> **Agent instruction:** Register the callback URLs using the Auth0 CLI (substitute real values for `CLIENT_ID`, `BUNDLE_ID`, `DOMAIN`).
>
> First, retrieve existing callback and logout URLs to avoid overwriting them:
> ```bash
> auth0 apps show CLIENT_ID --json --no-input > /tmp/auth0-app-info.json 2>&1
> ```
> Read `/tmp/auth0-app-info.json` to extract existing `callbacks` and `allowed_logout_urls` arrays.
>
> Then include any existing URLs as a comma-separated list alongside the new ones:
> ```bash
> auth0 apps update CLIENT_ID \
>   --callbacks "EXISTING_CALLBACKS,BUNDLE_ID://DOMAIN/ios/BUNDLE_ID/callback" \
>   --logout-urls "EXISTING_LOGOUT_URLS,BUNDLE_ID://DOMAIN/ios/BUNDLE_ID/callback" \
>   --no-input > /dev/null 2>&1
> ```
> If there are no existing URLs, omit the `EXISTING_` prefix and use only the new URL.
>
> Then follow the [URL scheme registration steps in Setup Guide](./references/setup.md#register-url-scheme-required-for-custom-scheme-callbacks) to register `$(PRODUCT_BUNDLE_IDENTIFIER)` as a URL type in Xcode.

#### Path B — HTTPS Universal Links

> **Agent instruction:** All four steps below are required — skipping any one will cause the callback redirect to fail silently after login.
>
> **Step B1 — Register callback URLs via Auth0 CLI:**
> Register both HTTPS and custom scheme so the app works in all scenarios.
>
> First, retrieve existing callback and logout URLs to avoid overwriting them:
> ```bash
> auth0 apps show CLIENT_ID --json --no-input > /tmp/auth0-app-info.json 2>&1
> ```
> Read `/tmp/auth0-app-info.json` to extract existing `callbacks` and `allowed_logout_urls` arrays.
>
> Then include any existing URLs as a comma-separated list alongside the new ones:
> ```bash
> auth0 apps update CLIENT_ID \
>   --callbacks "EXISTING_CALLBACKS,https://DOMAIN/ios/BUNDLE_ID/callback,BUNDLE_ID://DOMAIN/ios/BUNDLE_ID/callback" \
>   --logout-urls "EXISTING_LOGOUT_URLS,https://DOMAIN/ios/BUNDLE_ID/callback,BUNDLE_ID://DOMAIN/ios/BUNDLE_ID/callback" \
>   --no-input > /dev/null 2>&1
> ```
> If there are no existing URLs, omit the `EXISTING_` prefix and use only the new URLs.
>
> **Step B2 — Configure Device Settings via Auth0 CLI:**
> Extract `DEVELOPMENT_TEAM` from `project.pbxproj` (10-character value, e.g. `ABC12DE34F`). If not found, ask via `AskUserQuestion`: _"What is your Apple Team ID? (developer.apple.com → Account → Membership Details)"_
> ```bash
> auth0 api patch applications/CLIENT_ID \
>   --data '{"mobile":{"ios":{"team_id":"TEAM_ID","app_bundle_identifier":"BUNDLE_ID"}}}' \
>   --no-input > /dev/null 2>&1
> ```
> Auth0 will now host the `apple-app-site-association` file automatically — required for Universal Links to work on device.
>
> **Step B3 — Add Associated Domains entitlement in Xcode:**
> Add `com.apple.developer.associated-domains` to the app's `.entitlements` file with both `applinks:` and `webcredentials:` entries for the Auth0 domain. See [Setup Guide — Associated Domains](./references/setup.md#associated-domains-setup-https-universal-links) for the complete entitlements XML, Xcode capability steps, and build settings verification.
>
> **Step B4 — Use `.useHTTPS()` in the SDK:**
> ```swift
> Auth0.webAuth().useHTTPS()
> ```

### Step 4 — Implement Authentication

> **Agent instruction:** Search the project for `@main struct` (SwiftUI) or `AppDelegate`/`UIViewController` (UIKit) to detect the UI framework. If ambiguous, ask via `AskUserQuestion`: _"Does your app use SwiftUI or UIKit?"_ Then follow **only** the matching path below.
>
> **IMPORTANT — Never pass credentials in code:** Do NOT pass `clientId` or `domain` as arguments to `Auth0.webAuth()`, `Auth0.authentication()`, or any other SDK call. The SDK reads these values automatically from `Auth0.plist`. Always use the no-argument forms:
> ```swift
> Auth0.webAuth()           // ✓ reads Auth0.plist automatically
> Auth0.authentication()    // ✓ reads Auth0.plist automatically
>
> Auth0.webAuth(clientId: "...", domain: "...")      // ✗ never do this
> Auth0.authentication(clientId: "...", domain: "...") // ✗ never do this
> ```

#### SwiftUI

> **Agent instruction:** Create `AuthenticationService.swift` as an `ObservableObject`, then wire it into the app entry point and root view. Search for the `@main` struct and `ContentView` (or equivalent root view) and update them as shown.

```swift
// AuthenticationService.swift
import Auth0
import Combine

class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

    init() { isAuthenticated = credentialsManager.canRenew() }

    func login() async {
        do {
            let credentials = try await Auth0
                .webAuth()
                .useHTTPS()
                .scope("openid profile email offline_access")
                .start()
            _ = credentialsManager.store(credentials: credentials)
            await MainActor.run { isAuthenticated = true }
        } catch WebAuthError.userCancelled { }
        catch { print("Login failed: \(error)") }
    }

    func logout() async {
        do { try await Auth0.webAuth().useHTTPS().clearSession() }
        catch { print("Logout failed: \(error)") }
        _ = credentialsManager.clear()
        await MainActor.run { isAuthenticated = false }
    }
}
```

```swift
// @main App struct — inject AuthenticationService as environment object
@StateObject private var auth = AuthenticationService()
// In body: ContentView().environmentObject(auth)

// Root ContentView — branch on authentication state
@EnvironmentObject var auth: AuthenticationService
// In body: if auth.isAuthenticated { HomeView() } else { LoginView() }
```

For complete SwiftUI app lifecycle wiring, see [Integration Patterns](./references/integration.md#swiftui-app-lifecycle-recommended).

#### UIKit

> **Agent instruction:** Create `AuthenticationService.swift` as a plain class, then add login/logout calls to the relevant `UIViewController`. Also check whether the app uses `SFSafariViewController` — if so, add `WebAuthentication.resume(with:)` to `AppDelegate`/`SceneDelegate` (see note below).

```swift
// AuthenticationService.swift
import Auth0

class AuthenticationService {
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

    var isAuthenticated: Bool { credentialsManager.canRenew() }

    func login() async throws {
        let credentials = try await Auth0
            .webAuth()
            .useHTTPS()
            .scope("openid profile email offline_access")
            .start()
        _ = credentialsManager.store(credentials: credentials)
    }

    func logout() async throws {
        try await Auth0.webAuth().useHTTPS().clearSession()
        _ = credentialsManager.clear()
    }
}
```

```swift
// In your UIViewController
private let auth = AuthenticationService()

@IBAction func loginTapped(_ sender: UIButton) {
    Task {
        do {
            try await auth.login()
            await MainActor.run { navigateToHome() }
        } catch WebAuthError.userCancelled { }
        catch { print("Login failed: \(error)") }
    }
}

@IBAction func logoutTapped(_ sender: UIButton) {
    Task {
        do { try await auth.logout() }
        catch { print("Logout failed: \(error)") }
        await MainActor.run { navigateToLogin() }
    }
}
```

> **Note — SFSafariViewController only:** If the app uses `.provider(WebAuthentication.safariProvider())` instead of the default `ASWebAuthenticationSession`, add `WebAuthentication.resume(with: url)` to `AppDelegate.application(_:open:url:options:)` and `SceneDelegate.scene(_:openURLContexts:)`. See [Integration Patterns](./references/integration.md#uikit-app-lifecycle) for the exact code.

### Step 5 — Verify Build

> **Agent instruction:** Run a build to verify the integration compiles without errors:
> ```bash
> xcodebuild build -scheme YOUR_SCHEME -destination "platform=iOS Simulator,name=iPhone 16"
> ```
> If the build fails, review error messages and fix up to 5 times before asking the user.

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 CLI configuration, Auth0.plist, URL scheme registration, Associated Domains, CocoaPods/SPM/Carthage install
- **[Integration Patterns](./references/integration.md)** — Web Auth login/logout, CredentialsManager, biometric protection, MFA, organizations, error handling, SwiftUI/UIKit patterns
- **[API Reference & Testing](./references/api.md)** — Full API reference, configuration options, claims reference, testing checklist, troubleshooting

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Auth0 app type not set to **Native** | In Auth0 Dashboard, select "Native" when creating the application |
| Missing callback URL in Auth0 Dashboard | Add both `https://` Universal Link and `{bundle}://` custom scheme to Allowed Callback URLs and Logout URLs |
| `Auth0.plist` not added to Xcode target | Right-click file in Navigator → "Add Files to Target" → check your app target |
| Missing `offline_access` scope | Add `"offline_access"` to scope string to receive a refresh token for silent renewal |
| Tokens stored in `UserDefaults` | Always use `CredentialsManager` — it stores tokens in Keychain with access control |
| Calling `credentialsManager.credentials()` before `store()` | Store credentials from login result before attempting to retrieve |
| Opening `.xcodeproj` instead of `.xcworkspace` (CocoaPods) | Always open the `.xcworkspace` file after `pod install` |
| Not calling `clearSession()` on logout | Always call `clearSession()` to remove the Auth0 session cookie from the browser |
| Build error "No such module 'Auth0'" | Verify the package is added to the correct target; for CocoaPods, open `.xcworkspace` |
| Hardcoding domain/clientId in Swift source when they're in the prompt | Write them into `Auth0.plist` and call `Auth0.webAuth()` with no arguments — the SDK reads the plist automatically |

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## References

- [Auth0.swift GitHub](https://github.com/auth0/Auth0.swift)
- [iOS/macOS Quickstart](https://auth0.com/docs/quickstart/native/ios-swift)
- [Auth0.swift API Documentation](https://auth0.github.io/Auth0.swift/documentation/auth0/)
- [Auth0 Dashboard](https://manage.auth0.com)
- [EXAMPLES.md](https://github.com/auth0/Auth0.swift/blob/master/EXAMPLES.md)
