# Auth0 Laravel API Reference

Complete API reference for the Laravel Auth0 SDK (`auth0/login`).

---

## Guard Methods

The Auth0 authentication guard extends Laravel's guard contract. Access via `auth()->guard('web')`.

### Authentication

| Method | Returns | Description |
|--------|---------|-------------|
| `user()` | `?Authenticatable` | Returns the authenticated user or `null` |
| `check()` | `bool` | Returns `true` if user is authenticated |
| `guest()` | `bool` | Returns `true` if user is NOT authenticated |
| `id()` | `?string` | Returns the user's Auth0 `sub` identifier |
| `authenticate()` | `Authenticatable` | Returns user or throws `AuthenticationException` |
| `find()` | `?CredentialEntityContract` | Retrieves credentials from session |
| `login(?CredentialEntityContract $credential)` | `self` | Logs in a user with the given credential |
| `logout()` | `self` | Logs out the current user, clears session |

### Authorization

| Method | Returns | Description |
|--------|---------|-------------|
| `hasScope(string $scope)` | `bool` | Checks if the access token contains the given scope |
| `hasPermission(string $permission)` | `bool` | Checks if the user has the given RBAC permission |

### SDK Access

| Method | Returns | Description |
|--------|---------|-------------|
| `sdk()` | `Auth0` | Returns the underlying `Auth0\SDK\Auth0` instance |

---

## User Object (StatefulUser)

The `StatefulUser` class implements Laravel's `Authenticatable` and `JsonSerializable` interfaces.

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `$user->name` | `?string` | Display name (via `__get` magic) |
| `$user->email` | `?string` | Email address (via `__get` magic) |
| `$user->picture` | `?string` | Avatar URL (via `__get` magic) |
| `getAuthIdentifier()` | `string` | Auth0 user ID (`sub` claim) |
| `getAuthIdentifierName()` | `string` | Returns `'id'` |
| `getAttribute(string $key)` | `mixed` | Returns any claim value explicitly |
| `jsonSerialize()` | `array` | All user claims as associative array |

### Property Access (via `__get`)

`StatefulUser` uses PHP's `__get` magic method for claim access. Any ID token claim is available as a property:

```php
$user = auth()->user();
$user->sub;              // 'auth0|abc123'
$user->email;            // 'user@example.com'
$user->email_verified;   // true
$user->nickname;         // 'user'
$user->updated_at;       // '2024-01-15T10:30:00.000Z'
$user->name;             // 'John Doe'
$user->picture;          // 'https://...'
```

For explicit access: `$user->getAttribute('claim_name')`.

---

## Credential Entity

Returned by `$guard->find()`. Contains tokens and user data.

| Method | Returns | Description |
|--------|---------|-------------|
| `getUser()` | `?Authenticatable` | The authenticated user object |
| `getAccessToken()` | `?string` | Raw access token string |
| `getAccessTokenExpiration()` | `?int` | Token expiration as Unix timestamp |
| `getAccessTokenScope()` | `?array` | Granted scopes as array |
| `getIdToken()` | `?string` | Raw ID token string |
| `getRefreshToken()` | `?string` | Refresh token (if `offline_access` requested) |
| `getAccessTokenExpired()` | `bool` | Whether the access token has expired |

---

## Configuration (config/auth0.php)

### Top-Level Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `registerGuards` | `bool` | `true` | Auto-register `auth0.authenticator` and `auth0.authorizer` drivers |
| `registerMiddleware` | `bool` | `true` | Auto-register Auth0 middleware aliases |
| `registerAuthenticationRoutes` | `bool` | `true` | Auto-register `/login`, `/callback`, `/logout` routes |
| `configurationPath` | `?string` | `null` | Custom path for Auth0 JSON config file |

### Guard: `web` (Session-Based)

| Key | Env Variable | Default | Description |
|-----|-------------|---------|-------------|
| `strategy` | - | `STRATEGY_REGULAR` | Authentication strategy |
| `cookie_secret` | `AUTH0_COOKIE_SECRET` | `APP_KEY` | Encryption key for session data |
| `redirect_uri` | `AUTH0_REDIRECT_URI` | `${APP_URL}/callback` | OAuth callback URL |
| `transient_store_ttl` | `AUTH0_TRANSIENT_STORE_TTL` | `600` | Transaction store TTL in seconds |

### Guard: `default` (Shared Settings)

| Key | Env Variable | Description |
|-----|-------------|-------------|
| `domain` | `AUTH0_DOMAIN` | Auth0 tenant domain |
| `client_id` | `AUTH0_CLIENT_ID` | Application client ID |
| `client_secret` | `AUTH0_CLIENT_SECRET` | Application client secret |
| `audience` | `AUTH0_AUDIENCE` | API identifier for access tokens |
| `scope` | `AUTH0_SCOPE` | OAuth scopes (space-separated) |
| `organization` | `AUTH0_ORGANIZATION` | Organization ID for B2B apps |
| `pkce` | `AUTH0_PKCE` | Enable PKCE (default: `true`) |
| `https` | `AUTH0_HTTPS` | Require HTTPS (default: `true`) |
| `token_cache` | `AUTH0_TOKEN_CACHE` | Cache JWKS (default: `true`) |
| `cache_max_age` | `AUTH0_CACHE_MAX_AGE` | JWKS cache TTL in seconds (default: `60`) |
| `http_max_retries` | `AUTH0_HTTP_MAX_RETRIES` | Max HTTP request retries (default: `3`) |
| `custom_domain` | `AUTH0_CUSTOM_DOMAIN` | Custom domain for Auth0 |
| `backchannel_logout` | `AUTH0_BACKCHANNEL_LOGOUT` | Enable backchannel logout (default: `true`) |

