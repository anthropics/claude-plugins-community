# Setup Guide — Auth0 Flutter Native (iOS/Android)

## Auth0 Configuration

> **Note:** For native mobile applications, the Auth0 Domain and Client ID are **public configuration** (not secrets). A native app uses PKCE with no client secret, and these values are safe to commit to source control. Pass them directly to `Auth0(domain, clientId)`.
>
> **Agent instruction:** Check whether Auth0 credentials (domain and client ID) are already provided in the user's prompt.
> - **If credentials are provided:** Use them directly in the `Auth0(...)` constructor and proceed to "Post-Setup Steps".
> - **If no credentials are provided:** Ask the user which setup they prefer using `AskUserQuestion`: _"How would you like to set up the Auth0 application — automatic (I run the Auth0 CLI to create it) or manual (you create it in the Auth0 Dashboard and provide the Domain + Client ID)?"_
>   - **Automatic:** Follow the Auth0 CLI steps below.
>   - **Manual:** Ask the user for their Auth0 Domain and Client ID, then go straight to "Using Credentials" and the Post-Setup Steps.

### Create the Auth0 Application (Auth0 CLI)

> **Agent instruction:** Run these preflight checks first. Do NOT run `auth0 login` from the agent — it is interactive and will hang.
>
> 1. **Check the Auth0 CLI is installed**: `command -v auth0`. If missing, install per platform — macOS: `brew install auth0/auth0-cli/auth0`; Linux: `curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh`. See https://github.com/auth0/auth0-cli.
> 2. **Check login / active tenant**: `auth0 tenants list --json --no-input`. If it fails or returns empty:
>    - Tell the user: _"Please run `auth0 login` in your terminal and let me know when done."_
>    - Wait for confirmation, then re-run. Retry up to 3 times before treating as a persistent failure.
> 3. **Confirm the active tenant**: select the tenant where `active` is `true` from the JSON output:
>
>    ```bash
>    auth0 tenants list --json --no-input | jq -r '.[] | select(.active) | .domain'
>    ```
>
>    Tell the user: _"Your active Auth0 tenant is `<domain>`. Is this correct?"_ If not, ask them to run `auth0 tenants use <tenant-domain>`, then re-check. This domain is the `domain` value for `Auth0(...)`.

**Step 1 — Determine the platform identifiers.** The Native callback URLs are built from the Android package name and the iOS bundle identifier:
- **Android package name** — the `applicationId` in `android/app/build.gradle`.
- **iOS bundle identifier** — `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` (the Runner target, not RunnerTests).

**Step 2 — Create the Native application.** This registers both platform callback URLs and logout URLs in one command. Use the Flutter project name (from `pubspec.yaml`) for `--name`, and substitute the real domain, package name, and bundle id:

```bash
auth0 apps create \
  --name "My Flutter App" \
  --type native \
  --callbacks "https://YOUR_DOMAIN/android/ANDROID_PACKAGE_NAME/callback,https://YOUR_DOMAIN/ios/IOS_BUNDLE_ID/callback" \
  --logout-urls "https://YOUR_DOMAIN/android/ANDROID_PACKAGE_NAME/callback,https://YOUR_DOMAIN/ios/IOS_BUNDLE_ID/callback" \
  --no-input --json
```

The JSON output includes `client_id` — this is the `clientId` value for `Auth0(...)`. (Before creating, you can run `auth0 apps list --json --no-input` to check for an existing Native app of the same name and reuse it — see "Configure Callback URLs" below to update its URLs with `auth0 apps update`.)

**Step 3 — Ensure the database connection is enabled for the app.** Most tenants already have a `Username-Password-Authentication` connection. Enable it for the new application **without disconnecting other apps** — fetch the existing `enabled_clients`, append `CLIENT_ID`, then patch the merged list back.

> **Agent instruction:**
>
> 1. Find `CONNECTION_ID` (match `name` = `Username-Password-Authentication`):
>
>    ```bash
>    auth0 api get connections --no-input | jq -r '.[] | select(.name == "Username-Password-Authentication") | .id'
>    ```
>
> 2. Build the **merged** `enabled_clients` array from the connection's current value, then patch that computed array back. The `jq` expression reads the existing list (defaulting to `[]` if the connection had none), appends `CLIENT_ID`, and dedupes with `unique` — so it never overwrites or disconnects the other applications already on the connection. Do **not** patch `["CLIENT_ID"]` alone.
>
>    ```bash
>    MERGED_CLIENTS=$(auth0 api get "connections/CONNECTION_ID" --no-input |
>      jq -c --arg cid "CLIENT_ID" '(.enabled_clients // []) + [$cid] | unique')
>
>    auth0 api patch "connections/CONNECTION_ID" \
>      --data "{\"enabled_clients\":$MERGED_CLIENTS}" \
>      --no-input
>    ```
>
> If no `Username-Password-Authentication` connection exists, create one:
>
> ```bash
> auth0 api post connections \
>   --data '{"name":"Username-Password-Authentication","strategy":"auth0","enabled_clients":["CLIENT_ID"]}' \
>   --no-input
> ```

After these steps you have a `domain` and `client_id`. Pass them directly to `Auth0` (see "Using Credentials" below), then continue to the Post-Setup Steps.

### Using Credentials

Pass the domain and client ID directly to the `Auth0` constructor in your Dart code:

```dart
final auth0 = Auth0('YOUR_AUTH0_DOMAIN', 'YOUR_AUTH0_CLIENT_ID');
```

There is no separate config file (like `Auth0.plist` for native Swift) — credentials are passed directly to the `Auth0` constructor in Dart code. The only platform configuration needed is the Android `manifestPlaceholders` and (for custom schemes / older iOS) the iOS `Info.plist` URL type.

---

