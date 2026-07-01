---
name: auth0-laravel-api
description: >
  Use when protecting Laravel API endpoints with JWT Bearer token validation or scope checks. Integrates auth0/login with the AuthorizationGuard for stateless APIs receiving access tokens.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 Laravel API Integration

Protect Laravel API endpoints with JWT access token validation using `auth0/login` and the `AuthorizationGuard`.

---

## Prerequisites

- Laravel 11+ application
- PHP 8.2+ with extensions: `mbstring`, `openssl`, `json`
- Composer installed
- Auth0 API resource configured (not an Application - must be an API)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

| Scenario | Use Instead |
|----------|-------------|
| Laravel web app with login/logout UI | `auth0-laravel` (session-based `AuthenticationGuard`) |
| Plain PHP API (no framework) | `auth0-php-api` |
| Plain PHP web app | `auth0-php` |
| Single Page Applications | `auth0-react`, `auth0-vue`, or `auth0-angular` |
| FastAPI / Python APIs | `auth0-fastapi-api` |
| Express / Node.js APIs | `express-oauth2-jwt-bearer` |
| Issuing tokens | This skill is for *validating* access tokens, not issuing them |

---

## Quick Start Workflow

### 1. Install SDK

```bash
composer require auth0/login
```

The `auth0/login` package requires `auth0/auth0-php` (v8.19+) and installs it automatically. It also requires a PSR-18 HTTP client - if you don't already have one:

```bash
composer require guzzlehttp/guzzle guzzlehttp/psr7
```

### 2. Publish Configuration

```bash
php artisan vendor:publish --tag=auth0
```

This creates `config/auth0.php` with guard, middleware, and route configuration.

### 3. Create Auth0 API

You need an **API** (not Application) in Auth0.

> **STOP - ask the user before proceeding.**
>
> Ask exactly this question and wait for their answer before doing anything else:
>
> > "How would you like to create the Auth0 API resource?
> > 1. **Automated** - I'll run Auth0 CLI scripts that create the resource and write the exact values to your `.env` automatically.
> > 2. **Manual** - You create the API yourself in the Auth0 Dashboard (or via `auth0 apis create`) and provide me the Domain and Audience.
> >
> > Which do you prefer? (1 = Automated / 2 = Manual)"
>
> Do NOT proceed to any setup steps until the user has answered. Do NOT default to manual.

**If the user chose Automated**, follow the [Setup Guide](references/setup.md) for complete CLI scripts. The automated path writes `.env` for you - skip Step 4 below and proceed directly to Step 5.

**If the user chose Manual**, follow the [Setup Guide](references/setup.md) (Manual Setup section) for full instructions. Then continue with Step 4 below.

Quick reference for manual API creation:

```bash
auth0 apis create \
  --name "My Laravel API" \
  --identifier https://my-api.example.com \
  --json
```

Or create manually in Auth0 Dashboard -> Applications -> APIs

### 4. Configure Environment

Add to your `.env`:

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_AUDIENCE=https://your-api.example.com
```

`AUTH0_DOMAIN` is your Auth0 tenant domain (without `https://`). `AUTH0_AUDIENCE` is the API identifier you set when creating the API resource in Auth0.

### 5. Configure Auth Guard

Update `config/auth.php` to add the API guard:

```php
'guards' => [
    'web' => [
        'driver' => 'session',
        'provider' => 'users',
    ],
    'auth0-api' => [
        'driver' => 'auth0.authorizer',
        'provider' => 'auth0-provider',
        'configuration' => 'api',
    ],
],

'providers' => [
    'users' => [
        'driver' => 'eloquent',
        'model' => App\Models\User::class,
    ],
    'auth0-provider' => [
        'driver' => 'auth0.provider',
        'repository' => 'auth0.repository',
    ],
],
```

Key points:
- `driver` must be `auth0.authorizer` (not `auth0.authenticator` which is for web apps)
- `configuration` must be `'api'` which maps to the `api` guard in `config/auth0.php`
- The SDK auto-registers an `auth0-api` guard with this config, but defining it explicitly is clearer

### 6. Verify Auth0 Config

After publishing, verify that `config/auth0.php` contains a `guards.api` key with `strategy` set to `SdkConfiguration::STRATEGY_API` (value: `'api'`). This is already present in the published config — no manual editing needed.

