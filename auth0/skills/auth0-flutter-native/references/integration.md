# Integration Patterns — Auth0 Flutter Native (iOS/Android)

## Authentication Flow

```text
User taps "Log In"
    ↓
auth0.webAuthentication().login()
    ↓
System browser (ASWebAuthenticationSession / Chrome Custom Tabs) opens Universal Login
    ↓ (user authenticates)
Auth0 redirects to the app's callback URL (App Link / Universal Link / custom scheme)
    ↓
SDK exchanges the code for tokens (PKCE) and stores them in CredentialsManager
    ↓
Credentials returned (accessToken, idToken, refreshToken, user)
    ↓
On next launch, CredentialsManager.credentials() returns cached tokens
(auto-renewing with the refresh token if expired)
```

---

## Web Auth Login & Logout

### Basic Login

```dart
import 'package:auth0_flutter/auth0_flutter.dart';

final auth0 = Auth0('YOUR_DOMAIN', 'YOUR_CLIENT_ID');

Future<Credentials> login() async {
  final credentials = await auth0.webAuthentication().login(
    scopes: {'openid', 'profile', 'email', 'offline_access'},
  );
  // Tokens are persisted automatically by the CredentialsManager.
  return credentials;
}
```

### Logout

```dart
Future<void> logout() async {
  await auth0.webAuthentication().logout();
  await auth0.credentialsManager.clearCredentials();
}
```

### Login with a Custom URL Scheme

Use this when `auth0Scheme` in `build.gradle` is set to a custom scheme rather than `https`. The scheme passed to Dart must match the Gradle/Info.plist value (lowercase on Android).

```dart
final webAuth = auth0.webAuthentication(scheme: 'yourcustomscheme');

final credentials = await webAuth.login(
  scopes: {'openid', 'profile', 'email', 'offline_access'},
);

await webAuth.logout();
```

### Sign Up (Direct to Registration Screen)

```dart
final credentials = await auth0.webAuthentication().login(
  scopes: {'openid', 'profile', 'email', 'offline_access'},
  parameters: {'screen_hint': 'signup'},
);
```

### Login with a Custom Audience (API Access Token)

```dart
final credentials = await auth0.webAuthentication().login(
  audience: 'https://your-api.example.com',
  scopes: {'openid', 'profile', 'email', 'offline_access', 'read:data'},
);
```

---

## Credential Management

The `CredentialsManager` securely stores tokens (Android Keystore / iOS Keychain) and renews them automatically.

### Restore a Session on Startup

```dart
Future<Credentials?> restoreSession() async {
  if (await auth0.credentialsManager.hasValidCredentials()) {
    // Auto-renews with the refresh token if the access token is expired.
    return await auth0.credentialsManager.credentials();
  }
  return null;
}
```

### Retrieve the User Profile

```dart
final userProfile = await auth0.credentialsManager.user();
if (userProfile != null) {
  print('Name:  ${userProfile.name}');
  print('Email: ${userProfile.email}');
}
```

### Request a Fresh Token for an API

```dart
final credentials = await auth0.credentialsManager.credentials(
  audience: 'https://your-api.example.com',
  scopes: {'read:data', 'write:data'},
);
final accessToken = credentials.accessToken;
```

### Clear Stored Credentials

```dart
await auth0.credentialsManager.clearCredentials();
```

---

## Biometric Protection

Require Face ID / Touch ID / fingerprint before the `CredentialsManager` returns stored credentials.

```dart
const localAuthentication = LocalAuthentication(
  title: 'Please authenticate to continue',
);

final auth0 = Auth0(
  'YOUR_DOMAIN',
  'YOUR_CLIENT_ID',
  localAuthentication: localAuthentication,
);

// The OS biometric prompt is shown before credentials are returned.
final credentials = await auth0.credentialsManager.credentials();
```

> **Android:** `MainActivity` must extend `FlutterFragmentActivity` (not `FlutterActivity`) for the biometric prompt to appear.
> **iOS:** add `NSFaceIDUsageDescription` to `Info.plist`.

---

## Error Handling

### Login Errors

```dart
Future<void> login() async {
  try {
    await auth0.webAuthentication().login(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  } on WebAuthenticationException catch (e) {
    if (e.isUserCancelledException) {
      // User dismissed the browser — no action needed.
    } else {
      print('Login failed: ${e.code} - ${e.message}');
    }
  }
}
```

### Credential Retrieval Errors

```dart
Future<void> getToken() async {
  try {
    final credentials = await auth0.credentialsManager.credentials();
    callApi(credentials.accessToken);
  } on CredentialsManagerException catch (e) {
    if (e.isNoCredentialsFound) {
      // Nothing stored — send the user to log in.
      await auth0.webAuthentication().login();
    } else if (e.isNoRefreshTokenFound) {
      // No refresh token (request `offline_access`) — re-login.
      await auth0.webAuthentication().login();
    } else if (e.isTokenRenewFailed) {
      // Refresh failed (revoked/expired) — clear and re-login.
      await auth0.credentialsManager.clearCredentials();
      await auth0.webAuthentication().login();
    } else {
      print('Credentials error: ${e.message}');
    }
  }
}
```

