# Auth0 PHP API Integration Patterns

Advanced integration patterns for PHP API applications using `auth0/auth0-php` in API mode.

---

## Scope-Based Authorization

### Define Permissions in Auth0

1. Go to Auth0 Dashboard -> Applications -> APIs
2. Select your API
3. Click the **Permissions** tab
4. Add permissions matching the scopes you want to enforce (e.g., `read:messages`, `write:messages`)

### Enforce Scopes in Middleware

```php
function requireAuth(Auth0 $auth0, ?array $requiredScopes = null): array
{
    $token = $auth0->getBearerToken(server: ['HTTP_AUTHORIZATION']);

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
            header('WWW-Authenticate: Bearer error="insufficient_scope"');
            echo json_encode(['error' => 'insufficient_scope', 'message' => 'Token lacks required scopes']);
            exit;
        }
    }

    return $claims;
}
```

### Route Examples

```php
// Requires read:messages scope
case '/api/messages':
    $claims = requireAuth($auth0, ['read:messages']);
    echo json_encode(['messages' => fetchMessages($claims['sub'])]);
    break;

// Requires both read:data and write:data (AND logic)
case '/api/data':
    if ($method === 'POST') {
        $claims = requireAuth($auth0, ['read:data', 'write:data']);
        echo json_encode(['created' => true]);
    }
    break;
```

### Request Tokens with Scopes

Clients must request tokens that include the required scopes:

```bash
curl -X POST https://your-tenant.us.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://my-api.example.com",
    "grant_type": "client_credentials",
    "scope": "read:messages write:messages"
  }'
```

---

## Permission-Based RBAC

Auth0 can embed RBAC permissions directly in the access token (instead of scopes). Enable this in Auth0 Dashboard -> APIs -> Settings -> "Add Permissions in the Access Token".

```php
function requirePermission(Auth0 $auth0, array $requiredPermissions): array
{
    $token = $auth0->getBearerToken(server: ['HTTP_AUTHORIZATION']);

    if ($token === null) {
        http_response_code(401);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'unauthorized', 'message' => 'Missing or invalid Bearer token']);
        exit;
    }

    $claims = $token->toArray();
    $grantedPermissions = $claims['permissions'] ?? [];
    $missingPermissions = array_diff($requiredPermissions, $grantedPermissions);

    if (!empty($missingPermissions)) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'insufficient_permissions', 'message' => 'Missing required permissions']);
        exit;
    }

    return $claims;
}
```

---

## Multi-Audience Validation

If your token may target multiple APIs, configure multiple audiences:

```php
$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_API,
    domain: $_ENV['AUTH0_DOMAIN'],
    audience: [
        $_ENV['AUTH0_AUDIENCE'],
        'https://secondary-api.example.com',
    ],
    tokenCache: new FilesystemAdapter('auth0_jwks', 600, __DIR__ . '/var/cache'),
);
```

The SDK validates that the token's `aud` claim intersects with at least one of the configured audiences (ANY match succeeds).

---

## CORS Configuration

When your API receives requests from a browser-based SPA, CORS headers are required.

### Basic CORS Handler

```php
function handleCors(array $allowedOrigins): void
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';

    if (in_array($origin, $allowedOrigins, true)) {
        header("Access-Control-Allow-Origin: $origin");
        header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
        header('Access-Control-Allow-Headers: Authorization, Content-Type');
        header('Access-Control-Max-Age: 86400');
        header('Vary: Origin');
    }

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }
}
```

Call before any other logic in `index.php`:

```php
require 'cors.php';
handleCors(['https://your-spa.example.com', 'http://localhost:3000']);

require 'auth0.php';
require 'middleware.php';
// ... routes
```

### Production CORS

- Never use `*` for `Access-Control-Allow-Origin` with credentialed requests
- Always validate the `Origin` header against an allowlist
- Include `Vary: Origin` to prevent cache poisoning

---

## Error Handling

### Structured Error Responses

```php
function apiError(int $status, string $error, string $message): never
{
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode(['error' => $error, 'message' => $message]);
    exit;
}
```

### Handling Token Validation Errors

`getBearerToken()` returns `null` when validation fails. For more granular error handling, use `decode()` directly:

```php
use Auth0\SDK\Token;
use Auth0\SDK\Exception\InvalidTokenException;

$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
if (!str_starts_with($authHeader, 'Bearer ')) {
    apiError(401, 'unauthorized', 'Missing Bearer token');
}

$jwt = substr($authHeader, 7);

try {
    $token = $auth0->decode(
        $jwt,
        tokenType: Token::TYPE_ACCESS_TOKEN,
    );
    $claims = $token->toArray();
} catch (InvalidTokenException $e) {
    error_log('Token validation failed: ' . $e->getMessage());
    apiError(401, 'invalid_token', 'Token validation failed');
}
```

### Common Error Codes

| Status | Error Code | Cause |
|--------|------------|-------|
| 401 | `unauthorized` | Missing or malformed Authorization header |
| 401 | `invalid_token` | Expired token, invalid signature, wrong issuer/audience |
| 403 | `insufficient_scope` | Valid token but missing required scopes |
| 403 | `insufficient_permissions` | Valid token but missing required RBAC permissions |

