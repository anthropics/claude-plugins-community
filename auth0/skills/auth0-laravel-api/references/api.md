# Auth0 Laravel API - API Reference

Complete reference for `auth0/login` in API mode using the `AuthorizationGuard`.

---

## AuthorizationGuard

Stateless guard for JWT Bearer token validation. Registered under the driver name `auth0.authorizer`.

**Fully-qualified class:** `Auth0\Laravel\Guards\AuthorizationGuard`

### Access

```php
$guard = auth('auth0-api');
```

### Authentication Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `user()` | `?StatelessUser` | Returns authenticated user or `null` |
| `check()` | `bool` | Whether request has a valid token |
| `guest()` | `bool` | Whether no valid token is present |
| `hasUser()` | `bool` | Whether a user is set |
| `id()` | `?string` | Returns the `sub` claim directly |
| `authenticate()` | `Authenticatable` | Returns user or throws `AuthenticationException` |

### Authorization Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `hasScope(string $scope, ?CredentialEntity $credential = null)` | `bool` | Check if token has a specific scope (from `scope` claim) |
| `hasPermission(string $permission, ?CredentialEntity $credential = null)` | `bool` | Check if token has a specific RBAC permission (from `permissions` claim) |

### Credential Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getCredential()` | `?CredentialEntity` | Returns the full credential entity with decoded token |
| `find()` | `?CredentialEntity` | Searches for credential from the request |
| `findToken()` | `?CredentialEntity` | Gets credential specifically from access token |
| `login(?CredentialEntity $credential)` | `self` | Sets authenticated credential |
| `logout()` | `self` | Clears authentication |
| `setCredential(?CredentialEntity $credential)` | `self` | Sets credential directly |

### Advanced Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `sdk(bool $reset = false)` | `Auth0Interface` | Access the underlying Auth0 PHP SDK instance |
| `management()` | `ManagementInterface` | Access the Auth0 Management API |
| `processToken(string $token)` | `?array` | Decode and validate a JWT string manually |
| `refreshUser()` | `void` | Calls Auth0 `/userinfo` endpoint to refresh user claims. Requires a valid access token with the `openid` scope. In stateless API mode (`STRATEGY_API`), this is rarely needed since each request carries its own token. |

---

## StatelessUser

User model returned by the API guard. Implements Laravel's `Authenticatable` contract.

**Fully-qualified class:** `Auth0\Laravel\Users\StatelessUser`

### Claim Access

| Method | Returns | Description |
|--------|---------|-------------|
| `$user->claim_name` | `mixed` | Dynamic property access via `__get` (e.g., `$user->sub`, `$user->email`) |
| `getAttribute(string $key, mixed $default = null)` | `mixed` | Explicit claim access with optional default |
| `setAttribute(string $key, mixed $value)` | `self` | Set a claim value |
| `getAttributes()` | `array` | Get all claims |
| `fill(array $attributes)` | `self` | Fill with multiple claims |
| `jsonSerialize()` | `array` | All claims as array (for JSON responses) |

### Laravel Authenticatable Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getAuthIdentifier()` | `int\|string\|null` | Returns `sub`, `user_id`, or `email` claim (first found) |
| `getAuthIdentifierName()` | `string` | Returns `'id'` |
| `getAuthPassword()` | `string` | Returns empty string (not applicable for token auth) |
| `getRememberToken()` | `string` | Returns empty string (not applicable) |

### Common Access Token Claims

| Property | Type | Description |
|----------|------|-------------|
| `$user->sub` | `string` | User/client identifier |
| `$user->scope` | `string` | Space-separated scopes (use `hasScope()` for checking) |
| `$user->permissions` | `array` | RBAC permissions (when enabled) |
| `$user->iss` | `string` | Token issuer (Auth0 domain URL) |
| `$user->aud` | `string\|array` | Token audience |
| `$user->exp` | `int` | Expiration timestamp |
| `$user->iat` | `int` | Issued-at timestamp |

---

## CredentialEntity

Wraps the decoded token with accessors for token data.

