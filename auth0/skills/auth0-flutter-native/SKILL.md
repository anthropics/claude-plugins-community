---
name: auth0-flutter-native
description: >
  Use when adding Auth0 login, logout, or biometric-protected credential storage to a Flutter mobile app (iOS or Android). Integrates auth0_flutter on the native platform — use even if the user says "add login to my Flutter app".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Flutter Native (iOS/Android) Integration

`auth0_flutter` is the official Auth0 SDK for Flutter applications. On **mobile (iOS/Android)**, it performs authentication through the device's system browser (Web Auth / Universal Login) and stores tokens securely in the platform keychain/keystore via the built-in `CredentialsManager`, with optional biometric protection.

> **Agent instruction:** Before providing SDK setup instructions, fetch the latest release version by running one of:
> ```bash
> gh api repos/auth0/auth0-flutter/releases/latest --jq '.tag_name'
> ```
> ```bash
> flutter pub info auth0_flutter 2>/dev/null | head -5
> ```
> Or check pub.dev:
> ```bash
> curl -s https://pub.dev/api/packages/auth0_flutter | python3 -c "import sys,json;print(json.load(sys.stdin)['latest']['version'])"
> ```
> Use the returned version in all dependency lines instead of any hardcoded version below. Current known version: `2.1.0`.

## When NOT to Use

- **Flutter web**: Use [auth0-flutter-web](/auth0-flutter-web) — web uses a different platform interface (`Auth0Web`) wrapping Auth0 SPA JS
- **Native iOS (Swift, no Flutter)**: Use [auth0-swift](/auth0-swift)
- **Native Android (Kotlin/Java, no Flutter)**: Use [auth0-android](/auth0-android)
- **React Native**: Use [auth0-react-native](/auth0-react-native)
- **React SPA**: Use [auth0-react](/auth0-react)
- **Node.js/Express servers**: Use [auth0-express](/auth0-express)

## Prerequisites

