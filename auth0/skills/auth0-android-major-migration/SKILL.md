---
name: auth0-android-major-migration
description: >
  Use when upgrading an Android app's Auth0 SDK (com.auth0.android:auth0) to the next major version. Detects the current version, checks prerequisites, and applies only the breaking changes that affect the project's real call sites. Use even if the user just says "update my Auth0 Android SDK" or "migrate to Auth0 Android v4".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  argument-hint: '[target-version]   # e.g. 4.0.0 or 4.0.0-beta.1; omit to auto-resolve the latest v4 release'
  openclaw:
    emoji: "\U0001F504"
    homepage: https://github.com/auth0/agent-skills
    requires:
      bins:
        - gh
---

# Auth0.Android v4 Migration

Migrates an existing Auth0.Android (`com.auth0.android:auth0`) v3 integration to v4. Every code change is gated on a search that confirms the project actually calls the affected API — if the project never uses `SecureCredentialsManager`, no `SecureCredentialsManager` code is touched. Changes follow the project's existing architecture (Kotlin or Java, callback or coroutine) and Android conventions.

## Target version is argument-based

This skill accepts an optional target version argument:

- **`/auth0-android-major-migration 4.0.0`** — migrate to the exact tag `4.0.0` (validated before use).
- **`/auth0-android-major-migration`** (no argument) — auto-resolve the **latest release within the next major (v4.x)**, including pre-releases.

`$ARGUMENTS`, when present, is the requested target tag. Step 2 validates it and resolves the final `<TARGET_TAG>` used for the rest of the migration.

## When NOT to Use

- **New Auth0 integration** (no existing Auth0.Android SDK): Use [auth0-android](/auth0-android)
- **Minor/patch update** (e.g., 3.18 → 3.19): Bump the `com.auth0.android:auth0` version in Gradle — no migration needed
- **iOS / macOS apps**: Use [auth0-swift-major-migration](/auth0-swift-major-migration)
- **React Native / Expo**: Use [auth0-react-native](/auth0-react-native) or [auth0-expo](/auth0-expo)
- **Flutter**: Use the native Flutter Auth0 SDK

## Prerequisites

- Existing Auth0.Android v3 integration (`com.auth0.android:auth0:3.x`)
- Android SDK / Gradle toolchain installed; project builds cleanly on the current version
- Project under git version control with a clean working tree

---

## Migration Workflow

> **Agent instruction:** Execute every step in order. The goal is a green build with the smallest correct changeset. Each code-change step is gated by the Step 5 file-reading audit — if the API was not found in the project's source files, skip the entire step for that area. Never add code the project doesn't already call. v4 also raises platform requirements (Step 3) that can **block** the migration until satisfied — handle those before touching any Auth0 API call site.

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
git checkout -b auth0-v4-migration-backup
git checkout -
```

```bash
# 1c. Confirm the project builds on the current version before touching anything
./gradlew assembleDebug 2>&1 | tail -15
```

If the build fails, stop. Ask the user to fix the existing issues first — do not migrate a project that does not build.

---

### Step 2 — Detect Current & Resolve Target Version

**Detect the current Auth0.Android version** (check each location that applies):

```bash
# Inline dependency in a module build file (Groovy or Kotlin DSL)
grep -rEn "com\.auth0\.android:auth0:[0-9]" --include=build.gradle --include=build.gradle.kts .

# Gradle version catalog
grep -rEn "auth0" --include=libs.versions.toml .

# Resolved lockfile (most reliable if present)
grep -rEn "com\.auth0\.android:auth0:[0-9]" --include=gradle.lockfile .
```

**Resolve the target version.** There are two paths:

**Path A — the user passed a target version argument (`$ARGUMENTS`):**

Validate it against the published releases before using it. It must pass **all three** checks:

```bash
# List all published Auth0.Android release tags
gh api repos/auth0/Auth0.Android/releases --paginate \
  --jq '.[] | select(.draft==false) | .tag_name'
