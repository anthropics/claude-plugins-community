# Auth0 PHP Integration Patterns

Server-side authentication patterns for PHP web applications.

---

## Protected Routes

### Single Route Protection

```php
<?php
require 'auth0.php';

$credentials = $auth0->getCredentials();
if (null === $credentials) {
    header('Location: /login');
    exit;
}

// User is authenticated - proceed with route logic
$user = $credentials->user;
echo "Welcome, " . htmlspecialchars($user['name']);
```

### Reusable Auth Guard

Create a helper function for route protection:

```php
<?php
// helpers.php

function requireAuth(Auth0\SDK\Auth0 $auth0): object
{
    $credentials = $auth0->getCredentials();
    if (null === $credentials) {
        header('Location: /login');
        exit;
    }
    return $credentials;
}
```

Use it in any route:

```php
<?php
require 'auth0.php';
require 'helpers.php';

$credentials = requireAuth($auth0);
$user = $credentials->user;
```

### Optional Authentication

Check auth status without requiring it:

```php
<?php
require 'auth0.php';

$credentials = $auth0->getCredentials();

if ($credentials) {
    echo "Hello, " . htmlspecialchars($credentials->user['name']) . "! ";
    echo "<a href='/logout'>Logout</a>";
} else {
    echo "Welcome, guest! <a href='/login'>Login</a>";
}
```

---

## Calling External APIs

### Get Access Token for API Calls

Configure an audience to receive an access token for your API:

```php
$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_REGULAR,
    domain: $_ENV['AUTH0_DOMAIN'],
    clientId: $_ENV['AUTH0_CLIENT_ID'],
    clientSecret: $_ENV['AUTH0_CLIENT_SECRET'],
    cookieSecret: $_ENV['AUTH0_COOKIE_SECRET'],
    redirectUri: $_ENV['AUTH0_REDIRECT_URI'],
    audience: [$_ENV['AUTH0_AUDIENCE']],
    scope: ['openid', 'profile', 'email', 'read:data'],
);
```

Then use the access token:

```php
<?php
$credentials = $auth0->getCredentials();
if (null === $credentials) {
    header('Location: /login');
    exit;
}

$accessToken = $credentials->accessToken;

$ch = curl_init('https://your-api.example.com/data');
curl_setopt_array($ch, [
    CURLOPT_HTTPHEADER => ["Authorization: Bearer $accessToken"],
    CURLOPT_RETURNTRANSFER => true,
]);
$response = curl_exec($ch);
$data = json_decode($response, true);
curl_close($ch);
```

### Token Refresh

If the access token is expired, refresh it (requires `offline_access` scope):

```php
$configuration = new SdkConfiguration(
    // ... other config
    scope: ['openid', 'profile', 'email', 'offline_access'],
);

// Later, when making API calls:
$credentials = $auth0->getCredentials();

if (null === $credentials) {
    header('Location: /login');
    exit;
}

if ($credentials->accessTokenExpired) {
    try {
        $auth0->renew();
        $credentials = $auth0->getCredentials();
    } catch (\Exception $e) {
        // Refresh token expired or revoked - re-authenticate
        header('Location: /login');
        exit;
    }
}

$accessToken = $credentials->accessToken;
```

---

## Session Management

### Session Lifecycle

The SDK manages sessions automatically using encrypted cookies:

1. **Login** - Creates encrypted session cookie after `exchange()`
2. **Requests** - `getCredentials()` decrypts and returns session data
3. **Refresh** - `renew()` refreshes tokens without re-authentication
4. **Logout** - `logout()` clears session and redirects to Auth0

### Clear Local Session

Clear the local session without redirecting to Auth0 logout:

```php
$auth0->clear();
header('Location: /');
exit;
```

### Cookie Configuration for Production

```php
$configuration = new SdkConfiguration(
    // ... required params
    cookieSecure: true,        // HTTPS only (required for production)
    cookieSameSite: 'lax',     // Prevent CSRF (default)
    cookieDomain: '.myapp.com', // Share across subdomains
    cookieExpires: 86400,      // 24 hours (0 = session cookie)
    cookiePath: '/',           // Available on all paths
);
```

### Server-Side Sessions (Alternative)

For high-traffic apps or when cookie size is a concern, use PHP's native sessions:

```php
use Auth0\SDK\Store\SessionStore;

$configuration = new SdkConfiguration(
    // ... required params
    sessionStorage: new SessionStore(),
    transientStorage: new SessionStore(),
);
```