- **Flutter** 3.24.0+
- **Dart** 3.5.0+
- **Android**: minSdkVersion 21+, compileSdkVersion 34+
- **iOS**: 14.0+ (Universal Link callbacks require iOS 17.4+)
- Auth0 account — [Sign up free](https://auth0.com/signup)
- Auth0 CLI — [install instructions](https://github.com/auth0/auth0-cli) (used to create and configure the Auth0 application)

## Quick Start Workflow

> **Agent instruction:** Follow these steps in order. If you encounter an error at any step, attempt to fix it up to 5 times before calling `AskUserQuestion` to ask the user for guidance. Always search existing code first — if there are existing login/logout handlers, hook into them rather than creating new ones.

### Step 1 — Install SDK

> **Agent instruction:** Check the project directory for `pubspec.yaml`. If present, add the dependency. If not found, this is not a Flutter project — ask the user.
>
> Run in the project root:
> ```bash
> flutter pub add auth0_flutter
> ```
>
> Verify the dependency was added to `pubspec.yaml`:
> ```yaml
> dependencies:
>   auth0_flutter: ^2.1.0
> ```

### Step 2 — Configure Auth0

> **Note:** The Auth0 Domain and Client ID are **public configuration** (not secrets) — a native app uses PKCE with no client secret. Pass them directly to `Auth0(domain, clientId)`; there is no need to store them in environment variables or hide them.
>
> **Agent instruction:**
> - **If Auth0 credentials (domain AND client ID) are already in the user's prompt:** Use those values directly in the `Auth0(...)` constructor and proceed to Step 3.
> - **If no credentials are provided:** Ask the user which setup they prefer using `AskUserQuestion`: _"How would you like to set up the Auth0 application — automatic (I run the Auth0 CLI to create it) or manual (you create it in the Auth0 Dashboard and give me the Domain + Client ID)?"_
>   - **Automatic:** Follow the Auth0 CLI steps in the Setup Guide to create the Native application.
>   - **Manual:** Ask the user for their Auth0 Domain and Client ID and use them directly.
>
> Follow [Setup Guide — Auth0 Configuration](./references/setup.md#auth0-configuration) for the pre-flight checks and the `auth0 apps create` command.

### Step 3 — Configure Android

> **Agent instruction:** Edit `android/app/build.gradle` (or `build.gradle.kts`) and add `manifestPlaceholders` inside `android { defaultConfig { ... } }`. These supply the callback URL the SDK's `RedirectActivity` intent filter registers — without them the app will not build correctly for Auth0.

For `android/app/build.gradle` (Groovy):
```groovy
android {
    defaultConfig {
        manifestPlaceholders = [auth0Domain: "YOUR_AUTH0_DOMAIN", auth0Scheme: "https"]
    }
}
```

For `android/app/build.gradle.kts` (Kotlin DSL):
```kotlin
android {
    defaultConfig {
        manifestPlaceholders["auth0Domain"] = "YOUR_AUTH0_DOMAIN"
        manifestPlaceholders["auth0Scheme"] = "https"
    }
}
```

> **Agent instruction:** Use `auth0Scheme: "https"` to use Android App Links (recommended). If the app targets a custom scheme instead, set it to a lowercase scheme string and pass the same scheme to `webAuthentication(scheme: ...)` in Dart. See [Setup Guide](./references/setup.md) for details.

### Step 4 — Configure iOS

> **Agent instruction:** For the default HTTPS (Universal Link) flow on iOS 17.4+, no `Info.plist` change is required, but the **Associated Domains** capability must be added in Xcode (`webcredentials:YOUR_AUTH0_DOMAIN`). For older iOS or a custom URL scheme, add a `CFBundleURLTypes` entry to `ios/Runner/Info.plist`:

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

### Step 5 — Configure Callback URLs

> **Agent instruction:** Register the platform-specific callback and logout URLs using the Auth0 CLI. Determine the Android package name (from `android/app/build.gradle` `applicationId`) and the iOS bundle identifier (from Xcode / `PRODUCT_BUNDLE_IDENTIFIER`), then run the command below, replacing the placeholders (`CLIENT_ID`, `YOUR_DOMAIN`, `ANDROID_PACKAGE_NAME`, `IOS_BUNDLE_ID`) with the project's values:
>
> ```bash
> auth0 apps update CLIENT_ID \
>   --callbacks "https://YOUR_DOMAIN/android/ANDROID_PACKAGE_NAME/callback,https://YOUR_DOMAIN/ios/IOS_BUNDLE_ID/callback" \
>   --logout-urls "https://YOUR_DOMAIN/android/ANDROID_PACKAGE_NAME/callback,https://YOUR_DOMAIN/ios/IOS_BUNDLE_ID/callback" \
>   --no-input
> ```

The callback URL formats are:
- **Android**: `https://YOUR_DOMAIN/android/YOUR_PACKAGE_NAME/callback`
- **iOS**: `https://YOUR_DOMAIN/ios/YOUR_BUNDLE_ID/callback`

### Step 6 — Implement Authentication

> **Agent instruction:** Search the project for the main app entry point (`main.dart`). Determine the state management approach:
> - Look for `provider`, `riverpod`, `bloc`, `GetX`, or `mobx` imports
> - If none found, use basic `StatefulWidget` with `setState`
>
> Then follow **only** the matching path below. If ambiguous, ask via `AskUserQuestion`: _"Which state management approach does your Flutter app use — Provider, Riverpod, Bloc, or basic setState?"_

#### Basic StatefulWidget (Default)

> **Agent instruction:** Create an `AuthService` class, then wire it into the app's root widget. Search for the `MaterialApp` or `CupertinoApp` widget and update accordingly. On startup, restore the session from the `CredentialsManager` cache.

```dart
// lib/auth_service.dart
import 'package:auth0_flutter/auth0_flutter.dart';

class AuthService {
  late final Auth0 _auth0;
  Credentials? _credentials;

  AuthService({required String domain, required String clientId}) {
    _auth0 = Auth0(domain, clientId);
  }

  bool get isAuthenticated => _credentials != null;
  UserProfile? get user => _credentials?.user;

  /// Restore a stored session on app startup, if one exists.
  Future<void> init() async {
    final hasValid = await _auth0.credentialsManager.hasValidCredentials();
    if (hasValid) {
      _credentials = await _auth0.credentialsManager.credentials();
    }
  }

  /// Launch Web Auth via the system browser. Tokens are stored automatically.
  Future<void> login() async {
    _credentials = await _auth0
        .webAuthentication()
        .login(scopes: {'openid', 'profile', 'email', 'offline_access'});
  }

  /// Clear the session in the browser and wipe stored credentials.
  Future<void> logout() async {
    await _auth0.webAuthentication().logout();
    await _auth0.credentialsManager.clearCredentials();
    _credentials = null;
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:auth0_flutter/auth0_flutter.dart'; // for WebAuthenticationException
import 'auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _authService = AuthService(
    domain: 'YOUR_AUTH0_DOMAIN',
    clientId: 'YOUR_AUTH0_CLIENT_ID',
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    await _authService.init();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _authService.isAuthenticated
              ? HomeScreen(authService: _authService, onChanged: _refresh)
              : LoginScreen(authService: _authService, onChanged: _refresh),
    );
  }

  void _refresh() => setState(() {});
}

class LoginScreen extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onChanged;
  const LoginScreen({super.key, required this.authService, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Capture the messenger before the await to avoid using
            // BuildContext across an async gap.
            final messenger = ScaffoldMessenger.of(context);
            try {
              await authService.login();
              onChanged();
            } on WebAuthenticationException catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Login failed: ${e.message}')),
              );
            }
          },
          child: const Text('Log In'),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onChanged;
  const HomeScreen({super.key, required this.authService, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final user = authService.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () async {
              await authService.logout();
              onChanged();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user?.pictureUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(user!.pictureUrl.toString()),
                radius: 40,
              ),
            const SizedBox(height: 16),
            Text('Welcome, ${user?.name ?? 'User'}!'),
            Text(user?.email ?? ''),
          ],
        ),
      ),
    );
  }
}
```

#### Provider (State Management)

> **Agent instruction:** If the project uses `provider`, create `AuthService` as a `ChangeNotifier` and inject it via `ChangeNotifierProvider` at the app root.

```dart
// lib/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:auth0_flutter/auth0_flutter.dart';

class AuthService extends ChangeNotifier {
  late final Auth0 _auth0;
  Credentials? _credentials;
  bool _isLoading = true;

  AuthService({required String domain, required String clientId}) {
    _auth0 = Auth0(domain, clientId);
  }

  bool get isAuthenticated => _credentials != null;
  bool get isLoading => _isLoading;
  UserProfile? get user => _credentials?.user;

  Future<void> init() async {
    if (await _auth0.credentialsManager.hasValidCredentials()) {
      _credentials = await _auth0.credentialsManager.credentials();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login() async {
    _credentials = await _auth0
        .webAuthentication()
        .login(scopes: {'openid', 'profile', 'email', 'offline_access'});
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth0.webAuthentication().logout();
    await _auth0.credentialsManager.clearCredentials();
    _credentials = null;
    notifyListeners();
  }
}
```

```dart
// lib/main.dart — wrap with ChangeNotifierProvider
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(
        domain: 'YOUR_AUTH0_DOMAIN',
        clientId: 'YOUR_AUTH0_CLIENT_ID',
      )..init(),
      child: const MyApp(),
    ),
  );
}
```

For complete patterns with Riverpod, Bloc, biometrics, and advanced scenarios, see [Integration Patterns](./references/integration.md).

### Step 7 — Verify Build

> **Agent instruction:** Run a build to verify the integration compiles without errors:
> ```bash
> flutter build apk --debug      # Android
> flutter build ios --no-codesign  # iOS (on macOS)
> ```
> Then run the app on a device or emulator to test:
> ```bash
> flutter run
> ```
> If the build fails, review error messages and fix up to 5 times before asking the user.
>
> **Physical device testing:** Biometric protection (Face ID / Touch ID / fingerprint) cannot be exercised on a simulator/emulator — the iOS Simulator and Android emulator have limited or no biometric hardware. Test biometrics and the full Universal Login redirect on a real physical device before release.

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 application creation via the Auth0 CLI, Android `manifestPlaceholders`, iOS `Info.plist` / Associated Domains, callback URL registration
- **[Integration Patterns](./references/integration.md)** — Web Auth login/logout, CredentialsManager, biometric protection, custom schemes, organizations, API access tokens, state management patterns, error handling
- **[API Reference & Testing](./references/api.md)** — Full API reference, configuration options, claims reference, testing checklist, troubleshooting

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Auth0 app type not set to **Native** | Create the application with `auth0 apps create --type native` (or select "Native" in the Auth0 Dashboard) |
| Missing `manifestPlaceholders` on Android | Add `manifestPlaceholders = [auth0Domain: "...", auth0Scheme: "https"]` to `android/app/build.gradle` `defaultConfig` — the build fails without it |
| Using `Auth0Web` on mobile | Mobile uses the `Auth0` class with `webAuthentication()`, not `Auth0Web` (that's the web-only API) |
| Importing `auth0_flutter_web.dart` on mobile | Only import `package:auth0_flutter/auth0_flutter.dart` — the `_web` import is for Flutter web |
| Callback URL mismatch | Register `https://YOUR_DOMAIN/android/PACKAGE_NAME/callback` and `https://YOUR_DOMAIN/ios/BUNDLE_ID/callback` in Allowed Callback URLs |
| Scheme mismatch between Gradle and Dart | If `auth0Scheme` is a custom scheme, pass the same value to `webAuthentication(scheme: 'myscheme')` |
| Custom scheme with uppercase letters on Android | Android custom schemes must be all lowercase |
| Biometrics prompt never appears on Android | `MainActivity` must extend `FlutterFragmentActivity` (not `FlutterActivity`) for the biometric prompt to work |
| Not storing credentials after login | `webAuthentication().login()` stores credentials automatically; do NOT also re-store unless renewing manually via `api.renewCredentials` |
| Not restoring session on startup | Call `credentialsManager.hasValidCredentials()` + `credentials()` in `initState()` to restore the session |
| Missing `offline_access` scope | Add `'offline_access'` to scopes so the CredentialsManager can silently renew expired access tokens with a refresh token |
| Catching generic `Exception` | Catch `WebAuthenticationException` (login/logout) and `CredentialsManagerException` (credential errors) and inspect `isUserCancelledException`, `isNoCredentialsFound`, `isTokenRenewFailed`, etc. |

## Related Skills

- **[auth0-quickstart](/auth0-quickstart)** — Initial Auth0 setup and account creation
- **[auth0-flutter-web](/auth0-flutter-web)** — Same SDK, web platform
- **[auth0-swift](/auth0-swift)** — Native iOS (Swift)
- **[auth0-android](/auth0-android)** — Native Android (Kotlin/Java)

## Quick Reference

| API | Purpose |
|-----|---------|
| `Auth0(domain, clientId)` | Create the SDK client |
| `auth0.webAuthentication().login(...)` | Launch Universal Login in the system browser |
| `auth0.webAuthentication().logout()` | Clear the browser session |
| `auth0.webAuthentication(scheme: '...')` | Use a custom URL scheme |
| `auth0.credentialsManager.credentials()` | Get stored credentials (auto-renews if expired) |
| `auth0.credentialsManager.hasValidCredentials()` | Check for a valid stored session |
| `auth0.credentialsManager.clearCredentials()` | Wipe stored credentials |
| `LocalAuthentication(title: ...)` | Enable biometric protection of stored credentials |

## References

- [auth0_flutter on pub.dev](https://pub.dev/packages/auth0_flutter)
- [auth0_flutter GitHub](https://github.com/auth0/auth0-flutter)
- [Flutter Quickstart (Native)](https://auth0.com/docs/quickstart/native/flutter)
- [Auth0 Dashboard](https://manage.auth0.com)
