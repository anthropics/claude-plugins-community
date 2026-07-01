---
name: auth0-php-api
description: >
  Use when protecting PHP API endpoints with JWT Bearer token validation or scope checks. Integrates auth0/auth0-php in API mode for stateless APIs receiving access tokens.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 PHP API Integration

Protect PHP API endpoints with JWT access token validation using `auth0/auth0-php` in API mode (`STRATEGY_API`).

---

## Prerequisites

- PHP 8.2+ with extensions: `mbstring`, `openssl`, `json`
- Composer installed
- Auth0 API resource configured (not an Application - must be an API)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **PHP web applications with login/logout flows** - Use `auth0-php` for session-based authentication
- **Laravel applications** - Use `auth0/laravel-auth0` which has built-in API guard support
- **Symfony applications** - Use `auth0/symfony` with its security bundle
- **Single Page Applications** - Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Issuing tokens** - This skill is for *validating* access tokens, not issuing them

---

## Quick Start Workflow

### 1. Install SDK

```bash
composer require auth0/auth0-php vlucas/phpdotenv guzzlehttp/guzzle guzzlehttp/psr7 "symfony/cache:^7.0"
```

- `auth0/auth0-php` - The Auth0 SDK (v8.x)
- `vlucas/phpdotenv` - Load `.env` files into `$_ENV`
- `guzzlehttp/guzzle` + `guzzlehttp/psr7` - PSR-18 HTTP client required by the SDK
- `symfony/cache` - PSR-6 cache for JWKS key caching (recommended for production)

### 2. Create Auth0 API

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

**If the user chose Automated**, follow the [Setup Guide](references/setup.md) for complete CLI scripts. The automated path writes `.env` for you - skip Step 3 below and proceed directly to Step 4.

**If the user chose Manual**, follow the [Setup Guide](references/setup.md) (Manual Setup section) for full instructions. Then continue with Step 3 below.

Quick reference for manual API creation:

```bash
# Using Auth0 CLI
auth0 apis create \
  --name "My PHP API" \
  --identifier https://my-api.example.com \
  --json
```

Or create manually in Auth0 Dashboard -> Applications -> APIs

### 3. Configure Environment

Create `.env`:

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_AUDIENCE=https://your-api.example.com
```

`AUTH0_DOMAIN` is your Auth0 tenant domain (without `https://`). `AUTH0_AUDIENCE` is the API identifier you set when creating the API resource in Auth0.

### 4. Initialize Auth0 in API Mode

Create `auth0.php` to initialize the SDK:

```php
<?php

require 'vendor/autoload.php';

use Auth0\SDK\Auth0;
use Auth0\SDK\Configuration\SdkConfiguration;
use Symfony\Component\Cache\Adapter\FilesystemAdapter;

$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_API,
    domain: $_ENV['AUTH0_DOMAIN'],
    clientId: null,
    audience: [$_ENV['AUTH0_AUDIENCE']],
    tokenAlgorithm: 'RS256',
    tokenCache: new FilesystemAdapter('auth0_jwks', 600, __DIR__ . '/var/cache'),
    tokenCacheTtl: 600,
);

$auth0 = new Auth0($configuration);
```

Key differences from web app mode:
- `STRATEGY_API` - stateless, no sessions or cookies
- `clientId` is not required for RS256 validation (only needed for HS256)
- `audience` accepts an array of allowed audience strings
- `tokenCache` is a PSR-6 `CacheItemPoolInterface` for JWKS caching

### 5. Create Middleware Function

Since the SDK does not include a built-in middleware, create a reusable guard function. Create `middleware.php`:

```php
<?php

use Auth0\SDK\Auth0;
use Auth0\SDK\Token;
use Auth0\SDK\Exception\InvalidTokenException;

function requireAuth(Auth0 $auth0, ?array $requiredScopes = null): array
{
    $token = $auth0->getBearerToken(
        server: ['HTTP_AUTHORIZATION']
    );

    if ($token === null) {
        http_response_code(401);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'unauthorized', 'message' => 'Missing or invalid Bearer token']);
        exit;
    }

    $claims = $token->toArray();

    if ($requiredScopes !== null) {
        $grantedScopes = isset($claims['scope']) ? explode(' ', $claims['scope']) : [];
        $missingScopes = array_diff($requiredScopes, $grantedScopes);

        if (!empty($missingScopes)) {
            http_response_code(403);
            header('Content-Type: application/json');
            echo json_encode(['error' => 'insufficient_scope', 'message' => 'Token lacks required scopes']);
            exit;
        }
    }

    return $claims;
}
```