```

1. **Exists** — the requested tag appears in the published release list above.
2. **Next major** — the tag is within the **v4** major line (`tag_name` starts with `4`). A `3.x` or lower tag is *not* the next major; reject it.
3. **Not a downgrade** — the tag is newer than the version detected in the project.

> **On any check failing, STOP and ask the user.** Do not silently fall back. For example:
> - *"`4.9.9` isn't a published Auth0.Android release. Published v4 releases are: `4.0.0-beta.1`, … . Please pass a valid v4 tag, or omit the argument to auto-resolve the latest v4 release."*
> - *"`3.19.0` is a v3 release, not the next major. This skill migrates to v4. Pass a v4 tag (e.g. `4.0.0`) or omit the argument."*
> - *"`4.0.0-beta.0` is older than the `4.0.0-beta.1` already in your project — that's a downgrade. Pass a newer v4 tag or omit the argument."*

**Path B — no argument: auto-resolve the latest v4 release (including pre-releases):**

```bash
# Newest v4.x release tag (stable or pre-release), most recent first
gh api repos/auth0/Auth0.Android/releases --paginate \
  --jq '[.[] | select(.draft==false) | select(.tag_name|startswith("4"))] | .[0].tag_name'
```

Record the result as `<TARGET_TAG>` and use it in every subsequent step.

> **If `<TARGET_TAG>` is a pre-release** (contains `-beta`, `-rc`, etc.), tell the user before continuing:
> *"v4 is not yet generally available — the latest v4 release is `<TARGET_TAG>` (a pre-release). I'll migrate to that. You can pin a different tag by passing it as an argument."*
>
> **If no v4 release exists yet** (the resolver returns empty), stop and tell the user there is no published v4 release to migrate to.

---

### Step 3 — Prerequisite Gate (Requirements Changes)

v4 raises the build toolchain and platform floor. Check each requirement **before** migrating any API. If a requirement is unmet, prompt the user and apply the build-file change (or block until they confirm) — a project that doesn't meet these will not build against v4 regardless of API changes.

> Confirm the exact required versions for `<TARGET_TAG>` from the SDK's own `build.gradle` / `gradle-wrapper.properties` fetched in Step 4 if they differ from the values below (these reflect the v4 baseline).

| Requirement | v3 | v4 | Where to check / change |
|---|---|---|---|
| **minSdk** | 21 | **26** (Android 8.0) | `android { defaultConfig { minSdk } }` |
| **Java** | 8+ | **17** | `compileOptions { sourceCompatibility/targetCompatibility }`, `kotlinOptions { jvmTarget }` |
| **Gradle** | — | **8.11.1+** | `gradle/wrapper/gradle-wrapper.properties` (`distributionUrl`) |
| **AGP** | — | **8.10.1+** | root `build.gradle` `com.android.tools.build:gradle` classpath / `plugins` block |
| **Kotlin** | — | **2.0.21** | `ext.kotlin_version` / version catalog (only if the project uses Kotlin) |

```bash
# Inspect current values
grep -rEn "minSdk(Version)?\s*[ =]" --include=build.gradle --include=build.gradle.kts .
grep -rEn "sourceCompatibility|targetCompatibility|jvmTarget" --include=build.gradle --include=build.gradle.kts .
grep -En "distributionUrl" gradle/wrapper/gradle-wrapper.properties
grep -rEn "com\.android\.tools\.build:gradle|kotlin_version|kotlin(\"|-)" --include=build.gradle --include=build.gradle.kts --include=libs.versions.toml .
```

**`minSdk` below 26 is a hard block.** If the project targets API 25 or lower, tell the user this raises the minimum supported Android version (devices on Android 7.1 and below will no longer be supported) and ask them to confirm before bumping `minSdk` to 26 — or to stay on v3.

Apply the required bumps (example shapes — match the project's DSL):

```groovy
android {
    defaultConfig { minSdk 26 }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = '17' }
}
```

See [references/process.md](references/process.md) for Kotlin DSL, version-catalog, and Gradle/AGP wrapper edge cases.

---

### Step 4 — Fetch & Read the v4 SDK Source

Fetch the actual Kotlin source for `<TARGET_TAG>`. The signatures here are the authoritative reference for every change made in Step 7. **Do not migrate from memory or from the guide alone — confirm each signature in the fetched source.**

```bash
TAG=<TARGET_TAG>   # the version resolved in Step 2, e.g. 4.0.0-beta.1
BASE="https://raw.githubusercontent.com/auth0/Auth0.Android/${TAG}/auth0/src/main/java/com/auth0/android"