The published file uses class constants for keys (e.g., `Configuration::CONFIG_STRATEGY`), which resolve to the same string values at runtime:

```php
'guards' => [
    'api' => [
        'strategy' => SdkConfiguration::STRATEGY_API,  // value: 'api'
    ],
],
```

The published config also includes `default` and `web` guard sections — these can be ignored for API-only usage. The `STRATEGY_API` strategy disables all session/cookie machinery and enables stateless Bearer token validation.

### 7. Add Protected API Routes

Laravel 11+ does not include `routes/api.php` by default. If the file does not exist, scaffold it:

```bash
php artisan install:api
```

This creates `routes/api.php` and registers it in `bootstrap/app.php` with the `/api` prefix. It also installs Laravel Sanctum, which is unused but harmless alongside Auth0.

In `routes/api.php`:

```php
use Illuminate\Support\Facades\Route;

Route::get('/public', function () {
    return response()->json(['message' => 'Public endpoint - no authentication required']);
});

Route::middleware('auth:auth0-api')->group(function () {
    Route::get('/private', function () {
        $user = auth('auth0-api')->user();
        return response()->json([
            'message' => 'Private endpoint',
            'sub' => $user->getAuthIdentifier(),
        ]);
    });
});
```

The `auth:auth0-api` middleware validates the Bearer token, verifies the signature against the JWKS endpoint, and checks issuer and audience claims. Requests without a valid token receive a 401 response.

### 8. Scope and Permission Checks

Use the guard's `hasScope()` and `hasPermission()` methods:

```php
Route::middleware('auth:auth0-api')->group(function () {
    Route::get('/messages', function () {
        $guard = auth('auth0-api');

        if (!$guard->hasScope('read:messages')) {
            return response()->json(['error' => 'insufficient_scope'], 403);
        }

        return response()->json(['messages' => []]);
    });

    Route::delete('/users/{id}', function (string $id) {
        $guard = auth('auth0-api');

        if (!$guard->hasPermission('delete:users')) {
            return response()->json(['error' => 'insufficient_permissions'], 403);
        }

        return response()->json(['deleted' => $id]);
    });
});
```

- `hasScope()` checks the `scope` claim (space-separated string in the JWT)
- `hasPermission()` checks the `permissions` claim (array, requires RBAC enabled on the API in Auth0 Dashboard)

### 9. Access Token Claims

The authenticated user is a `StatelessUser` instance with dynamic claim access:

```php
Route::middleware('auth:auth0-api')->get('/profile', function () {
    $user = auth('auth0-api')->user();

    return response()->json([
        'sub' => $user->getAuthIdentifier(),
        'email' => $user->email,
        'permissions' => $user->permissions ?? [],
        'all_claims' => $user->jsonSerialize(),
    ]);
});
```

Claims are accessed via:
- `$user->getAuthIdentifier()` - Returns `sub` claim
- `$user->claim_name` - Dynamic property access via `__get`
- `$user->getAttribute('claim_name')` - Explicit access
- `$user->jsonSerialize()` - All claims as array

### 10. Test the API

> **Agent instruction:** Start the Laravel dev server and verify the basic endpoints work without credentials:
> ```bash
> php artisan serve &
> sleep 2
> curl -s -H "Accept: application/json" http://localhost:8000/api/public
> curl -s -o /dev/null -w "%{http_code}" -H "Accept: application/json" http://localhost:8000/api/private
> ```
> - `/api/public` should return `{"message":"Public endpoint - no authentication required"}`
> - `/api/private` should return HTTP 401
>
> **Important:** The `-H "Accept: application/json"` header is required. Without it, Laravel's `Authenticate` middleware returns a 302 redirect instead of 401.
>
> If both pass, the guard is working. Kill the background server when done:
> ```bash
> kill %1 2>/dev/null
> ```
>
> **Failcheck:** If the server fails to start or responses are unexpected, check that `config/auth0.php` exists and `.env` has `AUTH0_DOMAIN` and `AUTH0_AUDIENCE` set. After 5-6 failed iterations, use `AskUserQuestion`.

