# Auth0 PHP API - API Reference

Complete reference for `auth0/auth0-php` in API mode (`STRATEGY_API`).

---

## SdkConfiguration

Configuration class for the Auth0 SDK.

```php
use Auth0\SDK\Configuration\SdkConfiguration;
```

### Constructor (API Mode)

```php
$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_API,
    domain: 'your-tenant.us.auth0.com',
    clientId: null,
    clientSecret: null,
    audience: ['https://my-api.example.com'],
    organization: null,
    tokenAlgorithm: 'RS256',
    tokenJwksUri: null,
    tokenLeeway: 60,
    tokenCache: null,
    tokenCacheTtl: 60,
);
```

### Strategy Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `SdkConfiguration::STRATEGY_API` | `'api'` | Stateless JWT validation (no sessions) |
| `SdkConfiguration::STRATEGY_REGULAR` | `'webapp'` | Session-based web app auth |
| `SdkConfiguration::STRATEGY_MANAGEMENT_API` | `'management'` | Management API client |
| `SdkConfiguration::STRATEGY_NONE` | `'none'` | Manual configuration |

### Constructor Parameters (API Mode)

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| `strategy` | `string` | `'webapp'` | Yes | Must be `SdkConfiguration::STRATEGY_API` for stateless mode |
| `domain` | `?string` | `null` | Yes | Auth0 tenant domain (e.g., `my-tenant.us.auth0.com`). No `https://` prefix. |
| `clientId` | `?string` | `null` | No* | Application Client ID. Required for HS256; optional for RS256. |
| `clientSecret` | `?string` | `null` | No* | Client Secret. Required for HS256 signature verification. |
| `audience` | `?array` | `null` | Yes | Array of allowed API identifiers. Token `aud` must intersect. |
| `organization` | `?array` | `null` | No | Array of allowed organization IDs/names for `org_id`/`org_name` validation. |
| `tokenAlgorithm` | `string` | `'RS256'` | No | Signing algorithm: `'RS256'` (asymmetric) or `'HS256'` (symmetric). |
| `tokenJwksUri` | `?string` | `null` | No | JWKS endpoint URI. Auto-set to `https://{domain}/.well-known/jwks.json` if null. |
| `tokenLeeway` | `int` | `60` | No | Clock skew tolerance in seconds for time-based claim validation (`exp`, `iat`, `auth_time`). |
| `tokenCache` | `?CacheItemPoolInterface` | `null` | No | PSR-6 cache adapter for JWKS keys. Strongly recommended for production. |
| `tokenCacheTtl` | `int` | `60` | No | JWKS cache TTL in seconds. |

### Getter Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getAudience()` | `?array` | Configured audience values |
| `getClientId()` | `?string` | Client ID |
| `getClientSecret()` | `?string` | Client Secret |
| `getDomain()` | `?string` | Raw domain string |
| `formatDomain()` | `string` | Domain with `https://` prefix and trailing slash |
| `getTokenAlgorithm()` | `string` | `'RS256'` or `'HS256'` |
| `getTokenJwksUri()` | `?string` | JWKS endpoint URI |
| `getTokenLeeway()` | `int` | Clock skew tolerance |
| `getTokenCache()` | `?CacheItemPoolInterface` | PSR-6 cache instance |
| `getTokenCacheTtl()` | `int` | Cache TTL in seconds |

---

## Auth0

Main SDK class for token operations.

```php
use Auth0\SDK\Auth0;
```

### Constructor

```php
$auth0 = new Auth0($configuration); // accepts SdkConfiguration or array
```

When passing an array, it is forwarded to the `SdkConfiguration` constructor:

```php
$auth0 = new Auth0([
    'strategy' => SdkConfiguration::STRATEGY_API,
    'domain' => $_ENV['AUTH0_DOMAIN'],
    'audience' => [$_ENV['AUTH0_AUDIENCE']],
    'tokenCache' => $cache,
]);
```

### getBearerToken

Extracts, verifies, and validates a Bearer token from the request.

