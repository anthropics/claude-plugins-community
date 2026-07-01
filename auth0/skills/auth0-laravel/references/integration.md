# Auth0 Laravel Integration Patterns

Advanced authentication patterns for Laravel web applications.

---

## Route Protection

### Using Middleware

```php
use Illuminate\Support\Facades\Route;

// Single route
Route::get('/dashboard', function () {
    return view('dashboard', ['user' => auth()->user()]);
})->middleware('auth');

// Group of routes
Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'show']);
    Route::get('/settings', [SettingsController::class, 'index']);
});
```

### Controller-Based Protection

```php
namespace App\Http\Controllers;

use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth');
    }

    public function show(Request $request)
    {
        return view('profile', ['user' => $request->user()]);
    }
}
```

### Checking Auth in Blade

```blade
@auth
    <p>Hello, {{ auth()->user()->name }}</p>
    <a href="/logout">Logout</a>
@else
    <a href="/login">Login</a>
@endauth
```

### Optional Authentication

For routes where auth is optional (show different content for logged-in users):

```php
Route::get('/', function () {
    $user = auth()->user();
    return view('home', ['user' => $user]);
});
```

No middleware needed - `auth()->user()` returns `null` if not authenticated.

---

## Scope and Permission Checking

The Auth0 guard provides `hasScope()` and `hasPermission()` methods via the guard instance.

### Check Scopes

```php
Route::get('/admin', function () {
    $guard = auth()->guard('web');

    if (! $guard->hasScope('admin:access')) {
        abort(403, 'Insufficient scope');
    }

    return view('admin.dashboard');
})->middleware('auth');
```

### Check Permissions (RBAC)

```php
Route::get('/users', function () {
    $guard = auth()->guard('web');

    if (! $guard->hasPermission('read:users')) {
        abort(403, 'Missing permission');
    }

    return view('users.index');
})->middleware('auth');
```

### Using Laravel Gates

The SDK registers `scope` and `permission` gates automatically:

```php
use Illuminate\Support\Facades\Gate;

Route::get('/admin', function () {
    if (! Gate::check('scope', 'admin:access')) {
        abort(403);
    }

    return view('admin.dashboard');
})->middleware('auth');
```

In Blade:

```blade
@can('scope', 'admin:access')
    <a href="/admin">Admin Panel</a>
@endcan

@can('permission', 'read:users')
    <a href="/users">Manage Users</a>
@endcan
```

---

## Calling External APIs

### Getting the Access Token

Request an `audience` in your configuration to receive an access token for your API:

Add to `.env`:

```bash
AUTH0_AUDIENCE=https://your-api-identifier
```

Then retrieve the token in your routes:

```php
use Illuminate\Support\Facades\Http;

Route::get('/api-data', function () {
    $guard = auth()->guard('web');
    $credential = $guard->find();

    if (null === $credential) {
        return redirect('/login');
    }

    $accessToken = $credential->getAccessToken();

    if (null === $accessToken) {
        return redirect('/login');
    }

    $response = Http::withToken($accessToken)
        ->get('https://your-api.example.com/data');

    return view('api-data', ['data' => $response->json()]);
})->middleware('auth');
```

### Requesting Additional Scopes

Add scopes in `.env`:

```bash
AUTH0_SCOPE="openid profile email read:messages"
```

Or in `config/auth0.php` under the `web` guard:

```php
'web' => [
    'strategy' => SdkConfiguration::STRATEGY_REGULAR,
    'scope' => ['openid', 'profile', 'email', 'read:messages'],
    // ...
],
```

---

## Events

The SDK dispatches Laravel events during authentication:

| Event | When |
|-------|------|
| `Illuminate\Auth\Events\Login` | User successfully authenticated |
| `Illuminate\Auth\Events\Logout` | User logged out |
| `Auth0\Laravel\Events\TokenRefreshSucceeded` | Access token refreshed via refresh token |
| `Auth0\Laravel\Events\TokenRefreshFailed` | Token refresh attempt failed |
| `Auth0\Laravel\Events\AuthenticationSucceeded` | OAuth callback completed successfully |
| `Auth0\Laravel\Events\AuthenticationFailed` | OAuth callback failed |
| `Auth0\Laravel\Events\LoginAttempting` | Login flow initiated |

### Listening to Events

In `app/Providers/EventServiceProvider.php` or using closures:

```php
use Auth0\Laravel\Events\AuthenticationSucceeded;
use Illuminate\Support\Facades\Event;

Event::listen(AuthenticationSucceeded::class, function ($event) {
    logger()->info('User authenticated', [
        'user' => $event->user?->getAuthIdentifier(),
    ]);
});
```

---

## Custom User Model

By default, the SDK uses `StatefulUser` which implements `Authenticatable`. To use your own Eloquent model:

### 1. Create a Custom User Repository