`getBearerToken()` searches for a Bearer token at the locations you specify, verifies the signature against the JWKS endpoint, and validates claims (issuer, audience, expiration). The `server` parameter is an array of `$_SERVER` key names to check (e.g., `['HTTP_AUTHORIZATION']`) - not `$_SERVER` itself. Returns a `TokenInterface` on success or `null` if no valid token is found (does not throw).

### 6. Create API Routes

Create `index.php` as a front controller:

```php
<?php

require 'auth0.php';
require 'middleware.php';

$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

header('Content-Type: application/json');

switch ($path) {
    case '/api/public':
        echo json_encode(['message' => 'Public endpoint - no authentication required']);
        break;

    case '/api/private':
        $claims = requireAuth($auth0);
        echo json_encode(['message' => 'Private endpoint', 'sub' => $claims['sub']]);
        break;

    case '/api/private-scoped':
        $claims = requireAuth($auth0, ['read:messages']);
        echo json_encode(['messages' => [], 'sub' => $claims['sub']]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['error' => 'not_found']);
        break;
}
```

### 7. Access Token Claims

The decoded JWT claims are returned as an associative array:

```php
$claims = requireAuth($auth0);

$userId = $claims['sub'];       // user/client ID
$scopes = $claims['scope'];     // space-separated granted scopes
$issuer = $claims['iss'];       // issuer (your Auth0 domain URL)
$audience = $claims['aud'];     // audience (string or array)
$expiration = $claims['exp'];   // expiration timestamp
```

You can also use the `Token` object's typed accessor methods:

```php
$token = $auth0->getBearerToken(server: ['HTTP_AUTHORIZATION']);
if ($token !== null) {
    $subject = $token->getSubject();     // returns ?string
    $issuer = $token->getIssuer();       // returns ?string
    $audience = $token->getAudience();   // returns ?array
    $expiration = $token->getExpiration(); // returns ?int
}
```

### 8. Add CORS Headers

When your API receives requests from a browser-based SPA, add CORS headers. Create `cors.php`:

```php
<?php

function handleCors(array $allowedOrigins): void
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';

    if (in_array($origin, $allowedOrigins, true)) {
        header("Access-Control-Allow-Origin: $origin");
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        header('Access-Control-Allow-Headers: Authorization, Content-Type');
        header('Access-Control-Max-Age: 86400');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}
```

Then add these lines at the top of `index.php`, before the existing `require 'auth0.php'` line:

```php
require 'cors.php';
handleCors(['https://your-spa-domain.com']);
```

The updated `index.php` head should be:

```php
<?php

require 'cors.php';
handleCors(['https://your-spa-domain.com']);

require 'auth0.php';
require 'middleware.php';

// ... rest of index.php
```

CORS must be handled before auth so that preflight `OPTIONS` requests short-circuit without triggering token validation.

### 9. Test the API

> **Agent instruction:** Start the PHP built-in server and verify the basic endpoints work without credentials:
> ```bash
> php -S localhost:8000 index.php &
> sleep 1
> curl -s http://localhost:8000/api/public
> curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/private
> ```
> - `/api/public` should return `{"message":"Public endpoint - no authentication required"}`
> - `/api/private` should return HTTP 401
>
> If both pass, the middleware is working. Kill the background server when done:
> ```bash
> kill %1 2>/dev/null
> ```
>
> **Failcheck:** If the server fails to start or `/api/public` errors, check for PHP syntax issues or missing `.env`. After 5-6 failed iterations, use `AskUserQuestion` to ask the user for more details about their environment.