**Fully-qualified class:** `Auth0\Laravel\Entities\CredentialEntity`

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getAccessToken()` | `?string` | Raw access token JWT string |
| `getAccessTokenDecoded()` | `?array` | All decoded JWT claims |
| `getAccessTokenScope()` | `?array` | Scopes as array |
| `getAccessTokenExpiration()` | `?int` | Unix expiration timestamp |
| `getAccessTokenExpired()` | `?bool` | Whether token is expired |
| `getUser()` | `?Authenticatable` | The `StatelessUser` instance |

---

## Configuration

### config/auth0.php (API Guard Section)

```php
'guards' => [
    'api' => [
        'strategy' => SdkConfiguration::STRATEGY_API,
        // All other values read from .env via AUTH0_* variables
    ],
],
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTH0_DOMAIN` | Yes | Auth0 tenant domain (e.g., `tenant.us.auth0.com`) |
| `AUTH0_AUDIENCE` | Yes | API identifier (e.g., `https://api.example.com`) |
| `AUTH0_CLIENT_ID` | No | Required only for HS256 or Management API |
| `AUTH0_CLIENT_SECRET` | No | Required only for HS256 |

### config/auth.php (Guard Registration)

```php
'guards' => [
    'auth0-api' => [
        'driver' => 'auth0.authorizer',       // MUST be auth0.authorizer for API
        'provider' => 'auth0-provider',
        'configuration' => 'api',             // Maps to guards.api in config/auth0.php
    ],
],

'providers' => [
    'auth0-provider' => [
        'driver' => 'auth0.provider',
        'repository' => 'auth0.repository',
    ],
],
```

### Guard Driver Names

| Driver | Guard Class | Purpose |
|--------|-------------|---------|
| `auth0.authorizer` | `AuthorizationGuard` | Stateless API (JWT Bearer) |
| `auth0.authenticator` | `AuthenticationGuard` | Stateful web app (sessions) |

---

## Middleware

### Built-in Middleware

The SDK auto-registers middleware in the `api` middleware group:
- `Auth0\Laravel\Middleware\AuthorizerMiddleware` - Attempts to authenticate from Bearer token on every API request

### Using Laravel's auth Middleware

```php
// Require valid token
Route::middleware('auth:auth0-api')->get('/resource', ...);

// Multiple guards (first match wins)
Route::middleware('auth:auth0-api,web')->get('/flexible', ...);
```

### Guard Middleware (Per-Route Override)

```php
use Auth0\Laravel\Middleware\GuardMiddleware;

Route::middleware(GuardMiddleware::class)->group(function () {
    Route::get('/resource', ...);
});
```

Register it with a specific guard using Laravel's middleware alias system in `bootstrap/app.php`:

```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->alias([
        'auth0.guard' => \Auth0\Laravel\Middleware\GuardMiddleware::class,
    ]);
})
```

Then use on routes: `Route::middleware('auth0.guard')->group(...)`

---

## Token Validation Flow

When a request hits a route protected by `auth:auth0-api`:

1. **Extract** - Bearer token extracted from `Authorization` header
2. **Decode** - JWT parsed into header, payload, signature
3. **Verify** - RSA signature verified against JWKS endpoint (`https://{domain}/.well-known/jwks.json`)
4. **Validate** - Claims checked: `iss` matches domain, `aud` matches configured audience, `exp` is in the future
5. **Hydrate** - Decoded claims used to create `StatelessUser` via the user repository

JWKS keys are cached according to the SDK's `tokenCacheTtl` setting.

---

## UserRepositoryContract

Interface for customizing how tokens map to user objects.

```php
interface UserRepositoryContract
{
    public function fromAccessToken(array $user): ?Authenticatable;
    public function fromSession(array $user): ?Authenticatable;
}
```

The `fromAccessToken` method receives the decoded JWT claims array and returns a user object (or `null` to reject). Override to enrich users from a database or transform claims.

---

## References

- [Auth0 Laravel SDK on GitHub](https://github.com/auth0/laravel-auth0)
- [Integration Guide](integration.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
