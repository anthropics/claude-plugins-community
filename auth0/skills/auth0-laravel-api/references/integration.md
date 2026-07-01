# Auth0 Laravel API Integration Patterns

Advanced integration patterns for Laravel API applications using the `AuthorizationGuard`.

---

## Scope-Based Authorization

### Define Permissions in Auth0

1. Go to Auth0 Dashboard -> Applications -> APIs
2. Select your API
3. Click the **Permissions** tab
4. Add permissions (e.g., `read:messages`, `write:messages`, `delete:users`)

### Check Scopes in Routes

```php
Route::middleware('auth:auth0-api')->group(function () {
    Route::get('/messages', function () {
        if (!auth('auth0-api')->hasScope('read:messages')) {
            return response()->json(['error' => 'insufficient_scope'], 403);
        }
        return response()->json(['messages' => []]);
    });

    Route::post('/messages', function () {
        $guard = auth('auth0-api');
        if (!$guard->hasScope('read:messages') || !$guard->hasScope('write:messages')) {
            return response()->json(['error' => 'insufficient_scope'], 403);
        }
        return response()->json(['created' => true]);
    });
});
```

### Scope Middleware Helper

Create a reusable middleware for scope enforcement:

```php
// app/Http/Middleware/CheckScope.php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class CheckScope
{
    public function handle(Request $request, Closure $next, string ...$scopes): mixed
    {
        $guard = auth('auth0-api');

        foreach ($scopes as $scope) {
            if (!$guard->hasScope($scope)) {
                return response()->json([
                    'error' => 'insufficient_scope',
                    'message' => "Missing required scope: $scope",
                ], 403);
            }
        }

        return $next($request);
    }
}
```

Register in `bootstrap/app.php` (Laravel 11+):

```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->alias([
        'scope' => \App\Http\Middleware\CheckScope::class,
    ]);
})
```

Then use on routes:

```php
Route::middleware(['auth:auth0-api', 'scope:read:messages'])->get('/messages', function () {
    return response()->json(['messages' => []]);
});

Route::middleware(['auth:auth0-api', 'scope:read:data,write:data'])->post('/data', function () {
    return response()->json(['created' => true]);
});
```

---

## Permission-Based RBAC

Auth0 can embed RBAC permissions directly in the access token. Enable this in Auth0 Dashboard -> APIs -> Settings -> "Add Permissions in the Access Token".

### Check Permissions

```php
Route::middleware('auth:auth0-api')->group(function () {
    Route::delete('/users/{id}', function (string $id) {
        if (!auth('auth0-api')->hasPermission('delete:users')) {
            return response()->json(['error' => 'insufficient_permissions'], 403);
        }
        return response()->json(['deleted' => $id]);
    });
});
```

### Permission Middleware Helper

```php
// app/Http/Middleware/CheckPermission.php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class CheckPermission
{
    public function handle(Request $request, Closure $next, string ...$permissions): mixed
    {
        $guard = auth('auth0-api');

        foreach ($permissions as $permission) {
            if (!$guard->hasPermission($permission)) {
                return response()->json([
                    'error' => 'insufficient_permissions',
                    'message' => "Missing required permission: $permission",
                ], 403);
            }
        }

        return $next($request);
    }
}
```

Register and use similarly to the scope middleware.

---

## CORS Configuration

When your API receives requests from a browser-based SPA, configure CORS in `config/cors.php` (or `bootstrap/app.php` for Laravel 11+):

```php
// config/cors.php
return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['https://your-spa-domain.com'],
    'allowed_headers' => ['Authorization', 'Content-Type', 'Accept'],
    'exposed_headers' => [],
    'max_age' => 86400,
    'supports_credentials' => false,
];
```

For Laravel 11+ with `bootstrap/app.php`:

```php
->withMiddleware(function (Middleware $middleware) {
    $middleware->api(prepend: [
        \Illuminate\Http\Middleware\HandleCors::class,
    ]);
})
```

---

## Custom User Repository

Override how decoded tokens map to user objects:

```php
// app/Auth/ApiUserRepository.php
namespace App\Auth;

use Auth0\Laravel\UserRepositoryContract;
use Illuminate\Contracts\Auth\Authenticatable;
use Auth0\Laravel\Users\StatelessUser;

class ApiUserRepository implements UserRepositoryContract
{
    public function fromAccessToken(array $user): ?Authenticatable
    {
        // Add custom logic: enrich from database, transform claims, etc.
        return new StatelessUser($user);
    }

    public function fromSession(array $user): ?Authenticatable
    {
        return null; // Not used in API mode
    }
}
```

