# Migration Process — Edge Cases & Procedures

This skill migrates Auth0.swift v2 integrations to v3. Every code change is gated on reading the project's source files to confirm the affected API is actually used. If an API area is not found, the corresponding section is skipped entirely — no speculative changes, no added imports, no defensive code.

---

## Rollback Procedure

```bash
# Option 1 — restore the backup branch created in Step 1
git checkout auth0-v3-migration-backup
# Then delete the migration branch only if the user confirms
git branch -D <migration-branch>

# Option 2 — revert all uncommitted changes (confirm before running)
git checkout -- .

# Option 3 — stash for later
git stash push -m "auth0-v3-migration-wip"
```

Always confirm with the user before any destructive git operation.

---

## Fetching the SDK Source

The SDK source for the target tag is the single authoritative reference. Fetch it in Step 3 of the main workflow. Quick reference for core files:

```bash
# Use the tag the developer chose in Step 2.
# If no tag was specified, resolve the latest v3 release (stable or pre-release):
TAG=$(curl -s https://api.github.com/repos/auth0/Auth0.swift/releases | python3 -c "
import sys, json
releases = json.load(sys.stdin)
v3 = [r for r in releases if r['tag_name'].startswith('3') and not r['draft']]
print(v3[0]['tag_name'] if v3 else '')
")

curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/WebAuth.swift"
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/CredentialsManager.swift"
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/Authentication.swift"
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/Credentials.swift"
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/UserProfile.swift"
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/CredentialsStorage.swift"
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Auth0/MFAClient.swift"
```

If a file 404s, check the tree listing for the correct filename:
```bash
curl -s "https://api.github.com/repos/auth0/Auth0.swift/git/trees/${TAG}?recursive=1" \
  | python3 -c "
import sys, json
for item in json.load(sys.stdin).get('tree', []):
    if item['path'].startswith('Auth0/') and item['path'].endswith('.swift'):
        print(item['path'])
"
```

---

## Confirming a Signature Before Applying a Change

Before writing any replacement code, locate the target method in the fetched source and read its exact declaration. Step 3 fetches SDK files inline and prints them to stdout — search the output for the relevant declaration. Example patterns to look for:

```plaintext
# In the fetched WebAuth.swift output — confirm logout() is the v3 name
func logout(

# In the fetched CredentialsManager.swift output — confirm store() throws
func store(credentials:

# In the fetched CredentialsManager.swift output — confirm default minTTL value
minTTL
```

If the signature in the fetched source contradicts the examples in the skill's SKILL.md, **trust the fetched source** — it reflects the actual release you're targeting.

---

## Xcode-Managed SPM (no Package.swift at root)

When the project uses Xcode's built-in SPM:

1. The version constraint lives inside `project.pbxproj` — editing it directly is fragile.
2. Instruct the user to update via Xcode: *File → Packages → Update to Latest Package Versions*. If it doesn't resolve to v3, ask them to change the rule to *Up to Next Major from 3.0.0*.
3. After the user updates, verify resolution:
   ```bash
   grep -A3 "Auth0.swift" \
     *.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 2>/dev/null \
     || grep -A3 "Auth0.swift" **/Package.resolved 2>/dev/null
   ```

---

## Workspace with Multiple Targets

If the project has multiple targets (app + extensions + widgets):

```bash
# Find all targets importing Auth0
grep -rl "import Auth0" --include="*.swift" .
```

Apply the same changes to all targets simultaneously. Membership of each file in its target can be confirmed in Xcode or by checking `project.pbxproj`. Build each affected scheme:

```bash
xcodebuild -list   # shows available schemes
```

---

## CocoaPods Subspecs

Check whether the Podfile uses subspecs (e.g., `pod 'Auth0/WebAuth'`). Fetch the v3 podspec to confirm whether subspecs still exist:

```bash
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/\
$(curl -s https://api.github.com/repos/auth0/Auth0.swift/releases \
  | python3 -c "import sys,json;v=[r for r in json.load(sys.stdin) \
  if r['tag_name'].startswith('3') and not r['draft']]; print(v[0]['tag_name'])")/Auth0.podspec"
```

If subspecs were removed or merged in v3, simplify to `pod 'Auth0', '~> 3.0'`.

---

## Carthage Binary Frameworks

For Carthage projects migrating to a version that ships XCFrameworks:

1. Remove old `.framework` references from Xcode
2. Update and bootstrap:
   ```bash
   carthage update Auth0.swift --use-xcframeworks
   ```
3. Re-add the resulting `.xcframework` bundles to the target's *Frameworks, Libraries, and Embedded Content*

---

## Error-Handling Migration Rules

When an API changes from returning `Bool` to throwing:

1. **Map onto the project's existing strategy.** Look at how the project already handles errors (do-catch, Result, Combine `.catch`, etc.) and use the same pattern.
2. **Preserve custom logging / telemetry integrations.** If the project routes auth errors through a logger, analytics SDK, or crash reporter, feed the new `Error` type into the same sink.
3. **Prefer `do-catch` over `try?`** when the project has an error handler. Use `try?` only to exactly preserve intentional silent-discard behaviour.
4. **Never log sensitive data.** When adjusting error handling, ensure no token or credential value is printed, logged, or included in error messages.
5. **Flag for review.** Every error-handling change goes in the Step 9 summary — the user must verify the new error types are handled correctly.

---

## Management Client Removal — Backend Requirements

Auth0.swift v3 removed `Auth0.users(token:)` and the entire `Users` management client.

**What to do with call sites:**

1. Call sites are identified during the Step 4 file-reading audit — look for `Auth0.users(` or `.users(token:` in any file that imports Auth0.
2. **Do not delete them.** Add a `// TODO:` comment that preserves the intent and explains what the user must do.
3. Tell the user in the Step 9 summary: which operations were removed, that they must be moved to a secure backend, and that a Management API token must **never** be embedded in the client app.

Backend pattern to recommend:

```plaintext
App → HTTPS → Your Backend → Auth0 Management API (M2M token)
```

---

## MFA Methods Removed — MFAClient Migration

v3 removed:
- `authentication().login(withOTP:mfaToken:)`
- `authentication().login(withOOBCode:mfaToken:bindingCode:)`
- `authentication().login(withRecoveryCode:mfaToken:)`
- `authentication().multifactorChallenge(mfaToken:types:authenticatorId:)`

**What to do:**

1. Call sites are identified during the Step 4 file-reading audit — look for `login(withOTP:`, `login(withOOBCode:`, `login(withRecoveryCode:`, or `multifactorChallenge(` in any file that imports Auth0.
2. `MFAClient.swift` is fetched in Step 3 (under `Auth0/MFA/`) — use it to confirm the exact method signatures before applying changes.
3. Migrate call sites to the `MFAClient` API based on the fetched source (see §6.13 in SKILL.md for full before/after examples).
4. If the migration cannot be completed confidently, add `// TODO:` comments and list the affected flows in the Step 9 summary.
5. Tell the user to **re-test all MFA flows end-to-end** — OTP, OOB, and recovery code enrollment and challenge — against their tenant configuration.

---

## `WebAuth` as a Value Type in v3

In v3, the concrete `Auth0WebAuth` implementation changed from a class to a struct. This is transparent when using method chaining, but breaks imperative builder patterns:

```swift
// Breaks in v3 — var is a struct copy; mutating it then not capturing the result does nothing
var webAuth = Auth0.webAuth()
webAuth.scope("openid")  // ❌ discarded copy

// Fine in both v2 and v3 — capture the returned copy
var webAuth = Auth0.webAuth()
webAuth = webAuth.scope("openid")  // ✅

// Best practice in both versions — chain directly
Auth0.webAuth()
    .scope("openid profile email offline_access")
    .audience("https://api.example.com")
    .start { result in ... }
```

Grep for patterns where a `webAuth` variable is mutated without capturing the return:
```bash
grep -rn "webAuth\." --include="*.swift" . \
  | grep -v "= webAuth\.\|= Auth0\.webAuth()\|try await\|\.start(\|\.logout("
```

---

## Swift Version Compatibility

v3 may require a newer Swift toolchain. Verify:

```bash
# Project's current Swift version
grep "SWIFT_VERSION" *.xcodeproj/project.pbxproj | head -5

# SDK's minimum toolchain requirement
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.swift/${TAG}/Package.swift" \
  | grep "swift-tools-version"
```

If a Swift version bump is needed, inform the user — it may require an Xcode update. Distinguish between Auth0 migration errors and Swift version errors in the build output.

---

## JWTDecode Dependency

Auth0.swift depends on JWTDecode.swift. A major version bump may upgrade the JWTDecode dependency:

```bash
# Check for direct JWTDecode imports in the project
grep -rn "import JWTDecode" --include="*.swift" .
```

If the project directly imports JWTDecode, check the JWTDecode changelog for breaking changes. For CocoaPods, update both simultaneously:

```bash
pod update Auth0 JWTDecode
```

---

## Handling Deprecated APIs

In v3, some APIs may be deprecated but not yet removed. Leave them alone during migration:

- Do not replace deprecated APIs unless they cause build errors
- Note them in the Step 9 migration summary as optional follow-up
- Deprecated → removed happens in the next major version; they're safe for now

Do not confuse deprecated with removed. The old MFA methods (`Authentication.login(withOTP:)` etc.) were **fully removed** in v3 — they are not present at all and will cause compile errors, not warnings. Treat them as breaking changes per §6.13, not as deprecated APIs.
