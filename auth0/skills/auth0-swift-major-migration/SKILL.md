---
name: auth0-swift-major-migration
description: >
  Use when upgrading an iOS or macOS app's Auth0.swift SDK from v2 to v3. Detects the current version, fetches the new SDK source to confirm API signatures, and applies only the breaking changes that affect real call sites — use even if the user says "update my Auth0 Swift SDK" or "migrate to Auth0.swift v3".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F504"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0.swift v3 Migration

Migrates an existing Auth0.swift v2 integration to v3. Every code change is gated on a search that confirms the project actually calls the affected API — if the project never uses `CredentialsManager`, no `CredentialsManager` code is touched. Changes follow the project's existing architecture and Apple platform conventions.

## When NOT to Use

- **New Auth0 integration** (no existing Auth0.swift): Use [auth0-swift](/auth0-swift)
- **Minor/patch update** (e.g., 2.17 → 2.18): Run `pod update Auth0` or update SPM — no migration needed
- **Android apps**: Use [auth0-android](/auth0-android)
- **React Native / Expo**: Use [auth0-react-native](/auth0-react-native) or [auth0-expo](/auth0-expo)

## Prerequisites

- Existing Auth0.swift v2 integration
- Xcode installed; project builds cleanly on the current version
- Project under git version control with a clean working tree

---

## Migration Workflow

> **Agent instruction:** Execute every step in order. The goal is a green build with the smallest correct changeset. Each code-change step is gated by the Step 4 file-reading audit — if the API was not found in the project's source files, skip the entire step for that area. Never add code the project doesn't already call.

---

### Step 1 — Pre-flight & Safety Backup

```bash
# 1a. Verify clean working tree — stop if there are uncommitted changes
git status --porcelain
```

If the output is non-empty, ask the user:
> *"You have uncommitted changes. Should I stash them before proceeding (`git stash`), or would you like to commit first?"*

```bash
# 1b. Create a safety branch the user can reset to at any time
git checkout -b auth0-v3-migration-backup
git checkout -
```

```bash
# 1c. Pick an available simulator, then confirm the project builds before touching anything
SIM=$(xcrun simctl list devices available -j \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
    phones=[dev for devs in d['devices'].values() for dev in devs \
            if 'iPhone' in dev.get('name','') and dev.get('isAvailable')]; \
    print(phones[0]['name'] if phones else 'iPhone 16')")
xcodebuild build \
  -scheme <SCHEME> \
  -destination "platform=iOS Simulator,name=${SIM}" \
  2>&1 | tail -5
```

If the build fails, stop. Ask the user to fix the existing issues first.

---

### Step 2 — Detect Current & Target Versions

Detect the current Auth0.swift version from the project's dependency files:

```bash
# Check Package.resolved first (most reliable)
find . -name "Package.resolved" | xargs grep -A3 '"auth0/Auth0.swift"\|Auth0.swift"' 2>/dev/null | grep '"version"'

# Fallback: Podfile.lock
grep "^  - Auth0 " Podfile.lock 2>/dev/null

# Fallback: Cartfile.resolved
grep "auth0/Auth0.swift" Cartfile.resolved 2>/dev/null

# Fallback: Package.swift
grep -A2 'auth0/Auth0.swift' Package.swift 2>/dev/null
```

**Resolve the target version.** There are two paths:

**Path A — the user passed a target version argument (`$ARGUMENTS`):**

Validate it against the published releases before using it. It must pass **all three** checks:

```bash
# List all published Auth0.swift v3 release tags
curl -s https://api.github.com/repos/auth0/Auth0.swift/releases | python3 -c "
import sys, json
releases = json.load(sys.stdin)
v3 = [r for r in releases if r['tag_name'].startswith('3') and not r['draft']]
for r in v3:
    print(r['tag_name'])
"
```

1. **Exists** — the requested tag appears in the published release list above.
2. **Correct major** — the tag is within the **v3** major line (starts with `3`). A `2.x` or any other major is not valid; reject it.
3. **Not a downgrade** — the tag is newer than the version detected in the project.

> **On any check failing, STOP and ask the user.** Do not silently fall back. For example:
> - *"`3.9.9` isn't a published Auth0.swift release. Published v3 releases are: `3.0.0-beta.2`, … . Please pass a valid v3 tag, or omit the argument to auto-resolve the latest v3 release."*
> - *"`2.10.0` is a v2 release, not v3. This skill migrates to v3. Pass a v3 tag (e.g. `3.0.0-beta.2`) or omit the argument."*
> - *"`3.0.0-beta.1` is older than the `3.0.0-beta.2` already in your project — that's a downgrade. Pass a newer v3 tag or omit the argument."*

**Path B — no argument: auto-resolve the latest v3 release (including pre-releases):**

```bash
# Newest v3.x release tag (stable or pre-release), most recent first
curl -s https://api.github.com/repos/auth0/Auth0.swift/releases | python3 -c "
import sys, json
releases = json.load(sys.stdin)
v3 = [r for r in releases if r['tag_name'].startswith('3') and not r['draft']]
if v3:
    print(v3[0]['tag_name'])
else:
    print('')
"
```

Record the result as `<TARGET_TAG>` and use it in every subsequent step.

> **If `<TARGET_TAG>` is a pre-release** (contains `-beta`, `-rc`, etc.), inform the user before continuing:
> *"The latest v3 release is `<TARGET_TAG>` (a pre-release). I'll migrate to that. You can pin a different tag by passing it as an argument: `auth0-swift-major-migration <tag>`."*
>
> **If no v3 release exists** (the resolver returns empty), stop and tell the user there is no published v3 release to migrate to.


---

### Step 3 — Fetch & Read the v3 SDK Source

Fetch the actual Swift source for the target tag. The signatures here are the authoritative reference for every change made in Step 6.

```bash
TAG=<TARGET_TAG>   # the version the developer chose in Step 2, e.g. 3.0.0-beta.2

# List all public Swift files in the SDK
curl -s "https://api.github.com/repos/auth0/Auth0.swift/git/trees/${TAG}?recursive=1" \
  | python3 -c "
import sys, json
for item in json.load(sys.stdin).get('tree', []):
    if item['path'].startswith('Auth0/') and item['path'].endswith('.swift'):
        print(item['path'])
"

# Fetch core public API files
for FILE in WebAuth.swift CredentialsManager.swift Authentication.swift \
            Credentials.swift UserProfile.swift Requestable.swift \
            CredentialsStorage.swift CredentialsManagerError.swift WebAuthError.swift; do
    URL="https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/${FILE}"
    CONTENT=$(curl -sf "$URL")
    [ -n "$CONTENT" ] && echo "=== $FILE ===" && echo "$CONTENT"
done

# MFA files live in a subdirectory
for FILE in MFA/MFAClient.swift MFA/MFAErrors.swift; do
    URL="https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/${FILE}"
    CONTENT=$(curl -sf "$URL")
    [ -n "$CONTENT" ] && echo "=== $FILE ===" && echo "$CONTENT"
done
```