## Post-Setup Steps

### Android Configuration (Required)

The SDK ships a `RedirectActivity` with an intent filter that consumes the `auth0Domain` and `auth0Scheme` manifest placeholders. You must declare these in `android/app/build.gradle`:

```groovy
// android/app/build.gradle
android {
    defaultConfig {
        manifestPlaceholders = [auth0Domain: "YOUR_AUTH0_DOMAIN", auth0Scheme: "https"]
    }
}
```

Kotlin DSL (`android/app/build.gradle.kts`):
```kotlin
android {
    defaultConfig {
        manifestPlaceholders["auth0Domain"] = "YOUR_AUTH0_DOMAIN"
        manifestPlaceholders["auth0Scheme"] = "https"
    }
}
```

> **Agent instruction:**
> 1. Read `android/app/build.gradle` (or `.kts`).
> 2. If `manifestPlaceholders` is missing, add it inside `defaultConfig`.
> 3. If it already exists with other entries, merge the `auth0Domain` and `auth0Scheme` keys in (use `+=` for Groovy maps).
> 4. Ensure `<uses-permission android:name="android.permission.INTERNET" />` is present in `android/app/src/main/AndroidManifest.xml`.

- **`auth0Scheme: "https"`** → uses Android App Links (recommended, no scheme to maintain).
- **Custom scheme** → set `auth0Scheme` to a lowercase string (e.g. the package name) and pass the same string to `webAuthentication(scheme: '...')` in Dart.

For biometric credential protection, `MainActivity` must extend `FlutterFragmentActivity`:

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

### iOS Configuration

For the default HTTPS / Universal Link flow on **iOS 17.4+**, add the **Associated Domains** capability in Xcode:

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **Signing & Capabilities**.
3. Add the **Associated Domains** capability.
4. Add an entry: `webcredentials:YOUR_AUTH0_DOMAIN`

For **older iOS** or when using a **custom URL scheme**, add a URL type to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>None</string>
    <key>CFBundleURLName</key>
    <string>auth0</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    </array>
  </dict>
</array>
```

For Face ID biometric protection, add a usage description to `Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to secure your session.</string>
```

### Configure Callback URLs in Auth0 Dashboard

For a Native application, register platform-specific callback and logout URLs:

| Field | Value |
|-------|-------|
| Allowed Callback URLs (Android) | `https://YOUR_DOMAIN/android/YOUR_PACKAGE_NAME/callback` |
| Allowed Callback URLs (iOS) | `https://YOUR_DOMAIN/ios/YOUR_BUNDLE_ID/callback` |
| Allowed Logout URLs (Android) | `https://YOUR_DOMAIN/android/YOUR_PACKAGE_NAME/callback` |
| Allowed Logout URLs (iOS) | `https://YOUR_DOMAIN/ios/YOUR_BUNDLE_ID/callback` |

> **Agent instruction:** Determine the Android package name from `android/app/build.gradle` (`applicationId`) and the iOS bundle identifier (`PRODUCT_BUNDLE_IDENTIFIER` in the Xcode project / `ios/Runner.xcodeproj/project.pbxproj`). Then register both platforms in one CLI call:
> ```bash
> auth0 apps update CLIENT_ID \
>   --callbacks "https://YOUR_DOMAIN/android/ANDROID_PACKAGE_NAME/callback,https://YOUR_DOMAIN/ios/IOS_BUNDLE_ID/callback" \
>   --logout-urls "https://YOUR_DOMAIN/android/ANDROID_PACKAGE_NAME/callback,https://YOUR_DOMAIN/ios/IOS_BUNDLE_ID/callback" \
>   --no-input
> ```
>
> If using a **custom scheme** instead of HTTPS, the callback host changes to the scheme (e.g. `YOUR_PACKAGE_NAME://YOUR_DOMAIN/android/YOUR_PACKAGE_NAME/callback`).

---

## SDK Installation

> **Agent instruction:** Check the project directory for `pubspec.yaml`. If found, add the dependency:
> ```bash
> flutter pub add auth0_flutter
> ```
>
> If `pubspec.yaml` is not found, this is not a Flutter project. Ask the user for the correct project path.

### pubspec.yaml

```yaml
dependencies:
  auth0_flutter: ^2.1.0
```

After adding, run:
```bash
flutter pub get
```

---

## Secret Management

Auth0 Flutter Native **does not use a client secret**. Native applications use PKCE (Proof Key for Code Exchange) + the authorization code flow, which is secure without a secret.

- `domain` and `clientId` passed to `Auth0()` are **not secrets** — they are public identifiers safe to commit to source control.
- Access, ID, and refresh tokens are stored by the `CredentialsManager` in the platform secure storage (Android Keystore / iOS Keychain).
- No `.env` files are required for the Auth0 configuration. The Android `manifestPlaceholders` values may be committed.
- **Never** add a client secret to a mobile app.

---

## Running the App

```bash
# Run on a connected device or emulator
flutter run

# Build debug APK (Android)
flutter build apk --debug

# Build for iOS (on macOS)
flutter build ios --no-codesign
```

---

## Verification

After completing setup, verify:

- [ ] `auth0_flutter` is in `pubspec.yaml` dependencies
- [ ] `android/app/build.gradle` has `manifestPlaceholders` with `auth0Domain` and `auth0Scheme`
- [ ] iOS Associated Domains capability (or `Info.plist` URL type for custom scheme) is configured
- [ ] `Auth0` is instantiated with the correct domain and client ID
- [ ] `credentialsManager.hasValidCredentials()` is called on app startup to restore the session
- [ ] Android and iOS callback URLs are saved in Auth0 Dashboard
- [ ] App builds without errors (`flutter build apk --debug`)
- [ ] Login opens the system browser and returns to the app