> **Agent instruction: STOP - ask after basic tests pass.**
>
> Once public/401 tests pass, ask the user:
>
> > "Your API is set up and the middleware is working (public returns 200, private returns 401 without a token). Would you like me to help you set up testing with a real access token?
> > 1. **Yes** - I'll help you configure an M2M application to get test tokens.
> > 2. **No** - I'm done for now.
> >
> > Which do you prefer?"
>
> Do NOT proceed with M2M/token setup unless the user says yes. If they say no, summarize what was done and stop.

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
> Do NOT proceed until the user answers. Do NOT silently pick an existing application from the tenant.
>
> **If the user chose "Create new":**
> ```bash
> auth0 apps create \
>   --name "${PWD##*/} (Test App)" \
>   --type m2m \
>   --no-input --json
> ```
> Parse the JSON with `jq` to extract `client_id`. Do NOT use `--reveal-secrets` - never expose client secrets in agent context.
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
> Ask for the Client ID. Then create a client grant to authorize it for this API:
> ```bash
> auth0 api post "client-grants" --data '{
>   "client_id": "<USER_PROVIDED_CLIENT_ID>",
>   "audience": "<API_IDENTIFIER>",
>   "scope": ["<SCOPES>"]
> }'
> ```
> If the grant already exists (409 conflict), that's fine - the app is already authorized.

> **Agent instruction (TOKEN ISOLATION - CRITICAL):**
>
> The agent MUST NEVER directly see or display access token values. Token security rules:
> - Do NOT run `auth0 test token` on its own - it outputs the token to stdout
> - Do NOT ask the user to paste their token into the conversation
> - Do NOT echo, print, or log the token value
> - Do NOT store the token in a file
>
> **Secure testing approach (single-command chain):**
>
> If the user explicitly asks to test the protected endpoints, use a single-command chain that captures the token into a shell variable and immediately uses it:
>
> ```bash
> php -S localhost:8000 index.php &
> sleep 1
> TEST_TOKEN=$(auth0 test token <M2M_CLIENT_ID> --audience <AUDIENCE> --scopes <SCOPE1,SCOPE2> 2>/dev/null | grep -o 'ey[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*') && \
> [ -n "$TEST_TOKEN" ] && echo "Token acquired (${#TEST_TOKEN} chars)" && \
> echo "=== GET /api/private ===" && \
> curl -s http://localhost:8000/api/private -H "Authorization: Bearer $TEST_TOKEN" && \
> echo "" && echo "=== GET /api/private-scoped ===" && \
> curl -s http://localhost:8000/api/private-scoped -H "Authorization: Bearer $TEST_TOKEN"
> kill %1 2>/dev/null
> ```
>
> **Rules:**
> 1. ONLY use when the user explicitly asks to test
> 2. Always chain token acquisition + curl in a SINGLE `&&` command
> 3. NEVER add `echo $TEST_TOKEN` or any command that would print the raw token value
> 4. If the token acquisition fails (empty variable), report that the M2M app may not be authorized
> 5. **Client ID is REQUIRED** - if M2M setup was not completed, ask the user first
>
> **If the user does NOT ask to test**, just provide the commands for them to run manually:
> ```
> auth0 test token <CLIENT_ID> --audience <AUDIENCE> --scopes <SCOPE1,SCOPE2>
> curl http://localhost:8000/api/private -H "Authorization: Bearer <PASTE_TOKEN_HERE>"
> ```

Start the server:

```bash
php -S localhost:8000 index.php
```

Test public endpoint (no token needed):

```bash
curl http://localhost:8000/api/public
```

Test protected endpoint without token (should return 401):

```bash
curl http://localhost:8000/api/private
```

Test protected endpoint with token:

```bash
curl http://localhost:8000/api/private \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Test scoped endpoint:

```bash
curl http://localhost:8000/api/private-scoped \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Get a test token via Auth0 Dashboard -> APIs -> Test tab, or via the M2M flow described above.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hardcoding `domain` or `audience` in source | Always read from environment variables - never embed credentials in code |
| Using `STRATEGY_REGULAR` for an API | API mode must use `SdkConfiguration::STRATEGY_API` - it disables sessions and cookies |
| Installing without a PSR-18 HTTP client | Must have `guzzlehttp/guzzle` or another PSR-18 client or the SDK cannot fetch JWKS |
| Not caching JWKS keys | Without a PSR-6 cache, the SDK fetches JWKS on every request - always configure `tokenCache` |
| Passing `audience` as a string | `audience` must be an array: `['https://my-api.example.com']` not `'https://my-api.example.com'` |
| Passing `domain` as full URL with `https://` | `domain` should be the bare domain, e.g. `my-tenant.us.auth0.com`, not `https://my-tenant.us.auth0.com` |
| Using `decode()` without specifying token type | Always pass `tokenType: Token::TYPE_ACCESS_TOKEN` when manually calling `decode()` |
| Echoing exception messages to users | Use `error_log()` for the real error and return a generic JSON error message |
| Using an ID token instead of an access token | Must use the **access token** for API auth - ID tokens are for the client app |
| Created an Application instead of an API in Auth0 | Must create an **API** resource (Applications -> APIs) - an Application doesn't issue access tokens with the right audience |
| Setting `clientId` and expecting RS256 to need it | For RS256, `clientId` is optional - the SDK validates against the JWKS endpoint |
| Using `clientSecret` for RS256 validation | `clientSecret` is only needed for HS256 - RS256 uses the public key from JWKS |
| Passing `$_SERVER` directly to `getBearerToken()` | The `server` param takes an array of key names to look up, e.g. `['HTTP_AUTHORIZATION']` - not `$_SERVER` itself |

