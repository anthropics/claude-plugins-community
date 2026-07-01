# Auth0 PHP API Reference

Complete API reference for the `auth0/auth0-php` SDK in web application (stateful) mode.

---

## SdkConfiguration

### Constructor Parameters

```php
use Auth0\SDK\Configuration\SdkConfiguration;

$configuration = new SdkConfiguration(
    // Strategy
    strategy: SdkConfiguration::STRATEGY_REGULAR,  // 'webapp' - required for web apps

    // Required
    domain: 'tenant.us.auth0.com',
    clientId: 'your_client_id',
    clientSecret: 'your_client_secret',
    cookieSecret: 'generated_32_byte_hex',
    redirectUri: 'http://localhost:3000/callback',

    // Scopes
    scope: ['openid', 'profile', 'email'],

    // Cookie settings
    cookieExpires: 0,            // 0 = session cookie; seconds for persistent
    cookieSecure: false,         // true in production (requires HTTPS)
    cookieSameSite: 'lax',       // 'lax', 'strict', or 'none'
    cookieDomain: null,          // auto-detected; set for cross-subdomain
    cookiePath: '/',             // cookie path scope

    // Session storage
    sessionStorage: null,        // null = CookieStore (default)
    transientStorage: null,      // null = CookieStore (default)
    sessionStorageId: 'auth0_session',  // namespace prefix

    // Token settings
    tokenAlgorithm: 'RS256',     // 'RS256' (recommended) or 'HS256'
    tokenMaxAge: null,           // max age in seconds
    tokenLeeway: 60,             // clock skew tolerance in seconds
    tokenCache: null,            // PSR-6 CacheItemPoolInterface

    // Persistence
    persistUser: true,
    persistIdToken: true,
    persistAccessToken: true,
    persistRefreshToken: true,

    // OIDC
    usePkce: true,               // PKCE enabled by default
    responseMode: 'query',       // 'query' or 'form_post'
    responseType: 'code',        // authorization code flow

    // Optional
    audience: [],                // API identifiers
    organization: [],            // organization IDs or names
    queryUserInfo: false,        // query /userinfo endpoint
);
```

### Strategy Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `STRATEGY_REGULAR` | `'webapp'` | Stateful web app with sessions |
| `STRATEGY_API` | `'api'` | Stateless API token validation |
| `STRATEGY_MANAGEMENT_API` | `'management'` | Management API client |
| `STRATEGY_NONE` | `'none'` | No default behavior |

---

## Auth0 Class

### Constructor

```php
use Auth0\SDK\Auth0;

$auth0 = new Auth0($configuration);
```

### Authentication Methods

#### login()

Initiates the login flow. Returns the authorization URL to redirect the user to.

```php
$url = $auth0->login(
    ?string $redirectUrl = null,  // override redirectUri for this request
    ?array $params = null         // additional authorization parameters
); // returns string
```

**Parameters for `$params`:**
- `prompt` - `'login'`, `'none'`, `'consent'`, `'select_account'`
- `screen_hint` - `'signup'` to show registration form
- `connection` - force a specific connection (e.g. `'google-oauth2'`)
- `organization` - organization ID for B2B
- `invitation` - invitation ticket for org invites
- `login_hint` - pre-fill email on login form
- `max_age` - max authentication age in seconds

**Example:**
```php
header('Location: ' . $auth0->login(params: ['prompt' => 'login']));
exit;
```

#### signup()

Shortcut for login with `screen_hint=signup`:

```php
$url = $auth0->signup(
    ?string $redirectUrl = null,
    ?array $params = null
); // returns string
```

#### exchange()

Completes the authentication flow by exchanging the authorization code for tokens.

```php
$success = $auth0->exchange(
    ?string $redirectUri = null,  // override redirectUri
    ?string $code = null,         // authorization code (auto-detected from $_GET)
    ?string $state = null         // state parameter (auto-detected from $_GET)
); // returns bool
```

**Returns:** `true` on success.

**Throws:**
- `StateException` - invalid state, missing code, PKCE error
- `NetworkException` - cannot reach Auth0

#### getExchangeParameters()

Checks whether the current request contains authorization code parameters (code + state).

```php
$params = $auth0->getExchangeParameters();
```

**Returns:** Object with `code` and `state` properties, or `null` if not a callback request.

#### logout()

Clears the local session and returns the Auth0 logout URL.

```php
$url = $auth0->logout(
    ?string $returnUri = null,  // where Auth0 redirects after logout
    ?array $params = null       // additional parameters
); // returns string
```

**Example:**
```php
header('Location: ' . $auth0->logout(returnUri: 'http://localhost:3000'));
exit;
```

#### clear()

Clears the local session without redirecting to Auth0 (no federated logout).

```php
$auth0->clear(bool $transient = true); // returns self
```

#### renew()

Refreshes the access token using the stored refresh token. Requires `offline_access` scope.

```php
$auth0->renew(?array $params = null); // returns self
```