# List all public Kotlin files in the SDK (confirm paths for this tag)
gh api "repos/auth0/Auth0.Android/git/trees/${TAG}?recursive=1" \
  --jq '.tree[].path | select(startswith("auth0/src/main/") and endswith(".kt"))'

# Fetch the files that back the breaking changes
for FILE in \
  provider/WebAuthProvider.kt \
  authentication/AuthenticationAPIClient.kt \
  authentication/mfa/MfaApiClient.kt \
  authentication/storage/SecureCredentialsManager.kt \
  authentication/storage/CredentialsManager.kt \
  authentication/storage/BaseCredentialsManager.kt \
  authentication/storage/Storage.kt \
  dpop/DPoPException.kt \
  result/SSOCredentials.kt \
  request/DefaultClient.kt ; do
    CONTENT=$(curl -sf "${BASE}/${FILE}")
    [ -n "$CONTENT" ] && echo "=== ${FILE} ===" && echo "$CONTENT"
done
```

> **If a release tag has no source yet** (e.g. during the v4 development phase, before the first tag carries the full tree), fall back to the `v4_development` branch for signature confirmation: replace `${TAG}` with `v4_development` in the URLs above. Always prefer the chosen tag when it has source.

Read the fetched source and note, for each file:
- Public method signatures that changed (parameters, return type, `@Throws`)
- Constructors that were removed
- Types/classes that were removed or renamed
- Default parameter values that changed (e.g. `minTtl`)

This is the ground truth. Every change in Step 7 must match a real signature in these files.

---

### Step 5 — Audit Which Auth0 APIs the Project Uses

**Find all source files that import the Auth0 SDK — these are the scope of the migration:**

```bash
grep -rlE "import com\.auth0\.android" --include="*.kt" --include="*.java" .
```

**Read every file from that list.** Do not grep for individual API patterns and stop there — read the full source so you can see exactly how `Auth0`, `WebAuthProvider`, `AuthenticationAPIClient`, `SecureCredentialsManager`/`CredentialsManager`, and any Auth0 types are used, including multi-line builder chains and any custom `Storage` conformances.

For each file, identify:

| What to look for | Section |
|---|---|
| `PasskeyAuthProvider` usage | §7.1 — class removed |
| `UsersAPIClient`, `ManagementException`, `ManagementCallback` | §7.2 — Management API removed |
| `loginWithOTP(`, `loginWithOOB(`, `loginWithRecoveryCode(`, `multifactorChallenge(` on `AuthenticationAPIClient` | §7.3 — deprecated MFA methods removed |
| `WebAuthProvider.useDPoP(` called on the object *before* `.login(` | §7.4 — `useDPoP` moved to the login builder |
| `DPoPException.UNSUPPORTED_ERROR` | §7.5 — constant removed |
| `.expiresIn` accessed on an `SSOCredentials` value | §7.6 — renamed to `expiresAt` (now a `Date`) |
| `SecureCredentialsManager(` with an `Auth0` instance as the first argument | §7.7 — `Auth0`-based constructors removed |
| `getCredentials(` / `awaitCredentials(` without an explicit `minTtl`, or `hasValidCredentials()` | §9.1 — default `minTtl` 0 → 60s (behavioral) |
| `clearCredentials(` | §9.3 — now clears **all** storage |
| A class implementing the `Storage` interface | §9.4 — new `removeAll()` (default impl provided) |

Build a checklist: **"This project uses: [list]"** and **"This project does NOT use: [list]"**. Only work through the §7.x / §9.x sections that appear in the "uses" list. Skip the rest entirely.

---

### Step 6 — Update the SDK Dependency

Apply the matching declaration style. Use `<TARGET_TAG>` from Step 2.

**Inline — Groovy DSL (`build.gradle`):**

```groovy
implementation 'com.auth0.android:auth0:<TARGET_TAG>'
```

**Inline — Kotlin DSL (`build.gradle.kts`):**

```kotlin
implementation("com.auth0.android:auth0:<TARGET_TAG>")
```

**Version catalog (`gradle/libs.versions.toml`):**

```toml
[versions]
auth0 = "<TARGET_TAG>"
```

> **Pre-release tags** (e.g. `4.0.0-beta.1`) must be pinned **exactly** — do not use a dynamic range like `4.+` or `[4.0,5.0)`, which Gradle may resolve to a different artifact. For stable v4 releases an exact version is still recommended for reproducibility.

Do **not** build yet — apply all known code changes first (Step 7), then build (Step 8) to surface any remainders.

---

### Step 7 — Apply Breaking Changes

> **Agent instruction:** Work through only the §7.x sections that matched during the Step 5 audit. Skip every section whose API the project does not use — do not touch those files. Apply each change exactly as shown, confirmed against the source fetched in Step 4. Do not rename variables, reformat, or modernise code that isn't being migrated. Match the project's existing style: callback → callback, coroutine `await` → coroutine `await`, Kotlin → Kotlin, Java → Java.

---

#### 7.1 — `PasskeyAuthProvider` removed

**Applies if:** Step 5 found `PasskeyAuthProvider` in the project's source files.

The `com.auth0.android.provider.PasskeyAuthProvider` class was removed. Passkey operations now live on `AuthenticationAPIClient`: `passkeyChallenge()`, `signupWithPasskey()`, and `signinWithPasskey()`. Confirm the exact signatures in the `AuthenticationAPIClient.kt` fetched in Step 4, then migrate each call site to the corresponding client method. If a passkey flow cannot be migrated confidently from the source, add a `// TODO:` and list it in the Step 10 summary rather than guessing.

---

#### 7.2 — Management API removed (`UsersAPIClient`)

**Applies if:** Step 5 found `UsersAPIClient`, `ManagementException`, or `ManagementCallback` in the project's source files.

The entire Management API client was removed from the SDK in v4. Calling the Management API directly from a mobile app was never recommended — it requires a privileged token on the device. **Do not silently delete the call sites.** Add a `// TODO:` that preserves the intent and surface this in the Step 10 summary as required backend work.

```kotlin
// v3 — direct Management API call from the app (e.g. updating user_metadata)
val users = UsersAPIClient(account, accessToken)
users.updateMetadata(userId, metadata)
    .start(object : Callback<UserProfile, ManagementException> { /* ... */ })

// v4 — Management client removed; preserve intent, move to a backend
// TODO: Auth0.Android v4 removed the Management API client (UsersAPIClient).
// Expose an endpoint on your own backend (e.g. PATCH /me/metadata) that performs
// this operation. Call it from the app with the user's access token as a Bearer
// token. On the backend, obtain a machine-to-machine token via Client Credentials
// and call the Management API with the minimum required scopes.
// NEVER embed a Management API token in the app.
// See: https://auth0.com/docs/manage-users/user-accounts/manage-user-metadata
```

This **requires backend work** — record it in the Step 10 summary.

---

#### 7.3 — Deprecated MFA methods removed from `AuthenticationAPIClient` → `MfaApiClient`

**Applies if:** Step 5 found `loginWithOTP(`, `loginWithOOB(`, `loginWithRecoveryCode(`, or `multifactorChallenge(` called on an `AuthenticationAPIClient` in the project's source files.

These four methods were deprecated in v3 and removed in v4. Obtain an `MfaApiClient` via `AuthenticationAPIClient.mfaClient(mfaToken)` and use its APIs. Confirm the exact `MfaApiClient` method signatures in the `MfaApiClient.kt` fetched in Step 4 before applying changes.

```kotlin
// v3 — removed methods on AuthenticationAPIClient
authentication
    .loginWithOTP(mfaToken, otp)
    .start(object : Callback<Credentials, AuthenticationException> { /* ... */ })

// v4 — obtain an MfaApiClient and use its verify API (confirm signature in MfaApiClient.kt)
val mfaClient = authentication.mfaClient(mfaToken)
// e.g. mfaClient.verifyWithOTP(otp) — use the exact method/parameters from the fetched source
```

The `mfaToken` still comes from the same place — an `AuthenticationException` where the challenge is required. List every migrated MFA flow in the Step 10 summary and ask the user to **re-test each MFA flow end-to-end** against their tenant. See [references/process.md](references/process.md#mfa-migration) for the full method map.

---

#### 7.4 — `WebAuthProvider.useDPoP(context)` moved to the login builder

**Applies if:** Step 5 found `WebAuthProvider.useDPoP(` called on the `WebAuthProvider` object **before** `.login(`. Read the actual call chain — it may span multiple lines.

In v4, `useDPoP(context)` is configured per-request on the login builder rather than globally on the `WebAuthProvider` object. Move the `.useDPoP(context)` call so it chains **after** `.login(account)`.

```kotlin
// v3 — global configuration (no longer compiles)
WebAuthProvider
    .useDPoP(context)
    .login(account)
    .start(context, callback)

// v4 — builder-based, per-request
WebAuthProvider
    .login(account)
    .useDPoP(context)
    .start(context, callback)
```

---

#### 7.5 — `DPoPException.UNSUPPORTED_ERROR` removed

**Applies if:** Step 5 found `DPoPException.UNSUPPORTED_ERROR` in the project's source files.

With the minimum SDK raised to API 26, DPoP is supported on every API level v4 targets, so this constant was removed. Remove any reference to it — for example, a `when`/`if` branch or comparison that checked for `UNSUPPORTED_ERROR`. No replacement is needed; the unsupported-version case can no longer occur.

```kotlin
// v3 — guarding against the unsupported case
if (error == DPoPException.UNSUPPORTED_ERROR) {   // ❌ no longer exists in v4
    showDeviceUnsupported()
} else {
    handle(error)
}

// v4 — the guard is no longer applicable; handle the remaining cases
handle(error)
```

---

#### 7.6 — `SSOCredentials.expiresIn` → `expiresAt` (`Int` → `Date`)

**Applies if:** Step 5 found `.expiresIn` accessed on an `SSOCredentials` value in the project's source files.

`SSOCredentials.expiresIn` (raw seconds, `Int`) was renamed to `expiresAt` and is now an absolute `Date` (computed during deserialization, consistent with `Credentials.expiresAt`). Rename the property **and** update any arithmetic that assumed a duration in seconds.

> The JSON wire format is unchanged — the field is still `@field:SerializedName("expires_in")` in the SDK. Only the Kotlin property name and type changed (`expiresIn: Int` → `expiresAt: Date`); don't expect a renamed `expires_at` key if you grep the raw JSON.

```kotlin
// v3 — seconds until expiry (Int)
val secondsUntilExpiry: Int = ssoCredentials.expiresIn

// v4 — absolute expiration Date
val expirationDate: Date = ssoCredentials.expiresAt
// If you previously did `now + expiresIn` to get an absolute time, use expiresAt directly.
```

---

#### 7.7 — `SecureCredentialsManager` `Auth0`-based constructors removed

**Applies if:** Step 5 found `SecureCredentialsManager(` constructed with an `Auth0` instance as the first argument in the project's source files.

The two constructors that accepted an `Auth0` instance were removed. Both remaining constructors take an `AuthenticationAPIClient` first. Build the client from the `Auth0` account, then pass the **same** client into `SecureCredentialsManager`.

```kotlin
// v3 — Auth0-based constructors (removed in v4)
val manager = SecureCredentialsManager(auth0, context, storage)
val manager = SecureCredentialsManager(auth0, context, storage, fragmentActivity, localAuthenticationOptions)

// v4 — build an AuthenticationAPIClient first, pass it in
val apiClient = AuthenticationAPIClient(auth0)
val manager = SecureCredentialsManager(apiClient, context, storage)

// v4 — biometric variant
val apiClient = AuthenticationAPIClient(auth0)
val manager = SecureCredentialsManager(
    apiClient,
    context,
    storage,
    fragmentActivity,
    localAuthenticationOptions
)
```

```java
// Java — same change; there is no Java-specific overload
AuthenticationAPIClient apiClient = new AuthenticationAPIClient(auth0);
SecureCredentialsManager manager = new SecureCredentialsManager(apiClient, context, storage);
```

> If the project enables DPoP, configure it on the client before passing it in: `AuthenticationAPIClient(auth0).useDPoP(context)`. Confirm the constructor signatures in the `SecureCredentialsManager.kt` fetched in Step 4.

---

### Step 8 — Build Until Green

```bash
./gradlew assembleDebug 2>&1 | tail -40
```

For each error: read it, locate the source line, match it to a Step 7 section, verify the fix against the signature fetched in Step 4, apply it in the project's existing style, then rebuild.

**Common error → cause mapping:**

| Build error | Likely cause |
|---|---|
| `unresolved reference: PasskeyAuthProvider` | §7.1 — class removed; use `AuthenticationAPIClient` passkey APIs |
| `unresolved reference: UsersAPIClient` / `ManagementException` / `ManagementCallback` | §7.2 — Management API removed; add `// TODO:` + backend follow-up |
| `unresolved reference: loginWithOTP` / `loginWithOOB` / `loginWithRecoveryCode` / `multifactorChallenge` | §7.3 — use `mfaClient(mfaToken)` / `MfaApiClient` |
| `unresolved reference: useDPoP` on `WebAuthProvider` | §7.4 — move `.useDPoP(context)` after `.login(account)` |
| `unresolved reference: UNSUPPORTED_ERROR` | §7.5 — remove the reference |
| `unresolved reference: expiresIn` on `SSOCredentials`, or `Int`/`Date` type mismatch | §7.6 — rename to `expiresAt` (now a `Date`) |
| `none of the following functions can be called` / `too many arguments` on `SecureCredentialsManager(` | §7.7 — build `AuthenticationAPIClient(auth0)` first, pass it in |
| `class … must override removeAll` (custom `Storage`) | §9.4 — the interface has a default impl; override only if needed |

**Limit:** Up to **10 build-fix cycles**. If the build still fails after 10 attempts, stop and show the remaining errors with context — do not guess.

---

### Step 9 — Behavior & Default-Value Changes (Review, Usually No Code Change)

These changes compile without edits but alter runtime behavior. Surface each in the Step 10 summary. Only change code if the project depends on the old behavior.

#### 9.1 — Credentials Manager default `minTtl` 0 → 60s

**Applies if:** the project calls `getCredentials(...)` / `awaitCredentials(...)` without an explicit `minTtl`, or calls `hasValidCredentials()`.

v4 renews credentials that expire within 60 seconds instead of only when already expired. This is the recommended behavior (avoids handing out tokens that expire mid-request). To restore v3 behavior explicitly, pass `minTtl = 0`:

```kotlin
// v4 — restore v3 behavior explicitly if required
credentialsManager.getCredentials(scope = null, minTtl = 0, callback = callback)
```

#### 9.2 — `CredentialsManager` now uses the global executor

Runtime-only. Renewals across managers backed by the same `Auth0` object are now serialized, eliminating duplicate refresh-token exchanges. **No code change required.**

#### 9.3 — `clearCredentials()` now clears all storage

**Applies if:** the project calls `clearCredentials()`.

v4 calls `Storage.removeAll()`, clearing **all** values in the storage — including API credentials stored for specific audiences. If the project needs to preserve other data in the same `Storage`, recommend a separate `Storage` instance for API credentials, or consider the new `clearAll()` (Step 10 optional improvements).

#### 9.4 — `Storage` interface gains `removeAll()`

**Applies if:** the project has a class implementing the `Storage` interface.

`removeAll()` ships with a default empty implementation, so existing custom `Storage` implementations still compile. **Override `removeAll()`** to actually clear storage if that custom storage is used with `clearCredentials()` — otherwise `clearCredentials()` becomes a no-op for it.

---

### Step 10 — Migration Summary

Present a concise summary covering:

**1. Prerequisites changed** — `minSdk` / Java / Gradle / AGP / Kotlin bumps applied, and that `minSdk 26` drops support for Android 7.1 and below.

**2. Changes applied** — grouped by API area (§7.x), with the files touched per area.

**3. Needs manual review**
- §7.1 Passkey / §7.3 MFA flows migrated to the new clients — **re-test end-to-end** against the tenant.
- Any `// TODO:` left for §7.2 (Management API) — backend work required.

**4. Behavioral changes (no code change, verify acceptable)**
- §9.1 `minTtl` now defaults to 60s — tokens renew 60s before expiry.
- §9.3 `clearCredentials()` now clears **all** storage (including API credentials).
- §9.2 `CredentialsManager` now uses the global executor (renewals serialized).

**5. Backend / configuration follow-up**
- §7.2 Management API removal — list the operations stubbed with `TODO` and what must move to a secure backend (M2M token, never on-device).

**6. Optional improvements not applied** (list briefly; never auto-apply)
- `clearAll()` — full credential **and** cryptographic key cleanup on logout/account removal.
- `WebAuthProvider.registerCallbacks()` in `onCreate()` — prevents lost callbacks / memory leaks on configuration change or process death during authentication.
- `DefaultClient.Builder` — the constructor is deprecated (not removed); the builder adds write/call timeouts, custom interceptors, and loggers.
- Gson 2.8.9 → 2.11.0 (transitive) — stricter `TypeToken` / type coercion; see [references/process.md](references/process.md#gson-transitive-dependency).

**7. Ask the user** whether to commit the migration, explore an optional improvement, or step through specific files together.

> **Security reminder:** Never include tokens, secrets, client credentials, or stored credential values in the summary or any build log.

---

## Detailed References

- **[Migration Process](references/process.md)** — version-argument validation, prerequisite/toolchain handling, build-system edge cases (Groovy DSL, Kotlin DSL, version catalogs), MFA method map, Management-API backend pattern, Gson transitive notes, rollback, and "deprecated ≠ removed" guidance.
- **[Security Checklist](references/security.md)** — invariants that must hold before and after migration.

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| Applying a §7.x section when Step 5 didn't find that API in the project | Step 5 file-reading is the gate. Not found = skip the section entirely |
| Using grep alone to decide if an API is used | Grep misses multi-line builder chains (e.g. `useDPoP` before `login`) and aliased variables. Read the actual files |
| Migrating API call sites before meeting the Step 3 prerequisites | A project below `minSdk 26` / Java 17 won't build against v4. Handle prerequisites first |
| Accepting a target-version argument without validating it | Validate exists / next-major / not-a-downgrade, then **stop and ask** on failure |
| Using a dynamic range (`4.+`) for a pre-release tag | Pin pre-releases exactly — ranges may resolve to a different artifact |
| Silently deleting Management API or removed-MFA call sites | Add `// TODO:` and surface in the summary — deletion breaks functionality |
| Applying changes from the migration guide without confirming the SDK source | Every fix must trace to a signature in the files fetched in Step 4 |
| Treating `DefaultClient(...)` constructor as a breaking change | It is **deprecated, not removed** — leave it; note the Builder as optional |
| Starting on a dirty working tree | Always verify `git status --porcelain` is empty first |
| Continuing past 10 failed build cycles | Stop and show the user the remaining errors |
| Skipping the migration summary | Always produce the full summary — the user needs it |

## Related Skills

- [auth0-android](/auth0-android) — New Auth0.Android integration from scratch
- [auth0-swift-major-migration](/auth0-swift-major-migration) — Auth0.swift major version upgrades
- [auth0-mfa](/auth0-mfa) — Configure multi-factor authentication

---

## References

- [Auth0.Android GitHub](https://github.com/auth0/Auth0.Android)
- [Auth0.Android Releases](https://github.com/auth0/Auth0.Android/releases)
- [V4 Migration Guide](https://github.com/auth0/Auth0.Android/blob/v4_development/V4_MIGRATION_GUIDE.md)
- [Auth0 Android SDK Documentation](https://auth0.com/docs/libraries/auth0-android)

> **Security:** Never echo tokens, client secrets, or credentials in build logs or terminal output. Never commit secrets to version control.
