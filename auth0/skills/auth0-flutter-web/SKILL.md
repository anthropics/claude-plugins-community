---
name: auth0-flutter-web
description: >
  Use when adding Auth0 login or logout to a Flutter web application. Integrates auth0_flutter on the web platform — use even if the user says "add login to my Flutter web app".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Flutter Web Integration

`auth0_flutter` is the official Auth0 SDK for Flutter applications. On the **web platform**, it wraps the Auth0 SPA JS SDK to provide browser-based authentication via redirect or popup flows with built-in credential caching and automatic token renewal.

> **Agent instruction:** The current SDK version is `2.1.0`. Use this version in all dependency lines below. If you need to verify, run `flutter pub add auth0_flutter` which will resolve the latest compatible version automatically.

## When NOT to Use

- **Flutter mobile (iOS/Android)**: Use [auth0-flutter-native](/auth0-flutter-native) — mobile uses a different platform interface with Web Auth via system browser
- **Native iOS (Swift)**: Use [auth0-swift](/auth0-swift)
- **Native Android (Kotlin/Java)**: Use [auth0-android](/auth0-android)
- **React SPA**: Use [auth0-react](/auth0-react)
- **Angular SPA**: Use [auth0-angular](/auth0-angular)
- **Vue SPA**: Use [auth0-vue](/auth0-vue)
- **Node.js/Express servers**: Use [auth0-express](/auth0-express)

## Prerequisites