**Throws:** Exception if no refresh token is available or refresh fails.

---

### Session Methods

#### getCredentials()

Returns the current session data, or `null` if not authenticated.

```php
$credentials = $auth0->getCredentials();
```

**Returns object with:**

| Property | Type | Description |
|----------|------|-------------|
| `user` | `array` | User profile claims from ID token |
| `idToken` | `string` | Raw ID token JWT |
| `accessToken` | `string` | Access token |
| `refreshToken` | `string\|null` | Refresh token (if `offline_access` scope) |
| `accessTokenExpiration` | `int` | Unix timestamp when access token expires |
| `accessTokenExpired` | `bool` | Whether the access token has expired |
| `accessTokenScope` | `array` | Array of granted scope strings |

#### isAuthenticated()

Convenience check for whether a session exists.

```php
$isAuth = $auth0->isAuthenticated(); // returns bool
```

#### getUser()

Returns user profile array or null.

```php
$user = $auth0->getUser();
```

#### getAccessToken()

Returns access token string or null.

```php
$token = $auth0->getAccessToken();
```

#### getIdToken()

Returns ID token string or null.

```php
$token = $auth0->getIdToken();
```

#### getRefreshToken()

Returns refresh token string or null.

```php
$token = $auth0->getRefreshToken();
```

---

## User Profile Claims

Standard OpenID Connect claims available in `$credentials->user`:

| Claim | Type | Description |
|-------|------|-------------|
| `sub` | string | Unique user identifier (e.g. `auth0\|abc123`) |
| `name` | string | Full name |
| `nickname` | string | Casual name |
| `picture` | string | Profile picture URL |
| `email` | string | Email address |
| `email_verified` | bool | Whether email is verified |
| `given_name` | string | First name |
| `family_name` | string | Last name |
| `locale` | string | User locale |
| `updated_at` | string | Last profile update (ISO 8601) |
| `org_id` | string | Organization ID (if using organizations) |

---

## Session Storage

### CookieStore (Default)

Stores encrypted session data in HTTP cookies. No server-side state.

- **Encryption:** AES-256-GCM
- **Key derivation:** HKDF-SHA256 from `cookieSecret`
- **Max size:** ~4KB (browser cookie limit)
- **Tradeoff:** Stateless but limited by cookie size

### SessionStore

Uses PHP's native `$_SESSION` for server-side storage.

```php
use Auth0\SDK\Store\SessionStore;

$configuration = new SdkConfiguration(
    // ... required params
    sessionStorage: new SessionStore(),
    transientStorage: new SessionStore(),
);
```

**Requirements:**
- `session_start()` must be called before Auth0 initialization
- Shared session backend (Redis, Memcache) for load-balanced environments

### Custom Store

Implement `Auth0\SDK\Contract\StoreInterface`:

```php
use Auth0\SDK\Contract\StoreInterface;

class RedisStore implements StoreInterface
{
    public function set(string $key, mixed $value): void { /* ... */ }
    public function get(string $key, mixed $default = null): mixed { /* ... */ }
    public function delete(string $key): void { /* ... */ }
    public function purge(): void { /* ... */ }
    public function defer(int $seconds): void { /* ... */ }
}
```

---

## Exception Types

| Exception | When Thrown |
|-----------|------------|
| `Auth0\SDK\Exception\ConfigurationException` | Missing required configuration parameters |
| `Auth0\SDK\Exception\StateException` | Invalid state, missing code, PKCE errors during exchange |
| `Auth0\SDK\Exception\NetworkException` | HTTP request to Auth0 failed |
| `Auth0\SDK\Exception\InvalidTokenException` | Token signature or claims validation failed |
| `Auth0\SDK\Exception\ArgumentException` | Invalid arguments passed to methods |

---

## PSR Compatibility

The SDK uses PSR auto-discovery (`psr-discovery/all`):

| PSR | Purpose | Common Implementation |
|-----|---------|----------------------|
| PSR-18 | HTTP Client | `guzzlehttp/guzzle` |
| PSR-17 | HTTP Factories | `guzzlehttp/psr7` |
| PSR-7 | HTTP Messages | `guzzlehttp/psr7` |
| PSR-6 | Caching (optional) | `symfony/cache` |
| PSR-14 | Events (optional) | `symfony/event-dispatcher` |

---

## Token Validation

The SDK validates tokens automatically during `exchange()`. Claims checked:

- `iss` (issuer) - must match `https://{domain}/`
- `aud` (audience) - must match `clientId` (or configured audience)
- `exp` (expiration) - must not be expired (with `tokenLeeway`)
- `iat` (issued at) - must be reasonable
- `nonce` - must match stored nonce (CSRF protection)
- Signature - verified against JWKS endpoint (`https://{domain}/.well-known/jwks.json`)

JWKS keys are cached using PSR-6 if a `tokenCache` is provided.

---

## Related

- [Setup Guide](setup.md)
- [Integration Guide](integration.md)
- [Main Skill](../SKILL.md)