Read the fetched source and note:
- Every public method signature that changed (return type, parameters, `throws` added)
- Types that were renamed or removed
- Protocol requirements that changed
- Default parameter values that changed

This is the ground truth. Every change in Step 6 must match a real signature in these files.

---

### Step 4 — Audit Which Auth0 APIs the Project Uses

**Find all Swift files that import Auth0 — these are the scope of the migration:**
```bash
grep -rl "import Auth0" --include="*.swift" .
```

**Read every file from that list.** Do not grep for specific API patterns — read the full source so you can see exactly how `Auth0`, `webAuth`, `authentication`, `credentialsManager`, and any Auth0 types are used, including calls with domain/clientId parameters, chained builder calls, and any custom conformances.

For each file, identify:

| What to look for | Why it matters |
|---|---|
| Any call to `webAuth()`, `webAuth(domain:)`, `webAuth(domain:clientId:)` | §6.1 – `clearSession` rename; §6.14 – default scope |
| Any call to `.clearSession(` | §6.1 — rename to `logout` |
| Switch/catch on `WebAuthError` with explicit case names | §6.2 — removed and new cases |
| `DispatchQueue.main.async` or `MainActor.run` wrapping an Auth0 callback | §6.3 — removable in v3 |
| Any stored `Request<…>` type annotation (not just chained `.start(…)`) | §6.4 — type changed to `Requestable` |
| Test mocks conforming to `Authentication`, `MFAClient`, or `Requestable` | §6.4 — return type + `@MainActor` update |
| Any call to `credentialsManager.store(` | §6.5 — Bool → throws |
| Any call to `credentialsManager.clear()` or `credentialsManager.clear(forAudience:` | §6.6 — Bool → throws (both overloads) |
| Any access to `credentialsManager.user` (property, not method) | §6.7 — replaced by `userProfile()` method |
| Any call to `credentialsManager.revoke(` | §6.8 — new error paths |
| Any type annotation or declaration using `UserInfo` | §6.9 — renamed to `UserProfile` |
| Any access to `.expiresIn` on a `Credentials`-like object | §6.10 — renamed to `expiresAt` |
| Any type conforming to `CredentialsStorage` | §6.11 — method signatures changed |
| Any call to `Auth0.users(` or `Auth0.users(token:` | §6.12 — Management client removed |
| `login(withOTP:`, `login(withOOBCode:`, `login(withRecoveryCode:`, `multifactorChallenge(` | §6.13 — MFA methods removed |
| Any call to `webAuth()` that does **not** chain `.scope(` | §6.14 — default scope changed |
| Any call to `credentialsManager.credentials(` without explicit `minTTL:` parameter | §6.15 — default minTTL changed from 0 to 60 seconds |

Build a checklist: **"This project uses: [list]"** and **"This project does NOT use: [list]"**. Only work through the §6.x sections that appear in the "uses" list. Skip the rest entirely.

---

### Step 5 — Update the SDK Dependency

Apply only the matching package manager.

Use the `<TARGET_TAG>` chosen in Step 2. For stable releases (`3.x.y` with no suffix), use a range specifier. For pre-releases (`3.x.y-beta.z`), pin the exact tag — package managers treat pre-release versions as out-of-range for `~>` / `from:` rules.

**Swift Package Manager (Package.swift):**
```swift
// Stable v3 — range specifier picks up all 3.x.y patches
.package(url: "https://github.com/auth0/Auth0.swift", from: "3.0.0")

// Pre-release / specific beta — exact tag required
.package(url: "https://github.com/auth0/Auth0.swift", exact: "3.0.0-beta.2")
```

Then resolve:
```bash
swift package resolve
```

**CocoaPods (Podfile):**
```ruby
# Stable v3
pod 'Auth0', '~> 3.0'

# Pre-release / specific beta — pin the exact version
pod 'Auth0', '3.0.0-beta.2'
```

Then:
```bash
pod update Auth0
```

**Carthage (Cartfile):**
```plaintext
# Stable v3
github "auth0/Auth0.swift" ~> 3.0

# Pre-release / specific beta — pin the exact tag
github "auth0/Auth0.swift" "3.0.0-beta.2"
```

Then:
```bash
carthage update Auth0.swift --use-xcframeworks
```

**Xcode-managed SPM** (no `Package.swift` at root):
- *Stable:* File → Packages → Update to Latest Package Versions, then verify the version rule is *Up to Next Major* from 3.0.0.
- *Pre-release / specific beta:* File → Packages → Update to Latest Package Versions won't resolve a beta unless the dependency already pins an exact version. Tell the user to change the version rule to *Exact Version* and enter `3.0.0-beta.2` (or the chosen tag).

Do **not** build yet — apply all known code changes first.

---

### Step 6 — Apply Breaking Changes

> **Agent instruction:** Work through only the §6.x sections that matched during the Step 4 file-reading audit. Skip every section whose API the project does not use — do not touch those files.
>
> Apply each change exactly as shown. Do not alter surrounding code, rename variables, reformat, or modernise code that isn't being migrated. Match the project's existing style: completion handler → completion handler, async/await → async/await, Combine → Combine.

---

#### 6.1 — `WebAuth.clearSession()` → `WebAuth.logout()`

**Applies if:** Step 4 found any call to `.clearSession(` in the project's source files.

The `clearSession(federated:)` method was renamed to `logout(federated:)`. The parameter and its default value are unchanged.

**Completion handler:**
```swift
// v2
Auth0.webAuth().clearSession { result in
    switch result {
    case .success: handleLogoutSuccess()
    case .failure(let error): handleError(error)
    }
}

// v3
Auth0.webAuth().logout { result in
    switch result {
    case .success: handleLogoutSuccess()
    case .failure(let error): handleError(error)
    }
}
```

**async/await:**
```swift
// v2
try await Auth0.webAuth().clearSession()

// v3
try await Auth0.webAuth().logout()
```

**Combine:**
```swift
// v2
Auth0.webAuth().clearSession()
    .sink(receiveCompletion: { ... }, receiveValue: { ... })
    .store(in: &cancellables)

// v3
Auth0.webAuth().logout()
    .sink(receiveCompletion: { ... }, receiveValue: { ... })
    .store(in: &cancellables)
```