**Note:** When using `SessionStore`, you must call `session_start()` before creating the `Auth0` instance. For load-balanced environments, configure a shared session backend (Redis, Memcached).

---

## Custom Login Parameters

### Force Login Prompt

```php
header('Location: ' . $auth0->login(params: ['prompt' => 'login']));
exit;
```

### Signup Instead of Login

```php
header('Location: ' . $auth0->login(params: ['screen_hint' => 'signup']));
exit;
```

### Specify Connection

```php
header('Location: ' . $auth0->login(params: ['connection' => 'google-oauth2']));
exit;
```

### Custom Return URL

```php
header('Location: ' . $auth0->login(redirectUrl: 'http://localhost:3000/dashboard'));
exit;
```

---

## Organization Support

For B2B multi-tenant applications:

```php
$configuration = new SdkConfiguration(
    // ... required params
    organization: ['org_abc123'],
);

// Or prompt for organization at login:
header('Location: ' . $auth0->login(params: ['organization' => 'org_abc123']));
exit;
```

After login, check the organization claim:

```php
$credentials = $auth0->getCredentials();
$orgId = $credentials->user['org_id'] ?? null;
```

---

## Error Handling

### Callback Errors

```php
<?php
// routes/callback.php

if (null !== $auth0->getExchangeParameters()) {
    try {
        $auth0->exchange();
        header('Location: /');
        exit;
    } catch (\Auth0\SDK\Exception\StateException $e) {
        // Invalid state, PKCE error, or expired authorization code
        http_response_code(400);
        echo "Login failed: invalid state. Please try again.";
        echo " <a href='/login'>Retry Login</a>";
        exit;
    } catch (\Auth0\SDK\Exception\NetworkException $e) {
        // Network error calling Auth0
        http_response_code(502);
        echo "Unable to reach authentication server. Please try again.";
        exit;
    } catch (\Exception $e) {
        error_log('Auth0 callback error: ' . $e->getMessage());
        http_response_code(400);
        echo "Authentication failed. Please try again.";
        exit;
    }
}
```

### Token Expiration

```php
$credentials = $auth0->getCredentials();
if ($credentials && $credentials->accessTokenExpired) {
    try {
        $auth0->renew();
    } catch (\Exception $e) {
        $auth0->clear();
        header('Location: /login');
        exit;
    }
}
```

---

## Using with PHP Frameworks (Non-Laravel/Symfony)

### Slim Framework

```php
<?php
use Slim\Factory\AppFactory;

require 'vendor/autoload.php';
require 'auth0.php';

$app = AppFactory::create();

$app->get('/', function ($request, $response) use ($auth0) {
    $credentials = $auth0->getCredentials();
    $body = $credentials
        ? "Hello, " . htmlspecialchars($credentials->user['name'])
        : "<a href='/login'>Login</a>";
    $response->getBody()->write($body);
    return $response;
});

$app->get('/login', function ($request, $response) use ($auth0) {
    return $response->withHeader('Location', $auth0->login())->withStatus(302);
});

$app->get('/callback', function ($request, $response) use ($auth0) {
    if (null !== $auth0->getExchangeParameters()) {
        $auth0->exchange();
    }
    return $response->withHeader('Location', '/')->withStatus(302);
});

$app->get('/logout', function ($request, $response) use ($auth0) {
    return $response->withHeader('Location', $auth0->logout(returnUri: 'http://localhost:3000'))->withStatus(302);
});

$app->run();
```

---

## Security Considerations

- **Keep secrets secure** - Never commit `.env` to version control
- **Use HTTPS in production** - Set `cookieSecure: true`
- **Rotate cookie secret** - Update `AUTH0_COOKIE_SECRET` periodically
- **PKCE is enabled by default** - Do not disable it
- **Validate on server** - Authentication is server-side, tokens are encrypted in cookies
- **Set appropriate cookie expiration** - Use `cookieExpires` for session timeout
- **Always use `htmlspecialchars()`** when outputting user data to prevent XSS

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "No PSR-18 client discovered" | Install `guzzlehttp/guzzle` |
| "Invalid state" on callback | Regenerate `AUTH0_COOKIE_SECRET`; ensure cookies are not blocked |
| Session not persisting across requests | Check that `cookieDomain` and `cookiePath` are correct |
| "Configuration error: cookieSecret required" | Ensure `.env` is loaded before `SdkConfiguration` is created |
| Cookie too large | Switch to `SessionStore` for server-side sessions |
| Token expired errors | Add `offline_access` scope and call `renew()` |

---

## Next Steps

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