```php
namespace App\Auth;

use Auth0\Laravel\Users\UserRepositoryAbstract;
use Auth0\Laravel\Users\StatefulUserContract;
use Illuminate\Contracts\Auth\Authenticatable;
use App\Models\User;

class Auth0UserRepository extends UserRepositoryAbstract
{
    public function fromSession(array $user): ?Authenticatable
    {
        return User::firstOrCreate(
            ['auth0_id' => $user['sub']],
            [
                'name' => $user['name'] ?? '',
                'email' => $user['email'] ?? '',
                'avatar' => $user['picture'] ?? '',
            ]
        );
    }

    public function fromAccessToken(array $user): ?Authenticatable
    {
        return User::where('auth0_id', $user['sub'])->first();
    }
}
```

### 2. Register the Repository

In `AppServiceProvider`:

```php
use App\Auth\Auth0UserRepository;

public function register(): void
{
    $this->app->bind(
        \Auth0\Laravel\Users\UserRepositoryContract::class,
        Auth0UserRepository::class
    );
}
```

### 3. Update config/auth.php

```php
'providers' => [
    'auth0-provider' => [
        'driver' => 'auth0.provider',
        'repository' => Auth0UserRepository::class,
    ],
],
```

---

## Session Configuration

### Session Lifetime

The Auth0 session follows Laravel's session configuration in `config/session.php`:

```php
'lifetime' => 120,     // minutes
'expire_on_close' => false,
```

### Token Refresh

When the access token expires, the SDK automatically refreshes it using the refresh token (if available). Request `offline_access` scope to get a refresh token:

```bash
AUTH0_SCOPE="openid profile email offline_access"
```

The guard's `refreshSession()` method handles this transparently. Listen to `TokenRefreshSucceeded` or `TokenRefreshFailed` events for logging.

### Session Driver

The SDK stores auth state in Laravel's session. Any session driver works (file, redis, database, etc.). Configure in `config/session.php` or `.env`:

```bash
SESSION_DRIVER=redis
```

---

## Customizing Routes

### Disabling Auto-Registered Routes

In `config/auth0.php`:

```php
'registerAuthenticationRoutes' => false,
```

Then define your own:

```php
use Auth0\Laravel\Controllers\LoginController;
use Auth0\Laravel\Controllers\CallbackController;
use Auth0\Laravel\Controllers\LogoutController;

Route::get('/login', LoginController::class)->name('login');
Route::get('/callback', CallbackController::class)->name('callback');
Route::get('/logout', LogoutController::class)->name('logout');
```

### Changing Route Paths

In `.env`:

```bash
AUTH0_ROUTE_LOGIN=/auth/login
AUTH0_ROUTE_CALLBACK=/auth/callback
AUTH0_ROUTE_LOGOUT=/auth/logout
AUTH0_ROUTE_AFTER_LOGIN=/dashboard
AUTH0_ROUTE_AFTER_LOGOUT=/goodbye
```

---

## Organizations

For B2B multi-tenant apps using Auth0 Organizations:

Add to `.env`:

```bash
AUTH0_ORGANIZATION=org_abc123
```

Or prompt the user to select an organization at login:

```php
Route::get('/login/{org}', function (string $org) {
    return redirect()->to(
        auth()->guard('web')->sdk()->login(
            redirectUrl: config('app.url') . '/callback',
            params: ['organization' => $org]
        )
    );
});
```

---

## Error Handling

### Callback Errors

The auto-registered callback controller handles errors gracefully. If the OAuth exchange fails, the user is redirected to the configured `routes.index` path.

To customize error handling, disable auto-registered routes and create your own callback:

```php
Route::get('/callback', function (Request $request) {
    try {
        $guard = auth()->guard('web');
        $sdk = $guard->sdk();

        $code = $request->query('code');
        $state = $request->query('state');

        if (null === $code || null === $state) {
            error_log('Auth0 callback missing code or state');
            return redirect('/')->with('error', 'Authentication failed');
        }

        $sdk->exchange(code: $code, state: $state);
        $credential = $guard->find();

        if (null === $credential) {
            error_log('Auth0 callback: credential not found after exchange');
            return redirect('/')->with('error', 'Authentication failed');
        }

        $guard->login($credential);
        $request->session()->regenerate();

        return redirect()->intended('/');
    } catch (\Throwable $e) {
        error_log('Auth0 callback error: ' . $e->getMessage());
        return redirect('/')->with('error', 'Authentication failed');
    }
});
```

---

## Testing

### Impersonation for Tests

The Auth0 guard supports impersonation for testing without hitting Auth0:

```php
use Auth0\Laravel\Users\StatefulUser;

public function test_profile_page_shows_user_info(): void
{
    $user = new StatefulUser(['sub' => 'auth0|test', 'name' => 'Test User', 'email' => 'test@example.com']);

    $this->actingAs($user)
        ->get('/profile')
        ->assertOk()
        ->assertSee('Test User');
}
```

### Guard-Specific Testing

```php
$this->actingAs($user, 'web')
    ->get('/profile')
    ->assertOk();
```