**With `federated: true`:** The parameter name is the same — just rename the method:
```swift
// v2
try await Auth0.webAuth().clearSession(federated: true)

// v3
try await Auth0.webAuth().logout(federated: true)
```

---

#### 6.2 — `WebAuthError` — removed and new cases in exhaustive `switch` statements

**Applies if:** Step 4 found any `switch` or `catch` on `WebAuthError` with explicit case names in the project's source files.

Two `WebAuthError` cases were **removed** in v3. If the project has an exhaustive `switch` over `WebAuthError` (or explicitly matches these cases), the build will fail.

Three **new** cases were added to surface previously hidden failures.

**Removed cases (will no longer compile if matched):**

| v2 case | v3 behaviour |
|---|---|
| `.invalidInvitationURL` | Removed — now surfaces as `.unknown` |
| `.pkceNotAllowed` | Removed — now surfaces as `.unknown` |

**New cases (can now appear in `catch`/`switch` blocks):**

| v3 case | When it fires |
|---|---|
| `.authenticationFailed` | Server-side failure: wrong password, MFA required, account locked, etc. |
| `.codeExchangeFailed` | Token exchange failed: network issue, invalid grant, backend error |
| `.credentialsManagerError` | Credentials manager failed to store or clear credentials after login/logout; access the underlying error via `.cause` |

**Migration — remove the deleted cases from switch statements:**
```swift
// v2 — exhaustive switch including cases that no longer exist
Auth0.webAuth().start { result in
    switch result {
    case .success(let credentials):
        handle(credentials)
    case .failure(let error):
        switch error {
        case .userCancelled:
            break  // user dismissed — no action needed
        case .pkceNotAllowed:
            // ❌ compile error in v3 — remove this case
            showConfigError("PKCE not allowed")
        default:
            showError(error)
        }
    }
}

// v3 — remove the deleted cases; handle the new ones where appropriate
Auth0.webAuth().start { result in
    switch result {
    case .success(let credentials):
        handle(credentials)
    case .failure(let error):
        switch error {
        case .userCancelled:
            break  // user dismissed — no action needed
        case .authenticationFailed:
            // server rejected the login — show an appropriate message
            showError("Login failed. Please check your credentials.")
        case .codeExchangeFailed:
            // token exchange failed — network or server issue
            showError("Something went wrong. Please try again.")
        case .credentialsManagerError:
            // login succeeded but credentials could not be stored
            // the user is authenticated in memory but will need to log in again next launch
            // access the underlying error via error.cause (WebAuthError.cause: Error?)
            reportToMonitoring(error.cause)
            showError("Could not save your session.")
        default:
            showError(error)
        }
    }
}
```

**If the project uses async/await and catches specific cases:**
```swift
// v2
do {
    let credentials = try await Auth0.webAuth().start()
    handle(credentials)
} catch WebAuthError.userCancelled {
    break
} catch WebAuthError.pkceNotAllowed {
    // ❌ compile error in v3 — remove this catch
    showConfigError()
} catch {
    showError(error)
}

// v3 — remove deleted cases; add new ones if the project should handle them
do {
    let credentials = try await Auth0.webAuth().start()
    handle(credentials)
} catch WebAuthError.userCancelled {
    break
} catch WebAuthError.authenticationFailed {
    showError("Login failed. Please check your credentials.")
} catch WebAuthError.codeExchangeFailed {
    showError("Something went wrong. Please try again.")
} catch {
    showError(error)
}
```

> The new cases `.authenticationFailed` and `.codeExchangeFailed` are not required to be handled explicitly — a `default:` branch already catches them. Only add explicit cases if the project wants to show different UI or telemetry for those failures.

---

#### 6.3 — Remove redundant main-thread dispatch around WebAuth and CredentialsManager callbacks

**Applies if:** Step 4 found `DispatchQueue.main.async` or `MainActor.run` wrapping an Auth0 callback body.

In v3, all completion-handler callbacks, Combine publishers, and async/await methods deliver results on the main thread (they are `@MainActor`). Wrapping callback bodies in `DispatchQueue.main.async { }` or `await MainActor.run { }` is no longer necessary and can be removed.

**Completion handler callback — remove the dispatch wrapper:**
```swift
// v2 — dispatch to main manually
credentialsManager.credentials { result in
    DispatchQueue.main.async {
        switch result {
        case .success(let credentials):
            self.accessToken = credentials.accessToken
            self.isAuthenticated = true
        case .failure(let error):
            self.authError = error
        }
    }
}

// v3 — callback already arrives on main thread
credentialsManager.credentials { result in
    switch result {
    case .success(let credentials):
        self.accessToken = credentials.accessToken
        self.isAuthenticated = true
    case .failure(let error):
        self.authError = error
    }
}
```

**async/await — remove the MainActor.run wrapper:**
```swift
// v2
let credentials = try await Auth0.webAuth().start()
await MainActor.run {
    self.isAuthenticated = true
}

// v3 — start() is @MainActor; already on main thread after the await
let credentials = try await Auth0.webAuth().start()
self.isAuthenticated = true
```

> Only remove dispatch wrappers that are **solely** protecting Auth0 callback bodies. If a `DispatchQueue.main.async` block also dispatches unrelated UI work, remove only what's attributable to the Auth0 callback.

---

#### 6.4 — `Authentication` / `MFAClient` methods return `Requestable` instead of `Request` — app code and test mocks

**Applies if:** Step 4 found either (a) a stored `Request<…>` type annotation in app code, or (b) test/mock files with types conforming to `Authentication`, `MFAClient`, or `Requestable`.

In v3, all `Authentication` and `MFAClient` methods return protocol types rather than the concrete `Request` struct:

- **Credential-returning methods** (login, codeExchange, renew, ssoExchange, etc.) now return `any TokenRequestable<T, E>`
- **All other methods** (signup, resetPassword, userInfo, jwks, etc.) now return `any Requestable<T, E>`

**Impact on app code:** Call sites that chain directly to `.start(_:)` — the overwhelming majority — compile without any change. The only app code that breaks is a stored `Request<>` type annotation:

```swift
// v2 — storing the request in a typed variable
let request: Request<Credentials, AuthenticationError> = Auth0
    .authentication()
    .login(usernameOrEmail: email, password: password,
           realmOrConnection: "Username-Password-Authentication",
           audience: audience, scope: scope)
request.start { result in ... }

// v3 — update the type annotation to the protocol type
// For credential-returning methods:
let request: any TokenRequestable<Credentials, AuthenticationError> = Auth0
    .authentication()
    .login(usernameOrEmail: email, password: password,
           realmOrConnection: "Username-Password-Authentication",
           audience: audience, scope: scope)
request.start { result in ... }

// For non-credential methods (signup, resetPassword, userInfo, jwks):
let request: any Requestable<DatabaseUser, AuthenticationError> = Auth0
    .authentication()
    .signup(email: email, password: password, connection: connection)
request.start { result in ... }

// Most common pattern — chaining directly, no annotation needed, no change required:
Auth0.authentication()
    .login(usernameOrEmail: email, password: password,
           realmOrConnection: "Username-Password-Authentication",
           audience: audience, scope: scope)
    .start { result in ... }  // ✅ unchanged
```

**Credential-returning methods that now return `any TokenRequestable` (full list):**
- `login(email:code:audience:scope:)`
- `login(phoneNumber:code:audience:scope:)`
- `login(usernameOrEmail:password:realmOrConnection:audience:scope:)`
- `loginDefaultDirectory(withUsername:password:audience:scope:)`
- `login(appleAuthorizationCode:fullName:profile:audience:scope:)`
- `login(facebookSessionAccessToken:profile:audience:scope:)`
- `login(passkey:challenge:connection:audience:scope:organization:)` — two overloads (sign in + sign up with passkey)
- `codeExchange(withCode:codeVerifier:redirectURI:)`
- `renew(withRefreshToken:audience:scope:)`
- `ssoExchange(withRefreshToken:)`
- `customTokenExchange(subjectToken:subjectTokenType:audience:scope:organization:parameters:)`
- `MFAClient.verify(otp:mfaToken:)`, `verify(oobCode:bindingCode:mfaToken:)`, `verify(recoveryCode:mfaToken:)`

**Impact on test targets — custom `Authentication` mocks:**

If the project's test target has a mock or stub conforming to the `Authentication` or `MFAClient` protocol, two changes are required:

1. **Return type:** Change `Request<T, E>` to `any TokenRequestable<T, E>` (credential methods) or `any Requestable<T, E>` (other methods)
2. **`start(_:)` callback:** Add `@MainActor` to match the updated `Requestable` protocol requirement

```swift
// v2 — mock Authentication conformance in tests
class MockAuthentication: Authentication {
    var credentialsResult: Result<Credentials, AuthenticationError> = .failure(.init(info: [:], statusCode: 0))

    func login(usernameOrEmail username: String,
               password: String,
               realmOrConnection realm: String,
               audience: String?,
               scope: String) -> Request<Credentials, AuthenticationError> {
        // ❌ compile error in v3 — Request is no longer the return type
        return Request(session: URLSession.shared, ...) // v2 internal — no longer works
    }
}

// v2 — mock Requestable used as stub
struct MockRequest<T, E: Auth0Error>: Requestable {
    let result: Result<T, E>
    func start(_ callback: @escaping (Result<T, E>) -> Void) {
        // ❌ @MainActor missing — does not conform to v3 Requestable
        callback(result)
    }
}

// v3 — updated mock
struct MockRequest<T, E: Auth0Error>: Requestable {
    let result: Result<T, E>
    // ✅ Add @MainActor to match the protocol; dispatch via Task to satisfy @MainActor isolation
    func start(_ callback: @escaping @MainActor (Result<T, E>) -> Void) {
        Task { @MainActor in callback(result) }
    }
}

// v3 — updated Authentication mock returning the correct protocol type
class MockAuthentication: Authentication {
    var credentialsResult: Result<Credentials, AuthenticationError> = .failure(.init(info: [:], statusCode: 0))

    func login(usernameOrEmail username: String,
               password: String,
               realmOrConnection realm: String,
               audience: String?,
               scope: String) -> any TokenRequestable<Credentials, AuthenticationError> {
        // ✅ Return MockTokenRequest, not Request
        return MockTokenRequest(result: credentialsResult)
    }
}

// v3 — TokenRequestable mock (for credential-returning methods)
struct MockTokenRequest<T, E: Auth0Error>: TokenRequestable {
    typealias ResultType = T
    typealias ErrorType = E

    let result: Result<T, E>

    func start(_ callback: @escaping @MainActor (Result<T, E>) -> Void) {
        Task { @MainActor in callback(result) }
    }

    // TokenRequestable adds these claim-validation builder methods — return self
    func validateClaims() -> any TokenRequestable<T, E> { self }
    func withLeeway(_ leeway: Int) -> any TokenRequestable<T, E> { self }
    func withIssuer(_ issuer: String) -> any TokenRequestable<T, E> { self }
    func withNonce(_ nonce: String?) -> any TokenRequestable<T, E> { self }
    func withMaxAge(_ maxAge: Int?) -> any TokenRequestable<T, E> { self }
    func withOrganization(_ organization: String?) -> any TokenRequestable<T, E> { self }
}
```

> The `MockTokenRequest` stub above stubs out all `TokenRequestable` builder methods by returning `self`. In most tests, `validateClaims()` and the `with*` modifiers are never called, so returning `self` is correct. If a specific test verifies claim validation behaviour, implement those methods properly.

---

#### 6.5 — `CredentialsManager.store(credentials:)` — Bool return → throws

**Applies if:** Step 4 found any call to `credentialsManager.store(credentials:` in the project's source files.

`store(credentials:)` previously returned `Bool`. In v3 it throws on failure and returns `Void` on success.

**If the project checked the return value:**
```swift
// v2
if credentialsManager.store(credentials: credentials) {
    print("Stored successfully")
} else {
    print("Store failed")
}

// v3 — use do-catch; map the error into the project's existing error handler
do {
    try credentialsManager.store(credentials: credentials)
} catch {
    // replace with whatever logging/error handling the project already uses
    handleError(error)
}
```

**If the project discarded the return value:**
```swift
// v2 — silently discarded
_ = credentialsManager.store(credentials: credentials)

// v3 — try? discards the error the same way; use if the project didn't handle failures before
try? credentialsManager.store(credentials: credentials)
```

> Prefer `do-catch` over `try?` when the project has an error-handling pattern to route into. Use `try?` only to preserve intentional silent-discard behaviour.

---

#### 6.6 — `CredentialsManager.clear()` and `clear(forAudience:scope:)` — Bool return → throws

**Applies if:** Step 4 found any call to `credentialsManager.clear()` or `credentialsManager.clear(forAudience:` in the project's source files.

Both overloads previously returned `Bool`. In v3 both throw:
- `clear() throws` — clears the main stored credentials
- `clear(forAudience:scope:) throws` — clears API credentials for a specific audience