---

## Organizations

### Log in to a Specific Organization

```dart
final credentials = await auth0.webAuthentication().login(
  organizationId: 'org_YOUR_ORG_ID',
  scopes: {'openid', 'profile', 'email', 'offline_access'},
);
```

### Accept an Organization Invitation

```dart
// `invitationUrl` is the full URL the user opened from their invite email.
final credentials = await auth0.webAuthentication().login(
  invitationUrl: invitationUrl,
);
```

---

## Renewing Credentials Manually

Most apps should rely on `credentialsManager.credentials()` for automatic renewal. To renew explicitly with a refresh token:

```dart
final newCredentials = await auth0.api.renewCredentials(
  refreshToken: refreshToken,
);
await auth0.credentialsManager.storeCredentials(newCredentials);
```

### Native-to-Web SSO

```dart
final ssoCredentials = await auth0.credentialsManager.ssoCredentials();
```

---

## Calling Your API with the Access Token

```dart
import 'package:http/http.dart' as http;

Future<List<Item>> fetchItems() async {
  final credentials = await auth0.credentialsManager.credentials(
    audience: 'https://your-api.example.com',
  );

  final response = await http.get(
    Uri.parse('https://your-api.example.com/items'),
    headers: {'Authorization': 'Bearer ${credentials.accessToken}'},
  );

  if (response.statusCode == 401) {
    // Token rejected — clear and re-authenticate.
    await auth0.credentialsManager.clearCredentials();
    await auth0.webAuthentication().login(
      audience: 'https://your-api.example.com',
    );
    return [];
  }

  return parseItems(response.body);
}
```

---

## State Management Patterns

### Riverpod Pattern

```dart
// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auth0_flutter/auth0_flutter.dart';

final auth0Provider = Provider<Auth0>((ref) {
  return Auth0('YOUR_DOMAIN', 'YOUR_CLIENT_ID');
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<Credentials?>>((ref) {
  return AuthNotifier(ref.read(auth0Provider));
});

class AuthNotifier extends StateNotifier<AsyncValue<Credentials?>> {
  final Auth0 _auth0;

  AuthNotifier(this._auth0) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    if (await _auth0.credentialsManager.hasValidCredentials()) {
      state = AsyncValue.data(await _auth0.credentialsManager.credentials());
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login() async {
    final credentials = await _auth0.webAuthentication().login(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
    state = AsyncValue.data(credentials);
  }

  Future<void> logout() async {
    await _auth0.webAuthentication().logout();
    await _auth0.credentialsManager.clearCredentials();
    state = const AsyncValue.data(null);
  }
}
```

### Bloc Pattern

```dart
// lib/auth/auth_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auth0_flutter/auth0_flutter.dart';

// Events
abstract class AuthEvent {}
class AuthInitRequested extends AuthEvent {}
class AuthLoginRequested extends AuthEvent {}
class AuthLogoutRequested extends AuthEvent {}

// States
abstract class AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final Credentials credentials;
  AuthAuthenticated(this.credentials);
}
class AuthUnauthenticated extends AuthState {}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final Auth0 _auth0;

  AuthBloc({required String domain, required String clientId})
      : _auth0 = Auth0(domain, clientId),
        super(AuthLoading()) {
    on<AuthInitRequested>(_onInit);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onInit(AuthInitRequested event, Emitter<AuthState> emit) async {
    if (await _auth0.credentialsManager.hasValidCredentials()) {
      emit(AuthAuthenticated(await _auth0.credentialsManager.credentials()));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    final credentials = await _auth0.webAuthentication().login(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
    emit(AuthAuthenticated(credentials));
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _auth0.webAuthentication().logout();
    await _auth0.credentialsManager.clearCredentials();
    emit(AuthUnauthenticated());
  }
}
```

---

## Multi-Tenant / Environment Configuration

```dart
class AppConfig {
  final String auth0Domain;
  final String auth0ClientId;

  const AppConfig._({required this.auth0Domain, required this.auth0ClientId});

  static const development = AppConfig._(
    auth0Domain: 'dev-tenant.auth0.com',
    auth0ClientId: 'dev_client_id',
  );

  static const production = AppConfig._(
    auth0Domain: 'prod-tenant.auth0.com',
    auth0ClientId: 'prod_client_id',
  );
}

const config = bool.fromEnvironment('dart.vm.product')
    ? AppConfig.production
    : AppConfig.development;

final auth0 = Auth0(config.auth0Domain, config.auth0ClientId);
```