```php
$token = $auth0->getBearerToken(
    ?array $get = null,
    ?array $post = null,
    ?array $server = null,
    ?array $haystack = null,
    ?array $needles = null,
); // returns ?TokenInterface
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `$get` | `?array` | `null` | Array of `$_GET` key names to check for a token (e.g., `['access_token']`) |
| `$post` | `?array` | `null` | Array of `$_POST` key names to check for a token (e.g., `['access_token']`) |
| `$server` | `?array` | `null` | Array of `$_SERVER` key names to check for a Bearer token (e.g., `['HTTP_AUTHORIZATION']`). **Not** `$_SERVER` itself. |
| `$haystack` | `?array` | `null` | Custom array to search for the token |
| `$needles` | `?array` | `null` | Custom keys to search within haystack |

**Important:** The `$server`, `$get`, and `$post` parameters are arrays of KEY NAMES to look up in the respective superglobals, not the superglobals themselves. Pass `['HTTP_AUTHORIZATION']` not `$_SERVER`.

**Token extraction priority:**
1. `Authorization: Bearer <token>` header (from `$_SERVER['HTTP_AUTHORIZATION']` when `server: ['HTTP_AUTHORIZATION']`)
2. Token value from `$_GET` keys listed in `$get`
3. Token value from `$_POST` keys listed in `$post`
4. Custom `$haystack` keys

**Returns:** `TokenInterface` on success (signature verified, claims validated), `null` on failure.

**Typical usage:**
```php
$token = $auth0->getBearerToken(server: ['HTTP_AUTHORIZATION']);
```

### decode

Manually decodes, verifies, and validates a JWT string.

```php
$token = $auth0->decode(
    string $token,
    ?array $tokenAudience = null,
    ?array $tokenOrganization = null,
    ?string $tokenNonce = null,
    ?int $tokenMaxAge = null,
    ?int $tokenLeeway = null,
    ?int $tokenNow = null,
    ?int $tokenType = null,
); // returns TokenInterface
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `$token` | `string` | - | Raw JWT string |
| `$tokenAudience` | `?array` | `null` | Override audience validation (uses config if null) |
| `$tokenOrganization` | `?array` | `null` | Override organization validation |
| `$tokenNonce` | `?string` | `null` | Expected nonce (for ID tokens) |
| `$tokenMaxAge` | `?int` | `null` | Maximum `auth_time` age in seconds |
| `$tokenLeeway` | `?int` | `null` | Override leeway (uses config if null) |
| `$tokenNow` | `?int` | `null` | Override current time for testing |
| `$tokenType` | `?int` | `null` | Token type constant (see Token class) |

**Throws:** `InvalidTokenException` on validation failure.

**Typical usage for APIs:**
```php
use Auth0\SDK\Token;

$token = $auth0->decode($jwtString, tokenType: Token::TYPE_ACCESS_TOKEN);
```

### configuration

Returns the SDK configuration instance.

```php
$config = $auth0->configuration(); // returns SdkConfiguration
```

---

## Token (TokenInterface)

Represents a validated JWT token with typed claim accessors.

```php
use Auth0\SDK\Token;
```

### Type Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `Token::TYPE_ID_TOKEN` | `1` | ID token (contains `nonce`) |
| `Token::TYPE_ACCESS_TOKEN` | `2` | Access token (for API authorization) |
| `Token::TYPE_LOGOUT_TOKEN` | `3` | Back-channel logout token |

### Algorithm Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `Token::ALGO_RS256` | `'RS256'` | RSA-SHA256 (asymmetric, recommended) |
| `Token::ALGO_RS384` | `'RS384'` | RSA-SHA384 |
| `Token::ALGO_RS512` | `'RS512'` | RSA-SHA512 |
| `Token::ALGO_HS256` | `'HS256'` | HMAC-SHA256 (symmetric) |
| `Token::ALGO_HS384` | `'HS384'` | HMAC-SHA384 |
| `Token::ALGO_HS512` | `'HS512'` | HMAC-SHA512 |

### Claim Accessor Methods

| Method | Returns | Claim | Description |
|--------|---------|-------|-------------|
| `getSubject()` | `?string` | `sub` | User or client identifier |
| `getIssuer()` | `?string` | `iss` | Token issuer (Auth0 domain URL) |
| `getAudience()` | `?array` | `aud` | Intended audience(s) |
| `getExpiration()` | `?int` | `exp` | Expiration Unix timestamp |
| `getIssued()` | `?int` | `iat` | Issued-at Unix timestamp |
| `getAuthTime()` | `?int` | `auth_time` | Authentication time |
| `getNonce()` | `?string` | `nonce` | Token nonce (ID tokens) |
| `getOrganization()` | `?string` | `org_id` | Organization identifier |
| `getOrganizationId()` | `?string` | `org_id` | Organization ID |
| `getOrganizationName()` | `?string` | `org_name` | Organization name |
| `getAuthorizedParty()` | `?string` | `azp` | Authorized party |
| `getIdentifier()` | `?string` | `sid` | Session identifier |