> **Agent instruction: STOP - ask after basic tests pass.**
>
> Once public/401 tests pass, ask the user:
>
> > "Your API is set up and the guard is working (public returns 200, private returns 401 without a token). Would you like me to help you set up testing with a real access token?
> > 1. **Yes** - I'll help you configure an M2M application to get test tokens.
> > 2. **No** - I'm done for now.
> >
> > Which do you prefer?"
>
> Do NOT proceed with M2M/token setup unless the user says yes.

> **Agent instruction (M2M app setup - only if user wants testing):**
>
> If the user chose to set up testing, ask:
>
> > "To test your protected endpoints, you need a Machine-to-Machine (M2M) application authorized to request tokens for this API.
> > 1. **Create new** - I'll create a new M2M application and authorize it for this API.
> > 2. **Use existing** - You already have an M2M application. Provide the Client ID and I'll authorize it for this API.
> >
> > Which do you prefer? (1 = Create new / 2 = Use existing)"
>
> Do NOT proceed until the user answers.
>
> **If the user chose "Create new":**
> ```bash
> auth0 apps create \
>   --name "${PWD##*/} (Test App)" \
>   --type m2m \
>   --no-input --json
> ```
> Parse JSON with `jq` to extract `client_id`. Do NOT use `--reveal-secrets`.
> Then create a client grant:
> ```bash
> auth0 api post "client-grants" --data '{
>   "client_id": "<CLIENT_ID>",
>   "audience": "<API_IDENTIFIER>",
>   "scope": ["<SCOPES>"]
> }'
> ```
>
> **If the user chose "Use existing":**
> Ask for Client ID. Create a client grant (409 conflict = already authorized, fine).

> **Agent instruction (TOKEN ISOLATION - CRITICAL):**
>
> The agent MUST NEVER directly see or display access token values.
> - Do NOT run `auth0 test token` on its own
> - Do NOT ask the user to paste their token
> - Do NOT echo or store the token value
>
> **Secure testing (single-command chain):**
> ```bash
> php artisan serve &
> sleep 2
> TEST_TOKEN=$(auth0 test token <M2M_CLIENT_ID> --audience <AUDIENCE> --scopes <SCOPE1,SCOPE2> 2>/dev/null | grep -o 'ey[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*') && \
> [ -n "$TEST_TOKEN" ] && echo "Token acquired (${#TEST_TOKEN} chars)" && \
> curl -s -H "Accept: application/json" -H "Authorization: Bearer $TEST_TOKEN" http://localhost:8000/api/private
> kill %1 2>/dev/null
> ```
>
> **If the user does NOT ask to test**, provide commands for them to run manually:
> ```bash
> auth0 test token <CLIENT_ID> --audience <AUDIENCE> --scopes <SCOPE1,SCOPE2>
> curl -H "Accept: application/json" -H "Authorization: Bearer <PASTE_TOKEN_HERE>" http://localhost:8000/api/private
> ```

Start the server:

```bash
php artisan serve
```

Test public endpoint (no token needed):

```bash
curl -H "Accept: application/json" http://localhost:8000/api/public
```

Test protected endpoint without token (should return 401):

```bash
curl -H "Accept: application/json" http://localhost:8000/api/private
```

Note: The `Accept: application/json` header is required. Without it, Laravel redirects (302) instead of returning 401.

Test protected endpoint with token:

```bash
curl http://localhost:8000/api/private \
  -H "Accept: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Get a test token via Auth0 Dashboard -> APIs -> Test tab, or via the M2M flow described above.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `auth0.authenticator` driver for API routes | API guard must use `auth0.authorizer` - `auth0.authenticator` is for session-based web apps |
| Using `auth:web` middleware for API routes | Use `auth:auth0-api` to specify the API guard |
| Created an Application instead of an API in Auth0 | Must create an **API** resource (Dashboard -> Applications -> APIs) |
| Passing `domain` with `https://` prefix | Use bare domain: `tenant.us.auth0.com` not `https://tenant.us.auth0.com` |
| Using `auth0/auth0-php` directly | Use `auth0/login` which wraps the SDK with Laravel guards and middleware |
| Not publishing config | Run `php artisan vendor:publish --tag=auth0` before configuring |
| Missing `AUTH0_AUDIENCE` in `.env` | Required for token validation - without it, tokens can't be verified against the correct audience |
| Using `$request->user()` without guard name | Defaults to the `web` guard - use `auth('auth0-api')->user()` or `$request->user('auth0-api')` |
| Checking `$user->scope` as a string | The `scope` claim in JWTs is space-separated - use `hasScope()` instead of string comparison |
| Calling `hasPermission()` without enabling RBAC | Must enable "Add Permissions in the Access Token" in Auth0 Dashboard -> APIs -> Settings |
| Using ID tokens for API auth | Must use **access tokens** - ID tokens are for the client app |
| Setting `configuration => 'web'` on the API guard | Must be `'api'` which maps to the `STRATEGY_API` config in `config/auth0.php` |
| Testing with `curl` without `Accept: application/json` header | Laravel returns 302 redirect instead of 401 - always send `Accept: application/json` for API requests |
| `hasScope()` returns false for scopes not defined on the API | Scopes must be defined on the API resource in Auth0 Dashboard - requesting a scope in the token request does not grant it unless defined |
| `hasPermission()` returns false with M2M tokens | RBAC permissions are only embedded in tokens from user-based flows (Authorization Code), not client-credentials grants |
| `routes/api.php` missing in Laravel 11+ | Run `php artisan install:api` to scaffold API routing - Laravel 11 does not include it by default |

---

## Key SDK Methods

| Method | Returns | Purpose |
|--------|---------|---------|
| `auth('auth0-api')->user()` | `?StatelessUser` | Returns authenticated user or `null` |
| `auth('auth0-api')->check()` | `bool` | Whether request has a valid token |
| `auth('auth0-api')->hasScope($scope)` | `bool` | Check if token has a specific scope |
| `auth('auth0-api')->hasPermission($perm)` | `bool` | Check if token has a specific RBAC permission |
| `auth('auth0-api')->id()` | `?string` | Returns the `sub` claim directly |
| `$user->getAuthIdentifier()` | `int\|string\|null` | Returns `sub` claim |
| `$user->getAttribute('key')` | `mixed` | Returns any claim value |
| `$user->jsonSerialize()` | `array` | Returns all claims as array |
| `auth('auth0-api')->getCredential()` | `?CredentialEntity` | Full credential with decoded token data |

---

## Related Skills

- `auth0-laravel` - For Laravel web apps with login/logout using session-based auth
- `auth0-php-api` - For plain PHP APIs without Laravel
- `auth0-quickstart` - Initial Auth0 setup
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Guard configuration (`config/auth.php`):**
```php
'guards' => [
    'auth0-api' => [
        'driver' => 'auth0.authorizer',
        'provider' => 'auth0-provider',
        'configuration' => 'api',
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
Route::middleware('auth:auth0-api')->group(function () {
    Route::get('/resource', fn() => response()->json([...]));
});
```

**Scope/permission checks:**
```php
$guard = auth('auth0-api');
$guard->hasScope('read:messages');       // checks scope claim
$guard->hasPermission('delete:users');   // checks permissions claim (RBAC)
```

**User claims:**
```php
$user = auth('auth0-api')->user();
$user->getAuthIdentifier();   // sub
$user->email;                 // any claim via __get
$user->getAttribute('iss');   // explicit claim access
```

**Environment variables:**
- `AUTH0_DOMAIN` - Auth0 tenant domain (e.g. `tenant.us.auth0.com`)
- `AUTH0_AUDIENCE` - API identifier (e.g. `https://api.example.com`)

**Common Use Cases:**
- Protect routes -> `auth:auth0-api` middleware (see Step 7)
- Scope enforcement -> `hasScope()` (see Step 8)
- Permission enforcement -> `hasPermission()` (see Step 8)
- Advanced configuration -> [API Reference](references/api.md)

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Auth0 CLI setup, environment configuration, getting test tokens
- **[Integration Guide](references/integration.md)** - Scopes, permissions, CORS, custom user repositories, error handling, multi-guard
- **[API Reference](references/api.md)** - Complete AuthorizationGuard API, StatelessUser, CredentialEntity, configuration options

---

## References

- [Auth0 Laravel API Quickstart](https://auth0.com/docs/quickstart/backend/laravel)
- [SDK GitHub Repository](https://github.com/auth0/laravel-auth0)
- [SDK on Packagist](https://packagist.org/packages/auth0/login)
- [Access Tokens Guide](https://auth0.com/docs/secure/tokens/access-tokens)