---

## Key SDK Methods

| Method | Returns | Purpose |
|--------|---------|---------|
| `getBearerToken` | `?TokenInterface` | Searches specified `$_SERVER` keys for a Bearer token, verifies signature, validates claims. Returns `null` if no token found or validation fails (does not throw). |
| `decode` | `TokenInterface` | Manually decodes and validates a JWT string |
| `configuration` | `SdkConfiguration` | Access the SDK configuration instance |
| `Token::toArray` | `array` | Returns all token claims as an associative array |
| `Token::getSubject` | `?string` | Returns the `sub` claim (user/client ID) |
| `Token::getIssuer` | `?string` | Returns the `iss` claim |
| `Token::getAudience` | `?array` | Returns the `aud` claim |
| `Token::getExpiration` | `?int` | Returns the `exp` claim (Unix timestamp) |

---

## Related Skills

- `auth0-php` - For PHP web apps with login/logout using session-based auth
- `auth0-quickstart` - Basic Auth0 setup and framework detection
- `auth0-cli` - Manage Auth0 resources from the terminal
- `auth0-mfa` - Add Multi-Factor Authentication

---

## Quick Reference

**SdkConfiguration for APIs:**
```php
$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_API,       // required - stateless mode
    domain: $_ENV['AUTH0_DOMAIN'],                   // required
    audience: [$_ENV['AUTH0_AUDIENCE']],             // required - array of identifiers
    tokenAlgorithm: 'RS256',                        // default
    tokenCache: $psrCacheAdapter,                    // recommended for production
    tokenCacheTtl: 600,                             // JWKS cache TTL in seconds
);
```

**Token validation:**
```php
$token = $auth0->getBearerToken(server: ['HTTP_AUTHORIZATION']);  // returns ?TokenInterface
$claims = $token->toArray();                         // all claims as array
$userId = $token->getSubject();                      // sub claim
```

**Manual decode:**
```php
use Auth0\SDK\Token;

$token = $auth0->decode(
    $jwtString,
    tokenType: Token::TYPE_ACCESS_TOKEN,
);
```

**Environment variables:**
- `AUTH0_DOMAIN` - your Auth0 tenant domain (e.g. `tenant.us.auth0.com`)
- `AUTH0_AUDIENCE` - your API identifier (e.g. `https://api.example.com`)

**Common Use Cases:**
- Protect routes -> `requireAuth($auth0)` (see Step 5)
- Scope enforcement -> `requireAuth($auth0, ['read:messages'])` (see Step 5)
- CORS setup -> [Integration Guide](references/integration.md#cors-configuration)
- Multi-audience validation -> [Integration Guide](references/integration.md#multi-audience-validation)
- Advanced configuration -> [API Reference](references/api.md)

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Auth0 CLI setup, environment configuration, getting test tokens
- **[Integration Guide](references/integration.md)** - Scopes, permissions, middleware, multi-audience, CORS, error handling
- **[API Reference](references/api.md)** - Complete SDK API for API mode, configuration options, token methods

---

## References

- [auth0/auth0-php on Packagist](https://packagist.org/packages/auth0/auth0-php)
- [auth0/auth0-PHP on GitHub](https://github.com/auth0/auth0-PHP)
- [Auth0 PHP API Quickstart](https://auth0.com/docs/quickstart/backend/php)
- [PHP Documentation](https://www.php.net/)
- [Access Tokens Guide](https://auth0.com/docs/secure/tokens/access-tokens)
