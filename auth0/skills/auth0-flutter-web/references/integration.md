# Integration Patterns — Auth0 Flutter Web

## Authentication Flow

```text
User clicks "Log In"
    ↓
auth0.loginWithRedirect() OR auth0.loginWithPopup()
    ↓
Browser navigates to Auth0 Universal Login (redirect)
  OR popup window opens Auth0 Universal Login (popup)
    ↓ (user authenticates)
Auth0 redirects back to app URL with authorization code
    ↓
auth0.onLoad() exchanges code for tokens (PKCE)
    ↓
Credentials returned (accessToken, idToken, refreshToken, user)
    ↓
Tokens cached in-memory by Auth0 SPA JS (auto-refresh on expiry)
```

---

## Redirect Login & Logout

### Basic Redirect Login

```dart
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

final auth0 = Auth0Web(
  'YOUR_AUTH0_DOMAIN',
  'YOUR_AUTH0_CLIENT_ID',
);

// Redirect to Auth0 Universal Login
Future<void> login() async {
  await auth0.loginWithRedirect(
    scopes: {'openid', 'profile', 'email', 'offline_access'},
  );
}
```

### Handling the Redirect Callback

After login, Auth0 redirects back to your app with a code in the URL. Call `onLoad()` on app startup to exchange it for tokens:

```dart
// Call once on app startup (e.g., in initState or app initialization)
Future<Credentials?> handleAuthRedirect() async {
  final credentials = await auth0.onLoad();
  // Returns Credentials if user just logged in or has a cached session
  // Returns null if no session exists
  return credentials;
}
```

### Logout

```dart
Future<void> logout() async {
  await auth0.logout(returnToUrl: Uri.base.origin);
  // User is redirected to Auth0 logout endpoint, then back to returnToUrl
}
```

### Custom Redirect URL

```dart
// Redirect to a specific page after login
await auth0.loginWithRedirect(
  redirectUrl: '${Uri.base.origin}/callback',
  scopes: {'openid', 'profile', 'email', 'offline_access'},
);
```

### Sign Up (Direct to Registration Screen)

```dart
await auth0.loginWithRedirect(
  scopes: {'openid', 'profile', 'email', 'offline_access'},
  parameters: {'screen_hint': 'signup'},
);
```

### Custom Audience (API Access Token)

```dart
// Request an access token for your API
await auth0.loginWithRedirect(
  audience: 'https://your-api.example.com',
  scopes: {'openid', 'profile', 'email', 'offline_access', 'read:data'},
);
```

---

## Popup Login

### Basic Popup Login

```dart
// Opens Auth0 login in a popup window — no full-page redirect
Future<void> loginWithPopup() async {
  final credentials = await auth0.loginWithPopup(
    scopes: {'openid', 'profile', 'email', 'offline_access'},
  );
  // credentials are immediately available — no onLoad() needed
}
```

### Popup with Audience

```dart
final credentials = await auth0.loginWithPopup(
  audience: 'https://your-api.example.com',
  scopes: {'openid', 'profile', 'email', 'offline_access', 'read:data'},
);
```

### Popup with Timeout

```dart
final credentials = await auth0.loginWithPopup(
  scopes: {'openid', 'profile', 'email', 'offline_access'},
  timeoutInSeconds: 60,
);
```

> **Important:** `loginWithPopup()` must be called directly from a user interaction (e.g., button tap). Calling it from `initState()` or a timer will cause the browser to block the popup.

---

## Credential Management

Auth0 SPA JS handles credential caching automatically. Use these methods to check and retrieve credentials.

### Check Authentication State

```dart
// Quick check — uses in-memory cache
Future<bool> isLoggedIn() async {
  return await auth0.hasValidCredentials();
}
```

### Retrieve Credentials (Auto-Refreshes)

```dart
Future<Credentials> getCredentials() async {
  // Returns cached credentials if valid
  // Auto-refreshes via iframe or refresh token if within 60s of expiry
  final credentials = await auth0.credentials();
  return credentials;
}
```

### Retrieve with Custom Audience/Scopes

```dart
final credentials = await auth0.credentials(
  audience: 'https://your-api.example.com',
  scopes: {'read:data', 'write:data'},
);
```

### Access User Profile

```dart
final credentials = await auth0.credentials();
final user = credentials.user;
print('Name: ${user.name}');
print('Email: ${user.email}');
print('Picture: ${user.pictureUrl}');
print('Sub: ${user.sub}');
```

---

## Error Handling

### Login Errors

```dart
Future<void> login() async {
  try {
    await auth0.loginWithRedirect(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  } on WebException catch (e) {
    // Auth0-specific web errors
    switch (e.code) {
      case 'login_required':
        // Session expired — redirect to login again
        break;
      case 'consent_required':
        // User must consent to requested scopes
        break;
      case 'access_denied':
        // User denied access or Auth0 rule blocked login
        break;
      default:
        print('Auth error: ${e.code} - ${e.message}');
    }
  } catch (e) {
    print('Unexpected error: $e');
  }
}
```

