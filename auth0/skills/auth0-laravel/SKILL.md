---
name: auth0-laravel
description: >
  Use when adding session-based login, logout, or user profile to a Laravel web application. Integrates auth0/login (laravel-auth0) with guard-based auth — use even if the user says "add login to my Laravel app".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Laravel Web App Integration

Add login, logout, and user profile to a Laravel web application using `auth0/login` (Laravel Auth0 SDK).

---

## Prerequisites

- Laravel 11+ application
- PHP 8.2+ with extensions: `mbstring`, `openssl`, `json`
- Composer installed
- Auth0 Regular Web Application configured (not an API - must be an Application)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

| Scenario | Use Instead |
|----------|-------------|
| Laravel API with JWT Bearer validation | `auth0-laravel-api` (stateless token guard) |
| Plain PHP (no framework) web app | `auth0-php` |
| Plain PHP API | `auth0-php-api` |
| Single Page Applications | `auth0-react`, `auth0-vue`, or `auth0-angular` |
| Next.js applications | `auth0-nextjs` |
| Node.js web apps | `auth0-express` or `auth0-fastify` |
| Flask web apps | `auth0-flask` |

---

## Quick Start Workflow

### 1. Install SDK

```bash
composer require auth0/login
```

The `auth0/login` package requires `auth0/auth0-php` (v8.19+) and will install it automatically. It also requires a PSR-18 HTTP client - if you don't already have one, install Guzzle:

```bash
composer require guzzlehttp/guzzle guzzlehttp/psr7
```

### 2. Publish Configuration

```bash
php artisan vendor:publish --tag=auth0
```

This creates `config/auth0.php` with guard, middleware, and route configuration.

### 3. Configure Environment

Add to your `.env`:

```bash
APP_URL=http://localhost:8000
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
AUTH0_AUDIENCE=https://your-api-identifier
AUTH0_REDIRECT_URI=${APP_URL}/callback
```

`AUTH0_DOMAIN` is your Auth0 tenant domain (without `https://`). `AUTH0_CLIENT_ID` and `AUTH0_CLIENT_SECRET` come from your Auth0 Application settings. `AUTH0_AUDIENCE` must be set to an API identifier registered in Auth0 (Auth0 Dashboard > Applications > APIs) - without it, Auth0 returns opaque access tokens that the SDK cannot decode, causing a crash on session restore. The SDK uses `APP_KEY` as the cookie secret by default - no separate secret needed.

**Important:** Ensure `APP_URL` includes the port if using the built-in dev server (`http://localhost:8000`). Fresh Laravel installs default to `http://localhost` (no port) which causes callback URL mismatches.

### 4. Configure Auth0 Dashboard

In your Auth0 Application settings:
- **Application Type**: Regular Web Application
- **Allowed Callback URLs**: `http://localhost:8000/callback`
- **Allowed Logout URLs**: `http://localhost:8000`

### 5. Configure Auth Guards

Update `config/auth.php` to use Auth0 guards:

```php
'guards' => [
    'web' => [
        'driver' => 'auth0.authenticator',
        'provider' => 'auth0-provider',
        'configuration' => 'web',
    ],
],

'providers' => [
    'auth0-provider' => [
        'driver' => 'auth0.provider',
        'repository' => 'auth0.repository',
    ],
],
```

The `configuration` key maps to the guard definition in `config/auth0.php` (`web` uses `STRATEGY_REGULAR` with session-based auth). We override the default `web` guard so that Laravel's built-in `auth` middleware and `auth()->user()` work without specifying a guard name. The SDK also auto-registers an `auth0-session` guard with identical config, but overriding `web` is simpler.

### 6. Routes Are Auto-Registered

The SDK automatically registers these routes when `registerAuthenticationRoutes` is `true` in `config/auth0.php`:

- `GET /login` - Redirects to Auth0 Universal Login
- `GET /callback` - Handles OAuth callback, exchanges code for tokens
- `GET /logout` - Destroys session and redirects to Auth0 logout

No manual route definitions needed for the auth flow.

### 7. Add Protected Routes

In `routes/web.php`:

```php
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('home', ['user' => auth()->user()]);
});

Route::middleware('auth')->group(function () {
    Route::get('/profile', function () {
        return view('profile', ['user' => auth()->user()]);
    });
});
```

The standard `auth` middleware works with the Auth0 guard. Unauthenticated users are redirected to `/login`.

### 8. Create Views

Create `resources/views/home.blade.php`:

```blade
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Home</title>
</head>
<body>
    @if($user)
        <h1>Welcome, {{ $user->name }}!</h1>
        <p><a href="/profile">Profile</a></p>
        <p><a href="/logout">Logout</a></p>
    @else
        <h1>Welcome</h1>
        <p><a href="/login">Login</a></p>
    @endif
</body>
</html>
```

Create `resources/views/profile.blade.php`:

```blade
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Profile</title>
</head>
<body>
    <h1>{{ $user->name }}</h1>
    <p>Email: {{ $user->email }}</p>
    <img src="{{ $user->picture }}" alt="avatar" width="100" />
    <hr>
    <h2>User Claims</h2>
    <pre>{{ json_encode($user->jsonSerialize(), JSON_PRETTY_PRINT) }}</pre>
    <p><a href="/">Home</a> | <a href="/logout">Logout</a></p>
</body>
</html>
```

### 9. Test Authentication

```bash
php artisan serve
```

Visit `http://localhost:8000` and click Login.