---

## PSR-6 Cache Setup

### Filesystem Cache (Development)

```php
use Symfony\Component\Cache\Adapter\FilesystemAdapter;

$cache = new FilesystemAdapter(
    'auth0_jwks',       // namespace
    600,                // default TTL in seconds
    __DIR__ . '/var/cache'  // cache directory
);
```

### APCu Cache (Production - Single Server)

```php
use Symfony\Component\Cache\Adapter\ApcuAdapter;

$cache = new ApcuAdapter('auth0_jwks', 600);
```

Requires the `apcu` PHP extension.

### Redis Cache (Production - Multi-Server)

```php
use Symfony\Component\Cache\Adapter\RedisAdapter;

$redis = RedisAdapter::createConnection('redis://localhost:6379');
$cache = new RedisAdapter($redis, 'auth0_jwks', 600);
```

### Memcached

```php
use Symfony\Component\Cache\Adapter\MemcachedAdapter;

$memcached = MemcachedAdapter::createConnection('memcached://localhost:11211');
$cache = new MemcachedAdapter($memcached, 'auth0_jwks', 600);
```

### Using the Cache

Pass any PSR-6 `CacheItemPoolInterface` to `SdkConfiguration`:

```php
$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_API,
    domain: $_ENV['AUTH0_DOMAIN'],
    audience: [$_ENV['AUTH0_AUDIENCE']],
    tokenCache: $cache,
    tokenCacheTtl: 600,
);
```

---

## Custom Claims

Access custom claims added via Auth0 Actions:

```php
$claims = requireAuth($auth0);

// Namespaced custom claims (recommended)
$role = $claims['https://example.com/role'] ?? null;
$orgId = $claims['https://example.com/org_id'] ?? null;

// RBAC permissions (if enabled on the API)
$permissions = $claims['permissions'] ?? [];
```

Auth0 Actions add custom claims using namespaced keys to avoid collisions with registered JWT claims.

---

## Organization Validation

For multi-tenant applications using Auth0 Organizations:

```php
$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_API,
    domain: $_ENV['AUTH0_DOMAIN'],
    audience: [$_ENV['AUTH0_AUDIENCE']],
    organization: ['org_abc123', 'org_def456'],
    tokenCache: new FilesystemAdapter('auth0_jwks', 600, __DIR__ . '/var/cache'),
);
```

The SDK validates the `org_id` or `org_name` claim in the token against the configured allowlist.

---

## HS256 Configuration

If your API uses HS256 (symmetric signing) instead of RS256:

```php
$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_API,
    domain: $_ENV['AUTH0_DOMAIN'],
    clientId: $_ENV['AUTH0_CLIENT_ID'],
    clientSecret: $_ENV['AUTH0_CLIENT_SECRET'],
    audience: [$_ENV['AUTH0_AUDIENCE']],
    tokenAlgorithm: 'HS256',
);
```

HS256 uses the client secret as the signing key. No JWKS fetching or caching is needed. However, RS256 is recommended for APIs as it doesn't require sharing secrets.

---

## Testing

### Unit Tests with PHPUnit

```php
use PHPUnit\Framework\TestCase;

class ApiTest extends TestCase
{
    public function testPublicEndpoint(): void
    {
        $response = $this->request('GET', '/api/public');
        $this->assertEquals(200, $response['status']);
    }

    public function testProtectedEndpointWithoutToken(): void
    {
        $response = $this->request('GET', '/api/private');
        $this->assertEquals(401, $response['status']);
    }

    private function request(string $method, string $path, ?string $token = null): array
    {
        // Use PHP's built-in test server or a test framework
        $ch = curl_init("http://localhost:8000$path");
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        if ($token !== null) {
            curl_setopt($ch, CURLOPT_HTTPHEADER, ["Authorization: Bearer $token"]);
        }
        $body = curl_exec($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        return ['status' => $status, 'body' => json_decode($body, true)];
    }
}
```

### Integration Testing with Real Tokens

```bash
# Get a test token via Auth0 CLI
TOKEN=$(auth0 test token --audience https://my-api.example.com --no-input 2>/dev/null)

# Test protected endpoint
curl -s http://localhost:8000/api/private \
  -H "Authorization: Bearer $TOKEN" | jq .
```

---

## Security Considerations

- **Never hardcode Domain or Audience** - Always use environment variables or configuration files
- **Always cache JWKS keys** - Without caching, every request fetches from Auth0's JWKS endpoint
- **Use HTTPS in production** - Bearer tokens are sent in headers and must be encrypted in transit
- **Use minimal scopes** - Only request and enforce scopes your API actually needs
- **Validate access tokens, not ID tokens** - ID tokens are for the client app, access tokens are for API authorization
- **Never echo exception details** - Use `error_log()` and return generic error messages
- **Set short token expiration** - Configure access token lifetime in Auth0 Dashboard -> APIs -> Settings

---

## References

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