```swift
// v2
_ = credentialsManager.clear()
_ = credentialsManager.clear(forAudience: "https://api.example.com")

// v3
try? credentialsManager.clear()
try? credentialsManager.clear(forAudience: "https://api.example.com")
// or, if the project handles errors:
do {
    try credentialsManager.clear()
} catch {
    handleError(error)
}
```

---

#### 6.7 — `CredentialsManager.user` property → `userProfile()` throwing method

**Applies if:** Step 4 found any access to `credentialsManager.user` as a property (not a method call) in the project's source files.

The `user: UserInfo?` computed property was replaced by `userProfile() throws -> UserProfile?` (see also §6.9 for the type rename).

```swift
// v2 — property access, returns UserInfo?
func currentUser() -> UserInfo? {
    return credentialsManager.user
}

// v3 — method call that throws, returns UserProfile?
func currentUser() -> UserProfile? {
    return try? credentialsManager.userProfile()
}

// v3 — if the project needs to surface errors:
func loadUser() throws {
    let profile = try credentialsManager.userProfile()
    self.userProfile = profile
}
```

---

#### 6.8 — `CredentialsManager` async methods — new error paths from throwing storage

**Applies if:** Step 4 found any call to `credentialsManager.revoke(` in the project's source files.

Because `CredentialsManager` storage methods now throw, several async methods gain new failure paths that were previously silently swallowed. The most significant is `revoke()`. Only update error-handling code that the project actually writes — call sites that already use a `default:` branch need no change.

**New errors that can now surface from `revoke()`:**

| New error | When it fires | What to do |
|---|---|---|
| `.noCredentials` | `getEntry` threw — no credentials in storage, nothing to revoke | Treat as already logged out; navigate to login |
| `.revokeFailed` | Network call to revoke the refresh token failed | The token may still be active on the server; show an error |
| `.clearFailed` | Revocation succeeded but Keychain delete failed | Treat as logged out — the token is no longer valid server-side |

```swift
// v2 — only .revokeFailed was possible; missing credentials returned .success silently
credentialsManager.revoke { result in
    switch result {
    case .success:
        navigateToLogin()
    case .failure(let error):
        showError(error)  // only .revokeFailed reached here
    }
}

// v3 — new cases surface; update the switch if the project checks specific cases
credentialsManager.revoke { result in
    switch result {
    case .success:
        navigateToLogin()
    case .failure(let error):
        switch error {
        case .noCredentials:
            // nothing was stored — already effectively logged out
            navigateToLogin()
        case .revokeFailed:
            // server revocation failed — refresh token may still be active
            showError("Could not revoke your session. Please try again.")
        case .clearFailed:
            // token revoked server-side but Keychain delete failed
            // treat as logged out — token is no longer valid
            navigateToLogin()
        default:
            showError(error)
        }
    }
}
```

**New errors that can now surface from `credentials()`, `renew()`, `apiCredentials()`, `ssoCredentials()`:**

| New error | When it fires |
|---|---|
| `.noCredentials` | `getEntry` throws (e.g., Keychain item not found) — previously swallowed by `try?` |
| `.renewFailed` | Refresh token renewal request failed — network error, invalid/expired refresh token |
| `.storeFailed` | Keychain write fails when saving renewed credentials |

These only matter if the project's existing `catch`/`failure` handler needs to distinguish these cases. If it uses a generic fallback, no change is needed.

```swift
// v3 — if the project wants to distinguish storage failures from network failures:
credentialsManager.credentials { result in
    switch result {
    case .success(let credentials):
        use(credentials)
    case .failure(let error):
        switch error {
        case .noCredentials, .renewFailed:
            // credentials missing or refresh failed — force re-login
            navigateToLogin()
        case .storeFailed:
            // renewed successfully but couldn't save — credentials valid in memory this session
            // user will be asked to log in again on next launch
            reportToMonitoring(error)
            use(/* last known credentials if available */)
        default:
            showError(error)
        }
    }
}
```

> Only add these new `case` branches if the project currently has a `switch` on `CredentialsManagerError` that would benefit from handling them differently. A `default:` branch already handles them correctly without any change.

---

#### 6.9 — `UserInfo` → `UserProfile` type rename

**Applies if:** Step 4 found any type annotation, function signature, or variable declaration referencing `UserInfo` in the project's source files.

The `UserInfo` type was renamed to `UserProfile`. Update every type annotation, function signature, and variable declaration that references `UserInfo`.

```swift
// v2
var currentUser: UserInfo?
func showProfile(_ profile: UserInfo) { ... }
func fetchUser() -> UserInfo? { ... }

// v3
var currentUser: UserProfile?
func showProfile(_ profile: UserProfile) { ... }
func fetchUser() -> UserProfile? { ... }
```

If the project calls `Auth0.authentication().userInfo(withAccessToken:)`, the method name is unchanged but the return type changed:
```swift
// v2 — returns Request<UserInfo, AuthenticationError>
Auth0.authentication()
    .userInfo(withAccessToken: accessToken)
    .start { (result: Result<UserInfo, AuthenticationError>) in ... }

// v3 — returns Request<UserProfile, AuthenticationError>
Auth0.authentication()
    .userInfo(withAccessToken: accessToken)
    .start { (result: Result<UserProfile, AuthenticationError>) in ... }
```

---

#### 6.10 — `Credentials.expiresIn` → `Credentials.expiresAt`

**Applies if:** Step 4 found any access to `.expiresIn` on a `Credentials`, `APICredentials`, or `SSOCredentials` object.

The `expiresIn: Date` property on `Credentials`, `APICredentials`, and `SSOCredentials` was renamed to `expiresAt: Date`. The underlying JSON key is unchanged; only the Swift property name changed.

```swift
// v2
let expiry: Date = credentials.expiresIn

// v3
let expiry: Date = credentials.expiresAt
```

---

#### 6.11 — `CredentialsStorage` custom implementation — methods now throw

**Applies if:** Step 4 found a type conforming to `CredentialsStorage` in the project's source files. Skip if the project only passes a `SimpleKeychain` instance — the default storage needs no change.

Only applies if the project provides a **custom** `CredentialsStorage` implementation (i.e., a type conforming to the protocol — not just using the default `SimpleKeychain`). Skip if the project only passes a `SimpleKeychain` instance.

The protocol changed from Bool/Data? returns to throwing methods, and added a new required `deleteAllEntries()`.