### Routes

| Key | Env Variable | Default | Description |
|-----|-------------|---------|-------------|
| `routes.index` | `AUTH0_ROUTE_INDEX` | `/` | Landing page |
| `routes.login` | `AUTH0_ROUTE_LOGIN` | `/login` | Login route path |
| `routes.callback` | `AUTH0_ROUTE_CALLBACK` | `/callback` | Callback route path |
| `routes.after_login` | `AUTH0_ROUTE_AFTER_LOGIN` | `/` | Redirect after login |
| `routes.logout` | `AUTH0_ROUTE_LOGOUT` | `/logout` | Logout route path |
| `routes.after_logout` | `AUTH0_ROUTE_AFTER_LOGOUT` | `/` | Redirect after logout |

---

## Controllers

Auto-registered controllers handle the OAuth flow. All are invokable (`__invoke`).

### LoginController

- Checks if user is already authenticated
- If authenticated: redirects to `routes.after_login`
- If not: regenerates session, dispatches `LoginAttempting`, redirects to Auth0

### CallbackController

- Extracts `code` and `state` from query parameters
- Calls `$guard->sdk()->exchange(code: $code, state: $state)`
- On success: regenerates session, calls `$guard->login()`, dispatches `AuthenticationSucceeded`, redirects to intended URL or `routes.after_login`
- On failure: dispatches `AuthenticationFailed`, redirects to `routes.index`

### LogoutController

- Checks if user is authenticated
- If authenticated: invalidates session, calls `$guard->logout()`, redirects to Auth0 logout endpoint
- If not authenticated: redirects to `routes.index`

---

## Service Provider Auto-Registration

The `Auth0\Laravel\ServiceProvider` auto-registers:

### Guard Drivers

| Driver | Class | Purpose |
|--------|-------|---------|
| `auth0.authenticator` | `AuthenticationGuard` | Session-based web authentication |
| `auth0.authorizer` | `AuthorizationGuard` | Stateless API token validation |

### User Provider

| Driver | Class | Purpose |
|--------|-------|---------|
| `auth0.provider` | `UserProvider` | Resolves users from Auth0 credentials |

### Middleware Aliases (Deprecated in v7.8.0+)

| Alias | Class | Purpose |
|-------|-------|---------|
| `auth0.authenticate` | `AuthenticateMiddleware` | Require session auth |
| `auth0.authenticate.optional` | `AuthenticateOptionalMiddleware` | Optional session auth |
| `auth0.authorize` | `AuthorizeMiddleware` | Require bearer token |
| `auth0.authorize.optional` | `AuthorizeOptionalMiddleware` | Optional bearer token |

**Note:** Since v7.8.0, use Laravel's standard `auth` middleware instead of the Auth0-specific aliases.

### Gates

| Gate | Check | Usage |
|------|-------|-------|
| `scope` | `$guard->hasScope($scope)` | `Gate::check('scope', 'read:users')` |
| `permission` | `$guard->hasPermission($permission)` | `Gate::check('permission', 'delete:users')` |

---

## Session Bridge

The `SessionBridge` class integrates auth0-php with Laravel's session system.

| Method | Description |
|--------|-------------|
| `set(string $key, $value)` | Stores value in Laravel session under auth0 prefix |
| `get(string $key, $default)` | Retrieves value from session |
| `delete(string $key)` | Removes key from session |
| `purge()` | Clears all auth0 session data |
| `getAll()` | Returns entire auth0 session payload |

Session data is stored as JSON under the `auth0` key in Laravel's session store. The session driver (file, redis, database, etc.) is configured in `config/session.php`.

---

## Events

All events are in the `Auth0\Laravel\Events` namespace:

| Event | Properties | Dispatched When |
|-------|-----------|-----------------|
| `LoginAttempting` | - | Login flow initiated |
| `AuthenticationSucceeded` | `$user` | OAuth callback completed |
| `AuthenticationFailed` | `$throwable` | OAuth callback failed |
| `TokenRefreshSucceeded` | `$credential` | Access token refreshed |
| `TokenRefreshFailed` | `$throwable` | Token refresh failed |

Standard Laravel events (`Illuminate\Auth\Events\Login`, `Illuminate\Auth\Events\Logout`) are also dispatched.

---

## Artisan Commands

The SDK does not provide custom Artisan commands. Use the Auth0 CLI for management tasks:

```bash
auth0 apps list
auth0 apps show <client_id>
auth0 users list
```

See the `auth0-cli` skill for complete CLI reference.