### Popup Errors

```dart
Future<void> loginPopup() async {
  try {
    final credentials = await auth0.loginWithPopup(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  } on WebException catch (e) {
    if (e.code == 'cancelled') {
      // User closed the popup — no action needed
      return;
    }
    print('Popup login error: ${e.code} - ${e.message}');
  } on TimeoutException {
    // Popup timed out (user didn't complete login)
    print('Login timed out');
  }
}
```

### Credential Retrieval Errors

```dart
Future<void> getToken() async {
  try {
    final credentials = await auth0.credentials();
    callApi(credentials.accessToken);
  } on WebException catch (e) {
    if (e.code == 'login_required') {
      // No valid session — redirect to login
      await auth0.loginWithRedirect();
    } else {
      print('Token error: ${e.code} - ${e.message}');
    }
  }
}
```

---

## Organizations

### Login to a Specific Organization

```dart
await auth0.loginWithRedirect(
  organizationId: 'org_YOUR_ORG_ID',
  scopes: {'openid', 'profile', 'email', 'offline_access'},
);
```

### Accept Organization Invitation

```dart
// Handle invitation URL (e.g., from a link the user clicked)
await auth0.loginWithRedirect(
  invitationUrl: 'https://your-domain.auth0.com/login?invitation=...',
  organizationId: 'org_YOUR_ORG_ID',
);
```

---

## State Management Patterns

### Provider Pattern

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
  String? get accessToken => _credentials?.accessToken;

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

// lib/main.dart
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
```

### Riverpod Pattern

```dart
// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

final auth0Provider = Provider<Auth0Web>((ref) {
  return Auth0Web(
    'YOUR_AUTH0_DOMAIN',
    'YOUR_AUTH0_CLIENT_ID',
  );
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Credentials?>>((ref) {
  return AuthNotifier(ref.read(auth0Provider));
});

class AuthNotifier extends StateNotifier<AsyncValue<Credentials?>> {
  final Auth0Web _auth0;

  AuthNotifier(this._auth0) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final credentials = await _auth0.onLoad();
    state = AsyncValue.data(credentials);
  }

  Future<void> loginWithRedirect() async {
    await _auth0.loginWithRedirect(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  }

  Future<void> loginWithPopup() async {
    final credentials = await _auth0.loginWithPopup(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
    state = AsyncValue.data(credentials);
  }

  Future<void> logout() async {
    await _auth0.logout(returnToUrl: Uri.base.origin);
    state = const AsyncValue.data(null);
  }
}
```

### Bloc Pattern

```dart
// lib/auth/auth_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

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
  final Auth0Web _auth0;

  AuthBloc({required String domain, required String clientId})
      : _auth0 = Auth0Web(domain, clientId),
        super(AuthLoading()) {
    on<AuthInitRequested>(_onInit);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onInit(AuthInitRequested event, Emitter<AuthState> emit) async {
    final credentials = await _auth0.onLoad();
    if (credentials != null) {
      emit(AuthAuthenticated(credentials));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    await _auth0.loginWithRedirect(
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _auth0.logout(returnToUrl: Uri.base.origin);
    emit(AuthUnauthenticated());
  }
}
```

---

## Preserving App State Across Redirects

When using `loginWithRedirect()`, the page reloads. Use `appState` to preserve navigation state:

```dart
// Before redirect — pass current route as appState
await auth0.loginWithRedirect(
  appState: {'returnTo': '/dashboard'},
  scopes: {'openid', 'profile', 'email', 'offline_access'},
);

// After redirect — read appState from onLoad
final credentials = await auth0.onLoad();
if (credentials != null) {
  final returnTo = auth0.appState?['returnTo'] as String? ?? '/';
  navigateTo(returnTo);
}
```

---

## Calling Your API with the Access Token

```dart
import 'package:http/http.dart' as http;

Future<List<Item>> fetchItems() async {
  final credentials = await auth0.credentials(
    audience: 'https://your-api.example.com',
  );

  final response = await http.get(
    Uri.parse('https://your-api.example.com/items'),
    headers: {
      'Authorization': 'Bearer ${credentials.accessToken}',
    },
  );

  if (response.statusCode == 401) {
    // Token rejected — force re-login
    await auth0.loginWithRedirect(
      audience: 'https://your-api.example.com',
    );
    return [];
  }

  return parseItems(response.body);
}
```

---

## Custom Token Exchange (Advanced)

RFC 8693 Token Exchange for exchanging external identity tokens:

```dart
final credentials = await auth0.customTokenExchange(
  audience: 'https://your-api.example.com',
  scopes: {'openid', 'profile'},
  subjectToken: 'external-token-value',
  subjectTokenType: 'urn:ietf:params:oauth:token-type:access_token',
);
```

---

## Multi-Tenant / Environment Configuration

```dart
// Use environment-specific configuration
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

// In main.dart
const config = bool.fromEnvironment('dart.vm.product')
    ? AppConfig.production
    : AppConfig.development;

final auth0 = Auth0Web(config.auth0Domain, config.auth0ClientId);
```