```swift
// v2 — protocol conformance
final class AppKeychain: CredentialsStorage {
    func getEntry(forKey key: String) -> Data? {
        return Keychain.shared.read(key: key)
    }

    func setEntry(_ data: Data, forKey key: String) -> Bool {
        return Keychain.shared.write(data, forKey: key)
    }

    func deleteEntry(forKey key: String) -> Bool {
        return Keychain.shared.delete(key: key)
    }
}

// v3 — methods throw; deleteAllEntries() required
final class AppKeychain: CredentialsStorage {
    func getEntry(forKey key: String) throws -> Data {
        guard let data = Keychain.shared.read(key: key) else {
            throw CredentialsManagerError.noCredentials
        }
        return data
    }

    func setEntry(_ data: Data, forKey key: String) throws {
        guard Keychain.shared.write(data, forKey: key) else {
            throw CredentialsManagerError.storeFailed
        }
    }

    func deleteEntry(forKey key: String) throws {
        guard Keychain.shared.delete(key: key) else {
            throw CredentialsManagerError.revokeFailed
        }
    }

    func deleteAllEntries() throws {
        Keychain.shared.deleteAll()
    }
}
```

> The `CredentialsStorage` protocol declares its methods as `throws` with no specific error type — you can throw any `Error`. The example above uses `CredentialsManagerError` cases for illustration only; your implementation should throw an error type that makes sense for your storage backend. Verify the `CredentialsManagerError` case names in the SDK source fetched in Step 3 if you choose to reuse them.

---

#### 6.12 — Management client removed

**Applies if:** Step 4 found any call to `Auth0.users(` or `Auth0.users(token:` in the project's source files.

`Auth0.users(token:)` and the entire `Users` management client were removed from the SDK in v3. Do **not** silently delete any call sites — add a `TODO` comment and surface this in the migration summary.

```swift
// v2 — direct Management API call in the app
Auth0
    .users(token: managementToken)
    .patch(userId, userPatch: UserPatchAttributes(name: newName))
    .start { result in
        switch result {
        case .success: print("Updated")
        case .failure(let error): print(error)
        }
    }

// v3 — Management client removed; add TODO and preserve intent
// TODO: Auth0.swift v3 removed the Management client.
// Replace this with a call to your own backend endpoint, which
// calls the Auth0 Management API using a machine-to-machine token.
// NEVER embed a Management API token in the client app.
// See: https://auth0.com/docs/secure/tokens/access-tokens/management-api-access-tokens
```

This **requires backend work** — record it in the Step 9 summary.

---

#### 6.13 — MFA methods removed from `Authentication` → migrate to `MFAClient`

**Applies if:** Step 4 found any call to `login(withOTP:`, `login(withOOBCode:`, `login(withRecoveryCode:`, or `multifactorChallenge(` — or test mocks conforming to `MFAClient` — in the project's source files.

The four MFA methods on the `Authentication` protocol were removed in v3. They are replaced by the dedicated `MFAClient` protocol, accessible via `Auth0.mfa()`:

| v2 (`Authentication`) | v3 (`MFAClient`) |
|---|---|
| `authentication().login(withOTP: otp, mfaToken: token)` | `mfa().verify(otp: otp, mfaToken: token)` |
| `authentication().login(withOOBCode: code, mfaToken: token, bindingCode: binding)` | `mfa().verify(oobCode: code, bindingCode: binding, mfaToken: token)` |
| `authentication().login(withRecoveryCode: code, mfaToken: token)` | `mfa().verify(recoveryCode: code, mfaToken: token)` |
| `authentication().multifactorChallenge(mfaToken: token, types: types, authenticatorId: id)` | `mfa().challenge(with: id, mfaToken: token)` |

**The `mfaToken` itself** still comes from the same place — an `AuthenticationError` where `error.isMultifactorRequired == true` returns the token via `error.mfaRequiredErrorPayload?.mfaToken`.

---

**OTP (TOTP authenticator app):**
```swift
// v2
Auth0.authentication()
    .login(withOTP: otpCode, mfaToken: mfaToken)
    .start { result in
        switch result {
        case .success(let credentials): storeCredentials(credentials)
        case .failure(let error): showError(error)
        }
    }

// v3 — verify returns any TokenRequestable<Credentials, MFAVerifyError>
Auth0.mfa()
    .verify(otp: otpCode, mfaToken: mfaToken)
    .start { result in
        switch result {
        case .success(let credentials): storeCredentials(credentials)
        case .failure(let error): showError(error)
        }
    }

// async/await
let credentials = try await Auth0.mfa().verify(otp: otpCode, mfaToken: mfaToken).start()
```

---

**OOB (SMS / email code):**
```swift
// v2
Auth0.authentication()
    .login(withOOBCode: oobCode, mfaToken: mfaToken, bindingCode: bindingCode)
    .start { result in ... }

// v3 — parameter order changed: oobCode first, bindingCode second
Auth0.mfa()
    .verify(oobCode: oobCode, bindingCode: bindingCode, mfaToken: mfaToken)
    .start { result in ... }
```

---

**Recovery code:**
```swift
// v2
Auth0.authentication()
    .login(withRecoveryCode: recoveryCode, mfaToken: mfaToken)
    .start { result in ... }

// v3
Auth0.mfa()
    .verify(recoveryCode: recoveryCode, mfaToken: mfaToken)
    .start { result in ... }
```

---

**MFA challenge (request an OOB code to be sent):**
```swift
// v2
Auth0.authentication()
    .multifactorChallenge(mfaToken: mfaToken,
                          types: ["oob"],
                          authenticatorId: authenticatorId)
    .start { result in ... }

// v3 — types parameter removed; pass authenticatorId directly
Auth0.mfa()
    .challenge(with: authenticatorId, mfaToken: mfaToken)
    .start { result in ... }
```

---

**Handling the MFA required error to obtain the mfaToken (unchanged between v2 and v3):**
```swift
Auth0.authentication()
    .login(usernameOrEmail: email,
           password: password,
           realmOrConnection: "Username-Password-Authentication",
           audience: audience,
           scope: scope)
    .start { result in
        switch result {
        case .success(let credentials):
            storeCredentials(credentials)
        case .failure(let error) where error.isMultifactorRequired:
            // mfaToken extracted the same way in both v2 and v3
            if let mfaToken = error.mfaRequiredErrorPayload?.mfaToken {
                presentMFAChallenge(mfaToken: mfaToken)
            }
        case .failure(let error):
            showError(error)
        }
    }
```

---

**Error type changed: `AuthenticationError` → `MFAVerifyError`**

The verify methods on `MFAClient` return `any TokenRequestable<Credentials, MFAVerifyError>`. If the project previously matched specific `AuthenticationError` cases in MFA failure handlers, map them onto `MFAVerifyError`:

```swift
// v2 — MFA failures came as AuthenticationError
Auth0.authentication()
    .login(withOTP: otp, mfaToken: mfaToken)
    .start { result in
        switch result {
        case .success(let credentials): storeCredentials(credentials)
        case .failure(let error as AuthenticationError):
            if error.isMultifactorCodeInvalid {
                showError("Invalid code. Please try again.")
            } else {
                showError(error.debugDescription)
            }
        }
    }

// v3 — failures come as MFAVerifyError; fetch MFAErrors.swift for all cases
Auth0.mfa()
    .verify(otp: otp, mfaToken: mfaToken)
    .start { result in
        switch result {
        case .success(let credentials): storeCredentials(credentials)
        case .failure(let error):
            // Check the MFAVerifyError cases in Auth0/MFA/MFAErrors.swift
            // for the exact case names available in the target SDK version
            showError(error.debugDescription)
        }
    }
```

> Fetch `Auth0/MFA/MFAErrors.swift` from the target tag (Step 3) and read the `MFAVerifyError` cases to map any specific error handling the project currently does. Do not guess error case names — read them from the source.

---

**Test mocks for `MFAClient`:**

If the project's test target has a mock conforming to `MFAClient`, update method return types and add `@MainActor` to `start(_:)` (same pattern as §6.4 for `Authentication` mocks):

```swift
// v3 — mock MFAClient in tests
struct MockMFAClient: MFAClient {
    var verifyResult: Result<Credentials, MFAVerifyError>

    func verify(otp: String,
                mfaToken: String) -> any TokenRequestable<Credentials, MFAVerifyError> {
        return MockTokenRequest(result: verifyResult)
    }

    func verify(oobCode: String,
                bindingCode: String?,
                mfaToken: String) -> any TokenRequestable<Credentials, MFAVerifyError> {
        return MockTokenRequest(result: verifyResult)
    }

    func verify(recoveryCode: String,
                mfaToken: String) -> any TokenRequestable<Credentials, MFAVerifyError> {
        return MockTokenRequest(result: verifyResult)
    }

    func challenge(with authenticatorId: String,
                   mfaToken: String) -> any Requestable<MFAChallenge, MfaChallengeError> {
        // Fetch MFAClient.swift from the target tag to find MFAChallenge's initializer,
        // then construct a real fixture or return .failure for tests that don't exercise this path
        return MockRequest(result: .failure(/* MfaChallengeError case from MFAErrors.swift */))
    }
    // implement remaining MFAClient requirements using the same pattern
}
```

> Use the `MockTokenRequest` and `MockRequest` structs from §6.4. The `MFAClient` protocol also requires `getAuthenticators`, `enroll(mfaToken:phoneNumber:)`, `enroll(mfaToken:)`, and `enroll(mfaToken:email:)` — stub them the same way, using the return types from `MFAClient.swift`.

List all migrated MFA flows in the Step 9 summary and ask the user to **re-test every MFA flow end-to-end** (OTP, OOB, recovery code, challenge request) against their tenant configuration.

---

#### 6.14 — Default scope now includes `offline_access`

**Applies if:** Step 4 found any call to `webAuth()`, `webAuth(domain:)`, or `webAuth(domain:clientId:)` — but only for call chains that do **not** already have a `.scope(…)` modifier. Read the actual call site in the file to confirm whether `.scope(` is present; do not grep — the call chain may span multiple lines.

In v3, the default scope changed from `"openid profile email"` to `"openid profile email offline_access"`. Apps that relied on the default and do **not** want a refresh token should add an explicit `.scope()` call:

```swift
// v2 — default scope: "openid profile email" (no refresh token)
Auth0.webAuth()
    .audience("https://api.example.com")
    .start { result in ... }

// v3 — default scope includes offline_access (refresh token returned)
// If you want to keep the v2 behaviour (no refresh token), add .scope() explicitly:
Auth0.webAuth()
    .audience("https://api.example.com")
    .scope("openid profile email")  // explicit — no offline_access
    .start { result in ... }

// If refresh tokens are welcome (recommended — enables silent renewal):
// No change needed; the new default is intentional.
```

Surface this as a **behavioural change** in the Step 9 summary regardless of which path is chosen — the Auth0 tenant must permit offline access for this app if refresh tokens are to be issued.

---

#### 6.15 — `CredentialsManager.credentials()` — default `minTTL` changed from 0 to 60 seconds

**Applies if:** Step 4 found any call to `credentialsManager.credentials(` without an explicit `minTTL:` parameter.

In v3, `CredentialsManager.credentials(withScope:minTTL:parameters:headers:callback:)` defaults `minTTL` to `60` instead of `0`. This means the credentials manager will now consider tokens expired — and trigger a silent refresh — 60 seconds before their actual expiry, rather than only when they are already expired.

This is a **silent behavioural change**: the app still compiles without changes, but token renewal now happens earlier than before.

```swift
// v2 — credentials() triggers renewal only when token is actually expired (minTTL default: 0)
credentialsManager.credentials { result in
    switch result {
    case .success(let credentials): use(credentials)
    case .failure(let error): handleError(error)
    }
}

// v3 — credentials() triggers renewal 60 seconds before expiry (minTTL default: 60)
// No code change needed if this behaviour is acceptable (recommended for most apps).
// To restore the v2 behaviour explicitly:
credentialsManager.credentials(minTTL: 0) { result in
    switch result {
    case .success(let credentials): use(credentials)
    case .failure(let error): handleError(error)
    }
}
```

For most apps the new default is preferable — renewing tokens slightly before expiry avoids races where an in-flight request uses an access token that expires mid-request. Only set `minTTL: 0` explicitly if the app has a specific reason to renew only at exact expiry.

Surface this as a **behavioural note** in the Step 9 summary.

---

### Step 7 — Update the Dependency & Build

```bash
# Attempt a build — expect errors for any remaining call sites
xcodebuild build \
  -scheme <SCHEME> \
  -destination "platform=iOS Simulator,name=${SIM}" \
  2>&1
```

For each error:

1. Read the error and locate the source line
2. Match it to one of the API changes in Step 6
3. Verify the fix matches the actual SDK signature fetched in Step 3
4. Apply the fix in keeping with the project's existing style
5. Rebuild

**Common error → cause mapping:**