Register in a service provider:

```php
$this->app->bind(
    \Auth0\Laravel\UserRepositoryContract::class,
    \App\Auth\ApiUserRepository::class
);
```

---

## Error Handling

### Custom 401 Response

Override the unauthenticated handler in `bootstrap/app.php`:

```php
->withExceptions(function (Exceptions $exceptions) {
    $exceptions->render(function (\Illuminate\Auth\AuthenticationException $e, $request) {
        if ($request->expectsJson() || $request->is('api/*')) {
            return response()->json([
                'error' => 'unauthorized',
                'message' => 'Valid access token required',
            ], 401);
        }
    });
})
```

### Structured Error Responses

```php
Route::middleware('auth:auth0-api')->group(function () {
    Route::get('/resource', function () {
        try {
            // business logic
            return response()->json(['data' => []]);
        } catch (\Exception $e) {
            error_log('API error: ' . $e->getMessage());
            return response()->json([
                'error' => 'internal_error',
                'message' => 'An unexpected error occurred',
            ], 500);
        }
    });
});
```

---

## Multi-Guard Setup

Use both web (session) and API (Bearer) guards in the same Laravel app:

```php
// config/auth.php
'guards' => [
    'web' => [
        'driver' => 'auth0.authenticator',
        'provider' => 'auth0-provider',
        'configuration' => 'web',
    ],
    'auth0-api' => [
        'driver' => 'auth0.authorizer',
        'provider' => 'auth0-provider',
        'configuration' => 'api',
    ],
],
```

```php
// routes/web.php - uses session-based auth
Route::middleware('auth')->get('/dashboard', fn() => view('dashboard'));

// routes/api.php - uses Bearer token auth
Route::middleware('auth:auth0-api')->get('/data', fn() => response()->json([...]));
```

---

## Accessing the Credential Entity

For advanced use cases, access the full credential object:

```php
Route::middleware('auth:auth0-api')->get('/token-info', function () {
    $credential = auth('auth0-api')->getCredential();

    if ($credential === null) {
        return response()->json(['error' => 'no_credential'], 401);
    }

    return response()->json([
        'scopes' => $credential->getAccessTokenScope(),
        'expires_at' => $credential->getAccessTokenExpiration(),
        'expired' => $credential->getAccessTokenExpired(),
        'decoded_claims' => $credential->getAccessTokenDecoded(),
    ]);
});
```

---

## Organization Validation

For multi-tenant APIs using Auth0 Organizations, set the `AUTH0_ORGANIZATION` environment variable with a comma-delimited list of allowed organization IDs:

```bash
AUTH0_ORGANIZATION=org_abc123,org_def456
```

The published `config/auth0.php` already maps this using the SDK's helper:

```php
'organization' => \Auth0\Laravel\Configuration::stringToArrayOrNull(env('AUTH0_ORGANIZATION')),
```

The SDK validates the `org_id` claim in the token against the configured allowlist.

---

## Testing

### Feature Tests with Token Mocking

```php
use Tests\TestCase;

class ApiTest extends TestCase
{
    public function test_public_endpoint_returns_200(): void
    {
        $response = $this->getJson('/api/public');
        $response->assertStatus(200);
    }

    public function test_private_endpoint_returns_401_without_token(): void
    {
        $response = $this->getJson('/api/private');
        $response->assertStatus(401);
    }
}
```

### Integration Testing with Real Tokens

```bash
# Get a test token (replace <M2M_CLIENT_ID> with your M2M application's Client ID)
TOKEN=$(auth0 test token <M2M_CLIENT_ID> --audience https://my-api.example.com --no-input 2>/dev/null)

# Test endpoints
curl -s http://localhost:8000/api/private \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

---

## Security Considerations

- **Never hardcode Domain or Audience** - Always use environment variables
- **Always clear config cache after env changes** - `php artisan config:clear`
- **Use HTTPS in production** - Bearer tokens in headers must be encrypted in transit
- **Use minimal scopes** - Only enforce scopes your API actually needs
- **Validate access tokens, not ID tokens** - ID tokens are for the client app
- **Never log or expose token values** - Use `error_log()` for debugging, generic messages for clients

---

## References

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