**Important:** Always access the app via `http://localhost:8000` (not `http://127.0.0.1:8000`). The callback URL uses `localhost`, so the session cookie must be set for `localhost` to persist across the Auth0 login redirect. Using `127.0.0.1` causes an "Invalid state" error because the session cookie won't be sent to the `localhost` callback URL.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `auth0/auth0-php` directly in Laravel | Use `auth0/login` which wraps the SDK with Laravel guards, middleware, and routes |
| App created as SPA type in Auth0 Dashboard | Must be Regular Web Application for server-side session auth |
| Missing callback URL in Auth0 Dashboard | Add `http://localhost:8000/callback` to Allowed Callback URLs |
| Missing logout URL in Auth0 Dashboard | Add `http://localhost:8000` to Allowed Logout URLs |
| Not publishing the config | Run `php artisan vendor:publish --tag=auth0` before configuring |
| Using wrong guard driver name | Driver is `auth0.authenticator` (not `auth0` or `auth0.guard`) |
| Forgetting to set `APP_KEY` | Run `php artisan key:generate` - the SDK uses this as cookie secret |
| Calling `Auth0::getCredentials()` directly | Use Laravel's `auth()->user()` - the SDK integrates via guards |
| Manually defining `/login`, `/callback`, `/logout` routes | Routes are auto-registered by the service provider |
| Setting `AUTH0_DOMAIN` with `https://` prefix | Use bare domain: `tenant.us.auth0.com` not `https://tenant.us.auth0.com` |
| Using `$request->user()` without middleware | Only available in routes with the `auth` middleware applied |
| Missing `AUTH0_AUDIENCE` env var | Without an audience, Auth0 returns opaque tokens the SDK cannot parse - causes "JWT string must contain two dots" crash |
| Visiting `http://127.0.0.1:8000` instead of `http://localhost:8000` | Session cookies set for `127.0.0.1` won't be sent to the `localhost` callback - causes "Invalid state" error |
| Using `$user->getName()` or `$user->getEmail()` | `StatefulUser` uses magic `__get` - use `$user->name`, `$user->email`, `$user->picture` |

---

## Key SDK Methods

| Method | Usage | Purpose |
|--------|-------|---------|
| `auth()->user()` | In routes/controllers | Returns the authenticated `StatefulUser` or `null` |
| `auth()->check()` | In routes/controllers/views | Returns `true` if user is authenticated |
| `auth()->guard('web')` | When using multiple guards | Gets a specific Auth0 guard instance |
| `$user->name` | On user object | User's display name (via `__get` magic) |
| `$user->email` | On user object | User's email (via `__get` magic) |
| `$user->picture` | On user object | User's avatar URL (via `__get` magic) |
| `$user->getAuthIdentifier()` | On user object | Returns the Auth0 `sub` claim |
| `$user->getAttribute('claim')` | On user object | Returns any claim value explicitly |
| `$user->jsonSerialize()` | On user object | Returns all user claims as array |

---

## User Object

The authenticated user is a `StatefulUser` instance implementing Laravel's `Authenticatable` contract. It uses `__get` magic for property-style access to claims:

```php
$user = auth()->user();

$user->name;                   // display name (via __get)
$user->email;                  // email address (via __get)
$user->picture;                // avatar URL (via __get)
$user->email_verified;         // any claim via property access
$user->getAuthIdentifier();   // Auth0 'sub' (e.g. 'auth0|abc123')
$user->getAttribute('sub');    // explicit claim access
$user->jsonSerialize();        // all claims as array
```

Access any ID token claim as a property: `$user->nickname`, `$user->updated_at`, `$user->sub`, etc. For explicit access, use `$user->getAttribute('claim_name')`.

---

## Related Skills

- `auth0-laravel-api` - Protect Laravel API routes with JWT Bearer token validation
- `auth0-php` - Plain PHP web apps without a framework
- `auth0-quickstart` - Initial Auth0 setup
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Guard configuration (`config/auth.php`):**
```php
'guards' => [
    'web' => [
        'driver' => 'auth0.authenticator',
        'provider' => 'auth0-provider',
        'configuration' => 'web',
    ],
],
'providers' => [
    'auth0-provider' => [
        'driver' => 'auth0.provider',
        'repository' => 'auth0.repository',
    ],
],
```

**Route protection:**
```php
Route::middleware('auth')->group(function () {
    Route::get('/dashboard', [DashboardController::class, 'index']);
});
```

**Check auth in Blade:**
```blade
@auth
    <p>Hello, {{ auth()->user()->name }}</p>
@else
    <a href="/login">Login</a>
@endauth
```

**Environment variables:**
- `APP_URL` - Application URL with port (e.g. `http://localhost:8000`)
- `AUTH0_DOMAIN` - Auth0 tenant domain (e.g. `tenant.us.auth0.com`)
- `AUTH0_CLIENT_ID` - Application client ID
- `AUTH0_CLIENT_SECRET` - Application client secret
- `AUTH0_AUDIENCE` - API identifier (required for JWT access tokens)
- `AUTH0_REDIRECT_URI` - Callback URL (defaults to `${APP_URL}/callback`)
- `APP_KEY` - Laravel app key, used as cookie encryption secret

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup scripts, environment configuration, Auth0 CLI usage
- **[Integration Guide](references/integration.md)** - Scope checking, calling APIs, events, custom user models, session management
- **[API Reference](references/api.md)** - Complete guard API, configuration options, user model methods

---

## References

- [Auth0 Laravel Quickstart](https://auth0.com/docs/quickstart/webapp/laravel)
- [SDK GitHub Repository](https://github.com/auth0/laravel-auth0)
- [SDK on Packagist](https://packagist.org/packages/auth0/login)