### Data Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `toArray()` | `array` | All claims as associative array |
| `toJson()` | `string` | Claims as JSON string |
| `verify()` | `self` | Verify token signature (chainable) |
| `validate()` | `self` | Validate token claims (chainable) |

---

## InvalidTokenException

Thrown when token verification or validation fails.

```php
use Auth0\SDK\Exception\InvalidTokenException;
```

### Common Exception Scenarios

| Method | Message Pattern | Cause |
|--------|----------------|-------|
| `missingAudienceClaim()` | "aud claim missing" | Token has no `aud` claim |
| `mismatchedAudClaim()` | "aud mismatch" | Token `aud` doesn't match configured audience |
| `missingIssClaim()` | "iss claim missing" | Token has no `iss` claim |
| `mismatchedIssClaim()` | "iss mismatch" | Token `iss` doesn't match expected issuer |
| `missingExpClaim()` | "exp claim missing" | Token has no `exp` claim |
| `mismatchedExpClaim()` | "token expired" | Token `exp` is in the past (accounting for leeway) |
| `badSignature()` | "signature invalid" | JWT signature doesn't match |
| `missingKidHeader()` | "kid header missing" | RS256 token missing `kid` header for JWKS lookup |
| `requiresClientSecret()` | "client secret required" | HS256 validation attempted without `clientSecret` |
| `unsupportedSigningAlgorithm()` | "unsupported algorithm" | Token uses an algorithm not in supported list |

### Usage

```php
use Auth0\SDK\Exception\InvalidTokenException;

try {
    $token = $auth0->decode($jwt, tokenType: Token::TYPE_ACCESS_TOKEN);
} catch (InvalidTokenException $e) {
    error_log('Token validation failed: ' . $e->getMessage());
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'invalid_token', 'message' => 'Token validation failed']);
    exit;
}
```

---

## Token Verification Flow

When `getBearerToken()` or `decode()` is called, the SDK performs:

1. **Parse** - Splits JWT into header, payload, signature; base64-decodes each
2. **Verify** (signature) - For RS256: fetches public key from JWKS by `kid` header, verifies RSA signature. For HS256: verifies HMAC using `clientSecret`.
3. **Validate** (claims) - Checks `iss` matches `https://{domain}/`, `aud` intersects configured audience, `exp` is in the future (with leeway)

### JWKS Caching Behavior

- Cache key: Derived from the JWKS URI (`https://{domain}/.well-known/jwks.json`)
- On cache miss: HTTP GET to the JWKS endpoint
- On cache hit: Uses cached keyset directly
- Cache TTL: Controlled by `tokenCacheTtl` (default 60 seconds)
- Keys are stored as the full JWKS response (all keys)
- If the expected `kid` is not in the cached response, the cache is invalidated and JWKS is re-fetched

---

## Full Initialization Example

```php
<?php

require 'vendor/autoload.php';

use Auth0\SDK\Auth0;
use Auth0\SDK\Configuration\SdkConfiguration;
use Symfony\Component\Cache\Adapter\FilesystemAdapter;

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

$cache = new FilesystemAdapter('auth0_jwks', 600, __DIR__ . '/var/cache');

$auth0 = new Auth0(new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_API,
    domain: $_ENV['AUTH0_DOMAIN'],
    audience: [$_ENV['AUTH0_AUDIENCE']],
    tokenAlgorithm: 'RS256',
    tokenCache: $cache,
    tokenCacheTtl: 600,
    tokenLeeway: 60,
));

// Validate Bearer token
$token = $auth0->getBearerToken(server: ['HTTP_AUTHORIZATION']);

if ($token === null) {
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'unauthorized']);
    exit;
}

$claims = $token->toArray();
$userId = $token->getSubject();
```

---

## References

- [auth0/auth0-PHP on GitHub](https://github.com/auth0/auth0-PHP)
- [Integration Guide](integration.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