| Xcode error | Likely cause |
|---|---|
| `has no member 'clearSession'` | §6.1 — rename to `logout` |
| `error enum element 'pkceNotAllowed' not found in type` or `'invalidInvitationURL' not found` | §6.2 — remove deleted `WebAuthError` cases from switch |
| `cannot convert return expression of type 'Request<...>'` in mock | §6.4 — update mock return type to `any TokenRequestable<T,E>` or `any Requestable<T,E>` |
| `does not conform to protocol 'Requestable'` (missing `@MainActor` on `start`) | §6.4 — add `@MainActor` to `start(_:)` callback in mock |
| `has no member 'user'` on CredentialsManager | §6.7 — change to `userProfile()` |
| `cannot find type 'UserInfo'` | §6.9 — rename to `UserProfile` |
| `has no member 'expiresIn'` | §6.10 — rename to `expiresAt` |
| `cannot convert value of type 'Bool'` on store/clear | §6.5/§6.6 — add do-catch or try? |
| `does not conform to protocol 'CredentialsStorage'` | §6.11 — update protocol methods + add deleteAllEntries |
| `call can throw, but is not marked with 'try'` | wrap in do-catch or add try? |
| `sending '...' risks causing data races` | only appears when the project uses Swift 6 language mode or `SWIFT_STRICT_CONCURRENCY=complete`; resolve within the existing actor model — not a migration error |

**Limit:** Up to **10 build-fix cycles**. If the build still fails after 10 attempts, stop and show the remaining errors to the user with context — do not guess.

---

### Step 8 — Run Tests & Verify

```bash
# Run the test suite if one exists (reuse $SIM from Step 1)
xcodebuild test \
  -scheme <SCHEME> \
  -destination "platform=iOS Simulator,name=${SIM}" \
  2>&1 | tail -30
```

Test failures caused by the same API changes (wrong type name, missing method) should be fixed using the same rules as Step 7. Test failures that require logic changes beyond API updates should be flagged for the user.

```bash
# Summarise the diff
git diff --stat
```

---

### Step 9 — Migration Summary

Present a concise summary covering:

**1. Changes applied** (grouped by API area; list files touched per area)

**2. Needs manual review**
- Every error-handling change — confirm the new error types are routed correctly
- Every `try?` used to discard errors where the project previously discarded a `Bool` — ask if explicit error handling is wanted
- The `offline_access` default scope change — confirm the tenant is configured to allow it, or confirm the explicit scope call is correct

**3. Backend / configuration follow-up** (only if triggered)
- **WebAuthError cases changed (§6.2):** List which removed cases were deleted from switch statements and which new cases were added. Note that `.authenticationFailed` and `.codeExchangeFailed` may benefit from user-facing copy changes.
- **`Request` → `Requestable` in mocks (§6.4):** List which test mock files were updated. Note any `TokenRequestable` builder methods that were stubbed with `return self` — confirm this is correct for the tests involved.
- **New error paths (§6.8):** List which CredentialsManager async methods the project calls and note the new errors that can now surface:
  - `revoke()` — `.noCredentials` (nothing to revoke), `.revokeFailed` (server revocation failed), `.clearFailed` (token revoked but Keychain delete failed)
  - `credentials()` / `renew()` / `apiCredentials()` / `ssoCredentials()` — `.noCredentials` (Keychain item not found), `.renewFailed` (refresh token renewal failed), `.storeFailed` (renewed credentials could not be saved)
  - Confirm the failure handling for each case navigates or surfaces errors correctly.
- **Management client removed (§6.12):** List the specific operations that were stubbed with `TODO`. Describe what the user must implement on a secure backend.
- **MFA methods removed (§6.13):** List which MFA flows need updating to `MFAClient`. Ask the user to re-test MFA end-to-end.
- **Default scope change (§6.14):** Note whether `.scope()` was added explicitly or the new `offline_access` default was accepted. Confirm the tenant is configured to allow offline access.
- **Default minTTL change (§6.15):** Note that `credentialsManager.credentials()` now renews tokens 60 seconds before expiry instead of at exact expiry. Confirm this is acceptable or that `minTTL: 0` was set explicitly.

**4. Optional improvements not applied** (list briefly; never auto-apply)
- New `clearAll()` method on `CredentialsManager` — clears all credentials in one call
- New `MFAClient` API — if the project uses MFA and the old methods were already removed
- DPoP (Demonstrating Proof of Possession) support — if the API requires sender-constrained tokens
- Passkey login/signup APIs (iOS 16.6+, macOS 13.5+)
- `ssoCredentials()` — if SSO credential exchange is needed

**5. Ask the user** if they'd like to commit the migration changes, explore any optional improvement, or step through specific files together.

**Security reminder:** Never include tokens, secrets, client credentials, or Keychain values in the summary output.

---

## Detailed References

- **[Migration Process](./references/process.md)** — Multi-version jumps, rollback, CocoaPods/Carthage edge cases, Swift version compatibility
- **[Security Checklist](./references/security.md)** — Invariants that must hold before and after migration

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| Applying a §6.x section when Step 4 didn't find that API in the project | Step 4 file-reading is the gate. Not found = skip the section entirely |
| Using grep alone to decide if an API is used | Grep misses multi-line call chains, calls with `domain:clientId:` params, and variable aliases. Read the actual files |
| Touching `CredentialsManager` when the project doesn't use it | Only migrate what the project actually calls |
| Removing `DispatchQueue.main` wrappers around non-Auth0 code | Only remove dispatch wrappers that are solely inside an Auth0 callback body |
| Silently deleting Management API call sites | Add `// TODO:` and surface in the summary — removing the call breaks functionality |
| Silently deleting old MFA call sites | Same as above — add `TODO` and note in the summary |
| Applying changes based on assumed knowledge, not the fetched SDK source | Every fix must trace to a signature in the files fetched in Step 3 |
| Pinning `from: "3.0.0"` when the developer chose a beta tag | Stable range specifiers won't resolve betas; use `exact: "<TAG>"` for pre-releases |
| Starting migration on a dirty working tree | Always verify `git status --porcelain` is empty first |
| Skipping straight to build without applying known changes first | Apply all known changes first, then build to catch remainders |
| Continuing past 10 failed build cycles | Stop and show the user the remaining errors |
| Skipping the migration summary | Always produce the full summary — the user needs it |

## Related Skills

- [auth0-swift](/auth0-swift) — New Auth0.swift integration from scratch
- [auth0-android](/auth0-android) — Android native authentication

---

## References

- [Auth0.swift GitHub](https://github.com/auth0/Auth0.swift)
- [Auth0.swift Releases](https://github.com/auth0/Auth0.swift/releases)
- [Auth0.swift API Documentation](https://auth0.github.io/Auth0.swift/documentation/auth0/)

> **Security:** Never echo tokens, client secrets, or credentials in build logs or terminal output. Never commit secrets to version control.
