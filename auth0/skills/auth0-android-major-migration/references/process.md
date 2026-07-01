# Migration Process — Edge Cases & Procedures

This skill migrates Auth0.Android (`com.auth0.android:auth0`) v3 integrations to v4. Every code change is gated on reading the project's source files to confirm the affected API is actually used. If an API area is not found, the corresponding section is skipped entirely — no speculative changes, no added imports, no defensive code.

---

## Target-Version Argument Validation

The skill accepts an optional target version as an argument (`$ARGUMENTS`). Resolution happens in Step 2 of the main workflow.

**When an argument is provided, it must pass all three checks before use:**

1. **Exists** — the tag appears in the published release list:

   ```bash
   gh api repos/auth0/Auth0.Android/releases --paginate \
     --jq '.[] | select(.draft==false) | .tag_name'
   ```

2. **Next major (v4)** — `tag_name` starts with `4`. A `3.x` or lower tag is the current/previous major, not the next one.
3. **Not a downgrade** — the tag is newer than the version detected in the project files.

**On any failure, STOP and ask the user** to supply a valid v4 tag or omit the argument. Never silently fall back to auto-resolution when the user explicitly asked for a version — they may have a specific reason, and a silent substitution hides the mistake.

**When no argument is provided**, auto-resolve the newest v4.x release including pre-releases:

```bash
gh api repos/auth0/Auth0.Android/releases --paginate \
  --jq '[.[] | select(.draft==false) | select(.tag_name|startswith("4"))] | .[0].tag_name'
```

The releases endpoint returns newest-first, so `.[0]` after filtering is the latest v4 tag. If it is a pre-release (contains `-beta`, `-rc`, etc.), tell the user before proceeding. If the filter returns empty, there is no published v4 release yet — stop.

> **Rolling boundary:** this skill is intentionally version-number-free in its name. Today the "next major" is v4; when v5 ships, the same `startswith` resolver and the same validation logic target v5 with no change to the skill's structure. Only the breaking-change sections in `SKILL.md` are version-specific.

---

## Prerequisite Handling (Toolchain & Platform)

v4 raises the build floor. These are checked in Step 3 and can **block** the migration until satisfied. Confirm the exact required versions for the chosen tag from the SDK's own build files if they differ from the v4 baseline below.

| Requirement | v4 baseline | File |
|---|---|---|
| `minSdk` | 26 | module `build.gradle(.kts)` |
| Java | 17 | `compileOptions`, `kotlinOptions.jvmTarget` |
| Gradle | 8.11.1+ | `gradle/wrapper/gradle-wrapper.properties` |
| AGP | 8.10.1+ | root `build.gradle(.kts)` |
| Kotlin | 2.0.21 | `ext.kotlin_version` / version catalog (Kotlin projects only) |

**Confirm the SDK's own requirements from source** (don't assume — read them for the tag):

```bash
TAG=<TARGET_TAG>
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.Android/${TAG}/auth0/build.gradle" | grep -iEn "minSdk|sourceCompatibility|targetCompatibility|jvmTarget|kotlin"
curl -sf "https://raw.githubusercontent.com/auth0/Auth0.Android/${TAG}/gradle/wrapper/gradle-wrapper.properties" | grep -E "distributionUrl"
```

### Groovy DSL (`build.gradle`)

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

### Kotlin DSL (`build.gradle.kts`)

```kotlin
android {
    defaultConfig { minSdk = 26 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
```

> On newer AGP/Kotlin, `jvmTarget` may live under `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }` instead of `kotlinOptions`. Match the project's existing configuration block rather than introducing a new one.

### Gradle wrapper

```properties
# gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-all.zip
```

### AGP

```groovy
// root build.gradle (buildscript classpath form)
classpath 'com.android.tools.build:gradle:8.10.1'
```

```kotlin
// settings/root plugins block form
id("com.android.application") version "8.10.1"
```

**`minSdk` below 26 is a hard block.** Raising it drops support for Android 7.1 (API 25) and below. Confirm with the user before bumping, or advise staying on v3 if they must support older devices.

---

## Dependency Declaration Forms

| Style | File | Example |
|---|---|---|
| Inline Groovy | `build.gradle` | `implementation 'com.auth0.android:auth0:<TAG>'` |
| Inline Kotlin DSL | `build.gradle.kts` | `implementation("com.auth0.android:auth0:<TAG>")` |
| Version catalog | `gradle/libs.versions.toml` | `auth0 = "<TAG>"` under `[versions]` |

**Pre-release tags must be pinned exactly.** Do not use dynamic ranges (`4.+`, `[4.0,5.0)`, `latest.release`) for a `-beta`/`-rc` tag — Gradle may resolve them to a different artifact. Exact pinning is recommended for stable releases too, for reproducible builds.

After editing, refresh dependencies:

```bash
./gradlew --refresh-dependencies help 2>&1 | tail -5
```

---

## MFA Migration

v4 removed these deprecated methods from `AuthenticationAPIClient`:

- `loginWithOTP(mfaToken, otp)`
- `loginWithOOB(mfaToken, oobCode, bindingCode)`
- `loginWithRecoveryCode(mfaToken, recoveryCode)`
- `multifactorChallenge(mfaToken, challengeType, authenticatorId)`

**What to do:**

1. Call sites are identified during the Step 5 file-reading audit.
2. `MfaApiClient.kt` is fetched in Step 4 (under `authentication/mfa/`) — read it to confirm the exact replacement method signatures before applying changes. Do not guess method names.
3. Obtain the client with `AuthenticationAPIClient.mfaClient(mfaToken)`, then call the corresponding `MfaApiClient` method.
4. If a flow cannot be migrated confidently from the source, add a `// TODO:` and list it in the Step 10 summary.
5. Tell the user to **re-test every MFA flow end-to-end** — OTP, OOB (SMS/email), recovery code, and challenge — against their tenant configuration.

The `mfaToken` is obtained the same way as before: from an `AuthenticationException` raised during the initial login when MFA is required.

---

## Management API Removal — Backend Requirements

v4 removed `UsersAPIClient`, `ManagementException`, and `ManagementCallback`.

**What to do with call sites:**

1. Identified during the Step 5 audit (`UsersAPIClient`, `ManagementException`, `ManagementCallback`).
2. **Do not delete them.** Add a `// TODO:` comment preserving the intent and explaining the backend move.
3. In the Step 10 summary, list which operations were removed and state that they must move to a secure backend and that a Management API token must **never** be embedded in the app.

Recommended pattern:

```text
App  ──HTTPS (user access token)──▶  Your Backend  ──M2M token──▶  Auth0 Management API
```

The backend obtains a machine-to-machine token via the Client Credentials grant and calls the Management API with the minimum required scopes.

---

## Gson Transitive Dependency

v4 bumps the internal Gson dependency from 2.8.9 to 2.11.0. The SDK does not expose Gson in its public API, but it is a transitive runtime dependency. If the project also uses Gson directly, note the Gson 2.10+ behavior changes:

- `TypeToken` with unresolved type variables (e.g. `object : TypeToken<List<T>>() {}` where `T` is a generic parameter) throws `IllegalArgumentException` at runtime — use `reified` type parameters or concrete types.
- Strict type coercion: Gson no longer silently coerces JSON objects/arrays to `String`; this can surface as `JsonSyntaxException`.
- Gson 2.11.0 ships its own ProGuard/R8 keep rules, so custom Gson keep rules may be removable.

Escape hatch (not recommended long-term — the SDK is validated against 2.11.0):

```groovy
configurations.all {
    resolutionStrategy.force 'com.google.code.gson:gson:2.8.9'
}
```

---

## Deprecated vs. Removed

Do not confuse the two:

- **Removed** (compile errors, must fix): `PasskeyAuthProvider`, `UsersAPIClient`, the four deprecated MFA methods, `WebAuthProvider.useDPoP` as an object method, `DPoPException.UNSUPPORTED_ERROR`, the `Auth0`-based `SecureCredentialsManager` constructors, `SSOCredentials.expiresIn`.
- **Deprecated only** (still compiles, leave it): the `DefaultClient(...)` constructor — superseded by `DefaultClient.Builder` but not removed. Note it as an optional improvement in the summary; do not rewrite working code for it during migration.

---

## Rollback Procedure

```bash
# Option 1 — restore the backup branch created in Step 1
git checkout auth0-v4-migration-backup
# Then delete the migration branch only if the user confirms
git branch -D <migration-branch>

# Option 2 — revert all uncommitted changes (confirm before running)
git checkout -- .

# Option 3 — stash for later
git stash push -m "auth0-v4-migration-wip"
```

Always confirm with the user before any destructive git operation.

---

## Multi-Module Projects

If Auth0 is used across multiple modules:

```bash
# Find every module/source file importing the SDK
grep -rlE "import com\.auth0\.android" --include="*.kt" --include="*.java" .

# Find every module declaring the dependency
grep -rlE "com\.auth0\.android:auth0" --include=build.gradle --include=build.gradle.kts --include=libs.versions.toml .
```

Update the dependency wherever it is declared (or bump the single version-catalog entry once), apply API changes across all affected modules, and build the whole project (`./gradlew assembleDebug`) so errors surface for every module.

---

## Confirming a Signature Before Applying a Change

Before writing replacement code, locate the target in the source fetched in Step 4 and read its exact declaration. If the fetched source contradicts the examples in `SKILL.md`, **trust the fetched source** — it reflects the actual release being targeted.

```bash
# In the fetched SecureCredentialsManager.kt output — confirm the public constructors
grep -nE "public constructor\(|apiClient: AuthenticationAPIClient" SecureCredentialsManager.kt

# In the fetched SSOCredentials.kt output — confirm expiresAt and its type
grep -nE "expiresAt|expiresIn" SSOCredentials.kt

# In the fetched DPoPException.kt output — confirm UNSUPPORTED_ERROR is gone
grep -nE "UNSUPPORTED_ERROR" DPoPException.kt   # expect no match in v4
```