- **Flutter** 3.24.0+
- **Dart** 3.5.0+
- Auth0 account — [Sign up free](https://auth0.com/signup)
- Auth0 CLI — [install instructions](https://github.com/auth0/auth0-cli) (used to create and configure the Auth0 application)

## Quick Start Workflow

> **Agent instruction:** Follow these steps in order. If you encounter an error at any step, attempt to fix it up to 5 times before calling `AskUserQuestion` to ask the user for guidance. Always search existing code first — if there are existing login/logout handlers, hook into them rather than creating new ones.

### Step 1 — Install SDK

> **Agent instruction:** Check the project directory for `pubspec.yaml`. If present, add the dependency. If not found, this is not a Flutter project — ask the user.
>
> Run in the project root:
>
> ```bash
> flutter pub add auth0_flutter
> ```
>
> Verify the dependency was added to `pubspec.yaml`:
>
> ```yaml
> dependencies:
>   auth0_flutter: ^2.1.0
> ```

### Step 2 — Configure Auth0

> **Note:** For Single Page Applications, the Auth0 Domain and Client ID are **public configuration** (not secrets). A SPA uses PKCE with no client secret, and these values ship in the browser bundle. Pass them directly to `Auth0Web(domain, clientId)` — there is no need to store them in environment variables or hide them.
>
> **Agent instruction:**
> - **If Auth0 credentials (domain AND client ID) are already in the user's prompt:** Proceed to Step 3 and use those values directly in the `Auth0Web(...)` constructor.
> - **If no credentials are provided:** Create the application with the Auth0 CLI — do NOT ask the user to create or configure an Auth0 application manually in the Dashboard. Always use the CLI path.
>
> Follow [Setup Guide — Auth0 Configuration](./references/setup.md#auth0-configuration) for the pre-flight checks and the `auth0 apps create` command.

### Step 3 — Add Auth0 SPA JS to index.html

> **Agent instruction:**
> 1. Locate the web entry point: `web/index.html`
> 2. Add the Auth0 SPA JS script tag inside `<head>`:
>
> ```html
> <script src="https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js" defer></script>
> ```
>
> If `web/index.html` does not exist, the user may need to run `flutter create . --platforms=web` to add web support.

### Step 4 — Configure Callback URLs

> **Agent instruction:**
> 1. Determine the app's web URL. For local development, default is `http://localhost:3000` (when running with `--web-port 3000`).
> 2. Ask the user via `AskUserQuestion`: _"What port will you run your Flutter web app on locally? (default: 3000)"_
> 3. Register the callback URLs using the Auth0 CLI (substitute real values for `CLIENT_ID`, `APP_URL`):
>
> ```bash
> auth0 apps update CLIENT_ID \
>   --callbacks "APP_URL" \
>   --logout-urls "APP_URL" \
>   --web-origins "APP_URL" \
>   --no-input
> ```
>
> For production, also add the production URL to each list.

### Step 5 — Implement Authentication

> **Agent instruction:** Search the project for the main app entry point (`main.dart`). Determine the state management approach:
> - Look for `provider`, `riverpod`, `bloc`, `GetX`, or `mobx` imports
> - If none found, use basic `StatefulWidget` with `setState`
>
> Then follow **only** the matching path below. If ambiguous, ask via `AskUserQuestion`: _"Which state management approach does your Flutter app use — Provider, Riverpod, Bloc, or basic setState?"_

#### Basic StatefulWidget (Default)

> **Agent instruction:** Create an `AuthService` class, then wire it into the app's root widget. Search for the `MaterialApp` or `CupertinoApp` widget and update accordingly.

```dart
// lib/auth_service.dart
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

class AuthService {
  late final Auth0Web _auth0;
  Credentials? _credentials;

  AuthService({required String domain, required String clientId}) {
    _auth0 = Auth0Web(domain, clientId);
  }

  bool get isAuthenticated => _credentials != null;
  Credentials? get credentials => _credentials;
  UserProfile? get user => _credentials?.user;

  /// Call on app startup to restore session from cache
  Future<void> onLoad() async {
    _credentials = await _auth0.onLoad();
  }

  /// Redirect to Auth0 Universal Login
  Future<void> loginWithRedirect({String? redirectUrl}) async {
    await _auth0.loginWithRedirect(
      redirectUrl: redirectUrl,
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  }

  /// Open Auth0 login in a popup window
  Future<void> loginWithPopup() async {
    _credentials = await _auth0.loginWithPopup(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  }

  /// Get cached credentials (auto-refreshes if expired)
  Future<Credentials> getCredentials() async {
    final creds = await _auth0.credentials();
    _credentials = creds;
    return creds;
  }

  /// Check if valid credentials exist
  Future<bool> hasValidCredentials() async {
    return await _auth0.hasValidCredentials();
  }

  /// Logout and redirect back to the app
  Future<void> logout({String? returnToUrl}) async {
    await _auth0.logout(returnToUrl: returnToUrl);
    _credentials = null;
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
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
    await _authService.onLoad();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _authService.isAuthenticated
              ? HomeScreen(authService: _authService)
              : LoginScreen(authService: _authService),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final AuthService authService;
  const LoginScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => authService.loginWithRedirect(),
          child: const Text('Log In'),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final AuthService authService;
  const HomeScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final user = authService.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () => authService.logout(
              returnToUrl: Uri.base.origin,
            ),
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
import 'package:auth0_flutter/auth0_flutter_web.dart';

class AuthService extends ChangeNotifier {
  late final Auth0Web _auth0;
  Credentials? _credentials;
  bool _isLoading = true;

  AuthService({required String domain, required String clientId}) {
    _auth0 = Auth0Web(domain, clientId);
  }

  bool get isAuthenticated => _credentials != null;
  bool get isLoading => _isLoading;
  UserProfile? get user => _credentials?.user;

  Future<void> init() async {
    _credentials = await _auth0.onLoad();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loginWithRedirect() async {
    await _auth0.loginWithRedirect(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  }

  Future<void> loginWithPopup() async {
    _credentials = await _auth0.loginWithPopup(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth0.logout(returnToUrl: Uri.base.origin);
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

For complete patterns with Riverpod, Bloc, and advanced scenarios, see [Integration Patterns](./references/integration.md).

### Step 6 — Verify Build

> **Agent instruction:** Run a build to verify the integration compiles without errors:
>
> ```bash
> flutter build web
> ```
>
> Then run the app locally to test:
>
> ```bash
> flutter run -d chrome --web-port 3000
> ```
>
> If the build fails, review error messages and fix up to 5 times before asking the user.

## Detailed Documentation

- **[Setup Guide](./references/setup.md)** — Auth0 application creation via the Auth0 CLI, web/index.html setup, callback URL registration
- **[Integration Patterns](./references/integration.md)** — Redirect login, popup login, credential management, state management patterns, organization support, error handling
- **[API Reference & Testing](./references/api.md)** — Full API reference, configuration options, claims reference, testing checklist, troubleshooting

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Auth0 app type not set to **Single Page Application** | In Auth0 Dashboard, select "Single Page Application" when creating the application |
| Missing Auth0 SPA JS script in `web/index.html` | Add `<script src="https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js" defer></script>` to `<head>` |
| Not calling `onLoad()` on app startup | Always call `onLoad()` in `initState()` or equivalent to restore sessions after redirect |
| Missing `Allowed Web Origins` in Auth0 Dashboard | Add your app URL (e.g., `http://localhost:3000`) to Allowed Web Origins — required for silent token renewal |
| Using `auth0_flutter` mobile API on web | Import **both** `package:auth0_flutter/auth0_flutter.dart` (for types like `Credentials`, `UserProfile`) AND `package:auth0_flutter/auth0_flutter_web.dart` (for `Auth0Web` class) |
| Missing base import causes type errors | `Credentials` and `UserProfile` are exported from `auth0_flutter.dart`, not `auth0_flutter_web.dart` — you need both imports |
| Callback URL mismatch | Ensure `Allowed Callback URLs` matches the exact URL where your app runs (including port) |
| Not adding `--web-port` when running locally | Use `flutter run -d chrome --web-port 3000` to ensure consistent port matching callback URLs |
| Popup blocked by browser | `loginWithPopup()` must be called from a direct user interaction (button click); cannot be called from `initState()` |
| Missing `offline_access` scope | Add `'offline_access'` to scopes set to enable refresh token rotation for silent renewal |
| CORS errors on token endpoint | Ensure `Allowed Web Origins` is configured in Auth0 Dashboard (not just Callback URLs) |

## References

- [auth0_flutter on pub.dev](https://pub.dev/packages/auth0_flutter)
- [auth0_flutter GitHub](https://github.com/auth0/auth0-flutter)
- [Flutter Web Quickstart](https://auth0.com/docs/quickstart/spa/flutter)
- [Auth0 Dashboard](https://manage.auth0.com)
- [Auth0 SPA JS SDK](https://github.com/auth0/auth0-spa-js)
