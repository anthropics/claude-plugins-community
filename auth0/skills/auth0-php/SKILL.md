---
name: auth0-php
description: >
  Use when adding session-based login, logout, or user profile to a PHP web application. Integrates auth0/auth0-php — use even if the user says "add login to my PHP app".
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 PHP Web App Integration

Add login, logout, and user profile to a PHP web application using `auth0/auth0-php`.

---

## Prerequisites

- PHP 8.2+ with extensions: `mbstring`, `openssl`, `json`
- Composer installed
- Auth0 Regular Web Application configured (not an API - must be an Application)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **PHP APIs with JWT Bearer validation** - Use `auth0-php-api` for stateless API token validation
- **Laravel applications** - Use a dedicated Laravel integration with `auth0/laravel-auth0`
- **Symfony applications** - Use a dedicated Symfony integration with `auth0/symfony`
- **Single Page Applications** - Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Next.js applications** - Use `auth0-nextjs` which handles both client and server
- **Node.js web apps** - Use `auth0-express` or `auth0-fastify` for session-based auth

---

## Quick Start Workflow

### 1. Install SDK

```bash
composer require auth0/auth0-php vlucas/phpdotenv guzzlehttp/guzzle guzzlehttp/psr7
```

- `auth0/auth0-php` - The Auth0 SDK
- `vlucas/phpdotenv` - Load `.env` files into `$_ENV`
- `guzzlehttp/guzzle` + `guzzlehttp/psr7` - PSR-18 HTTP client required by the SDK

### 2. Configure Environment

Create `.env`:

```bash
AUTH0_DOMAIN=your-tenant.us.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
AUTH0_COOKIE_SECRET=your_generated_secret
AUTH0_REDIRECT_URI=http://localhost:3000/callback
```

`AUTH0_DOMAIN` is your Auth0 tenant domain (without `https://`). `AUTH0_CLIENT_ID` and `AUTH0_CLIENT_SECRET` come from your Auth0 Application settings. `AUTH0_COOKIE_SECRET` is used for encrypting session cookies - generate with `openssl rand -hex 32`.

### 3. Configure Auth0 Dashboard

In your Auth0 Application settings:
- **Application Type**: Regular Web Application
- **Allowed Callback URLs**: `http://localhost:3000/callback`
- **Allowed Logout URLs**: `http://localhost:3000`

### 4. Create Auth Configuration

Create `auth0.php` to initialize the SDK:

```php
<?php

require 'vendor/autoload.php';

use Auth0\SDK\Auth0;
use Auth0\SDK\Configuration\SdkConfiguration;

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_REGULAR,
    domain: $_ENV['AUTH0_DOMAIN'],
    clientId: $_ENV['AUTH0_CLIENT_ID'],
    clientSecret: $_ENV['AUTH0_CLIENT_SECRET'],
    cookieSecret: $_ENV['AUTH0_COOKIE_SECRET'],
    redirectUri: $_ENV['AUTH0_REDIRECT_URI'],
    scope: ['openid', 'profile', 'email'],
);

$auth0 = new Auth0($configuration);
```

Create one `Auth0` instance and reuse it. Never hardcode credentials - always use environment variables.

**How this works:** The SDK encrypts session data (tokens, user profile) using AES-256-GCM with a key derived from `cookieSecret` via HKDF-SHA256. Session data is stored in an encrypted cookie by default - no server-side database required.

### 5. Create Index Page (Router)

Create `index.php` as a simple front controller. Create the `routes/` directory first:

```php
<?php

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

if ($path === '/style.css') {
    header('Content-Type: text/css');
    readfile(__DIR__ . '/style.css');
    exit;
}

require 'auth0.php';

switch ($path) {
    case '/':
        require 'routes/home.php';
        break;
    case '/login':
        require 'routes/login.php';
        break;
    case '/callback':
        require 'routes/callback.php';
        break;
    case '/profile':
        require 'routes/profile.php';
        break;
    case '/logout':
        require 'routes/logout.php';
        break;
    default:
        http_response_code(404);
        echo 'Not found';
        break;
}
```

The static file handler for `/style.css` is placed before `require 'auth0.php'` so stylesheets load without initializing the SDK.

### 6. Add Stylesheet

Create `style.css`:

```css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #f5f7fa;
    color: #1a1a2e;
    line-height: 1.6;
    min-height: 100vh;
}

.container {
    max-width: 800px;
    margin: 0 auto;
    padding: 40px 20px;
}

.card {
    background: #fff;
    border-radius: 12px;
    padding: 28px;
    margin-bottom: 20px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
    border: 1px solid #e8ecf0;
}

.card.center {
    text-align: center;
    padding: 60px 28px;
}

h1 {
    font-size: 1.5rem;
    font-weight: 600;
    margin-bottom: 4px;
}

h2 {
    font-size: 1.1rem;
    font-weight: 600;
    margin-bottom: 16px;
    color: #444;
}

.subtitle {
    color: #666;
    font-size: 0.95rem;
}

.card.center .subtitle {
    margin: 12px 0 28px;
}

.user-header {
    display: flex;
    align-items: center;
    gap: 16px;
}

.avatar {
    width: 48px;
    height: 48px;
    border-radius: 50%;
    object-fit: cover;
}

.avatar-lg {
    width: 72px;
    height: 72px;
}

.nav-links {
    margin-top: 20px;
    display: flex;
    gap: 12px;
}

.top-nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
}

.btn {
    display: inline-block;
    padding: 10px 20px;
    border-radius: 8px;
    text-decoration: none;
    font-size: 0.9rem;
    font-weight: 500;
    transition: all 0.15s ease;
}

.btn-primary {
    background: #635bff;
    color: #fff;
}

.btn-primary:hover {
    background: #4b44d4;
}

.btn-secondary {
    background: #f0f0f5;
    color: #444;
}

.btn-secondary:hover {
    background: #e4e4ec;
}

.btn-back {
    background: none;
    color: #635bff;
    padding: 10px 0;
}

.btn-back:hover {
    color: #4b44d4;
}

.info-table {
    width: 100%;
    border-collapse: collapse;
}

.info-table tr {
    border-bottom: 1px solid #f0f0f5;
}

.info-table tr:last-child {
    border-bottom: none;
}

.info-table td {
    padding: 10px 0;
    vertical-align: top;
}

.info-table .label {
    font-weight: 500;
    color: #666;
    width: 160px;
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.02em;
}

.info-table .value {
    color: #1a1a2e;
    word-break: break-all;
}

.token-box {
    background: #f8f9fb;
    border: 1px solid #e8ecf0;
    border-radius: 8px;
    padding: 14px;
    font-size: 0.8rem;
    font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
    word-break: break-all;
    white-space: pre-wrap;
    max-height: 120px;
    overflow-y: auto;
    margin-bottom: 16px;
}
```

### 7. Add Home Route

Create `routes/home.php`:

```php
<?php

$credentials = $auth0->getCredentials();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Auth0 PHP App</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <?php if ($credentials): ?>
            <div class="card">
                <div class="user-header">
                    <img src="<?= htmlspecialchars($credentials->user['picture'] ?? '') ?>" alt="avatar" class="avatar" />
                    <div>
                        <h1>Hello, <?= htmlspecialchars($credentials->user['name'] ?? 'User') ?>!</h1>
                        <p class="subtitle"><?= htmlspecialchars($credentials->user['email'] ?? '') ?></p>
                    </div>
                </div>
                <nav class="nav-links">
                    <a href="/profile" class="btn btn-primary">View Profile & Tokens</a>
                    <a href="/logout" class="btn btn-secondary">Logout</a>
                </nav>
            </div>
        <?php else: ?>
            <div class="card center">
                <h1>Auth0 PHP Web App</h1>
                <p class="subtitle">Session-based authentication with Auth0 SDK</p>
                <a href="/login" class="btn btn-primary">Login</a>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>
```

### 8. Add Login Route

Create `routes/login.php`:

```php
<?php

header('Location: ' . $auth0->login());
exit;
```

`login()` returns a URL string pointing to Auth0's Universal Login page. You must redirect the user to it.

### 9. Add Callback Route

Create `routes/callback.php`:

```php
<?php

if (null !== $auth0->getExchangeParameters()) {
    try {
        $auth0->exchange();
        header('Location: /');
        exit;
    } catch (\Exception $e) {
        error_log('Auth0 callback error: ' . $e->getMessage());
        http_response_code(400);
        echo "Authentication failed. Please try again.";
        exit;
    }
}

header('Location: /');
exit;
```

`getExchangeParameters()` checks if the callback contains authorization code parameters. `exchange()` exchanges the code for tokens and establishes the session. Always wrap in try/catch since the token exchange can fail (e.g. expired code, CSRF mismatch).

### 10. Add Profile Route (Protected)

Create `routes/profile.php`:

```php
<?php

$credentials = $auth0->getCredentials();

if (null === $credentials) {
    header('Location: /login');
    exit;
}

$user = $credentials->user;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Profile - Auth0 PHP App</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <nav class="top-nav">
            <a href="/" class="btn btn-back">&larr; Back to Home</a>
            <a href="/logout" class="btn btn-secondary">Logout</a>
        </nav>

        <div class="card">
            <div class="user-header">
                <img src="<?= htmlspecialchars($user['picture'] ?? '') ?>" alt="avatar" class="avatar avatar-lg" />
                <div>
                    <h1><?= htmlspecialchars($user['name'] ?? 'User') ?></h1>
                    <p class="subtitle"><?= htmlspecialchars($user['email'] ?? '') ?></p>
                </div>
            </div>
        </div>

        <div class="card">
            <h2>User Profile Claims</h2>
            <table class="info-table">
                <?php foreach ($user as $key => $value): ?>
                <tr>
                    <td class="label"><?= htmlspecialchars($key) ?></td>
                    <td class="value"><?= htmlspecialchars(is_array($value) ? json_encode($value) : (string)$value) ?></td>
                </tr>
                <?php endforeach; ?>
            </table>
        </div>

        <div class="card">
            <h2>ID Token</h2>
            <pre class="token-box"><?= htmlspecialchars($credentials->idToken ?? 'N/A') ?></pre>
        </div>

        <div class="card">
            <h2>Access Token</h2>
            <pre class="token-box"><?= htmlspecialchars($credentials->accessToken ?? 'N/A') ?></pre>
            <table class="info-table">
                <tr>
                    <td class="label">Expires</td>
                    <td class="value"><?= $credentials->accessTokenExpiration ? date('Y-m-d H:i:s', $credentials->accessTokenExpiration) . ' (' . ($credentials->accessTokenExpired ? 'EXPIRED' : 'valid') . ')' : 'N/A' ?></td>
                </tr>
                <tr>
                    <td class="label">Scopes</td>
                    <td class="value"><?= htmlspecialchars(implode(', ', $credentials->accessTokenScope ?? [])) ?></td>
                </tr>
            </table>
        </div>

        <?php if ($credentials->refreshToken): ?>
        <div class="card">
            <h2>Refresh Token</h2>
            <pre class="token-box"><?= htmlspecialchars($credentials->refreshToken) ?></pre>
        </div>
        <?php endif; ?>
    </div>
</body>
</html>
```

`getCredentials()` returns the user's session data, or `null` if not logged in. The profile page displays all user claims and tokens for verification during development.

### 11. Add Logout Route

Create `routes/logout.php`:

```php
<?php

header('Location: ' . $auth0->logout(returnUri: 'http://localhost:3000'));
exit;
```

`logout()` returns the Auth0 logout URL. Redirect the user to it. The `returnUri` is where Auth0 sends the user after logout - it must be listed in Allowed Logout URLs. In production, replace with your actual domain.

### 12. Test the App

```bash
php -S localhost:3000 index.php
```

Visit `http://localhost:3000/login` to start the login flow.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hardcoding `domain`, `clientId`, or `clientSecret` in source | Always read from environment variables - never embed credentials in code |
| Using an old `auth0-PHP` version < 8.0 | Require PHP 8.2+ and v8.x of the SDK; older versions have different APIs |
| Installing without a PSR-18 HTTP client | Must have a PSR-18 client (e.g. `guzzlehttp/guzzle`) or the SDK cannot make HTTP requests |
| Using `STRATEGY_API` for a web app | Web apps must use `SdkConfiguration::STRATEGY_REGULAR` for session-based auth |
| Passing `domain` as full URL with `https://` | `domain` should be the bare domain, e.g. `my-tenant.us.auth0.com`, not `https://my-tenant.us.auth0.com` |
| Forgetting `cookieSecret` | Required for session encryption - without it, the SDK throws a ConfigurationException |
| Not checking `getExchangeParameters()` before `exchange()` | Calling `exchange()` without parameters causes errors; always check first |
| Not handling errors in callback | `exchange()` can fail - always wrap in try/catch |
| Created app as SPA type in Auth0 | Must be Regular Web Application type for server-side auth |
| Not configuring callback URL in Auth0 Dashboard | Must add `http://localhost:3000/callback` to Allowed Callback URLs |
| Using `$_SESSION` directly | The SDK manages its own encrypted cookie session - do not use `$_SESSION` unless you configure a custom `SessionStore` |
| Deploying without `cookieSecure: true` | Must set to `true` in production - cookies are sent over HTTP otherwise |
| Calling `login()` or `logout()` without redirecting | Both return URL strings, not responses - must use `header('Location: ...')` |
| "Network error resulted in unfulfilled request" on callback | Usually means `AUTH0_CLIENT_SECRET` is wrong, not an actual network issue - verify your credentials in `.env` |

---

## Key SDK Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `login` | `$auth0->login(?string $redirectUrl, ?array $params): string` | Returns authorization URL string - redirect user to it |
| `exchange` | `$auth0->exchange(?string $redirectUri, ?string $code, ?string $state): bool` | Exchanges authorization code for tokens, establishes session |
| `getCredentials` | `$auth0->getCredentials(): ?object` | Returns current session credentials or `null` |
| `getExchangeParameters` | `$auth0->getExchangeParameters(): ?object` | Checks if callback contains exchange parameters |
| `logout` | `$auth0->logout(?string $returnUri, ?array $params): string` | Returns Auth0 logout URL string |
| `renew` | `$auth0->renew(?array $params): self` | Refreshes expired access token (requires `offline_access` scope) |
| `clear` | `$auth0->clear(bool $transient = true): self` | Clears local session without Auth0 logout |

---

## Credentials Object

After successful authentication, `getCredentials()` returns an object with:

```php
$credentials = $auth0->getCredentials();

$credentials->user;                    // array - user profile claims
$credentials->idToken;                 // string - raw ID token
$credentials->accessToken;             // string - access token
$credentials->refreshToken;            // string|null - refresh token (requires offline_access)
$credentials->accessTokenExpiration;   // int - expiration timestamp
$credentials->accessTokenExpired;      // bool - whether token is expired
$credentials->accessTokenScope;        // array - granted scopes
```

**User profile claims** (`$credentials->user`):
- `sub` - unique user identifier
- `name`, `nickname`, `picture`
- `email`, `email_verified`
- `given_name`, `family_name`
- `updated_at`, `locale`

---

## Related Skills

- `auth0-php-api` - For protecting PHP APIs with JWT Bearer token validation
- `auth0-quickstart` - Basic Auth0 setup and framework detection
- `auth0-cli` - Manage Auth0 resources from the terminal
- `auth0-mfa` - Add Multi-Factor Authentication

---

## Quick Reference

**SdkConfiguration for web apps:**
```php
$configuration = new SdkConfiguration(
    strategy: SdkConfiguration::STRATEGY_REGULAR,        // required
    domain: $_ENV['AUTH0_DOMAIN'],                        // required
    clientId: $_ENV['AUTH0_CLIENT_ID'],                   // required
    clientSecret: $_ENV['AUTH0_CLIENT_SECRET'],           // required
    cookieSecret: $_ENV['AUTH0_COOKIE_SECRET'],           // required
    redirectUri: $_ENV['AUTH0_REDIRECT_URI'],             // required
    scope: ['openid', 'profile', 'email'],               // recommended
);
```

**Route protection pattern:**
```php
$credentials = $auth0->getCredentials();
if (null === $credentials) {
    header('Location: /login');
    exit;
}
```

**Environment variables:**
- `AUTH0_DOMAIN` - your Auth0 tenant domain (e.g. `tenant.us.auth0.com`)
- `AUTH0_CLIENT_ID` - your Application's client ID
- `AUTH0_CLIENT_SECRET` - your Application's client secret
- `AUTH0_COOKIE_SECRET` - encryption secret key (generate: `openssl rand -hex 32`)
- `AUTH0_REDIRECT_URI` - callback URL (e.g. `http://localhost:3000/callback`)

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup scripts, environment configuration, Auth0 CLI usage
- **[Integration Guide](references/integration.md)** - Protected routes, calling APIs, session management, error handling
- **[API Reference](references/api.md)** - Complete Auth0 SDK API, configuration options, session storage, security

---

## References

- [auth0/auth0-php on Packagist](https://packagist.org/packages/auth0/auth0-php)
- [auth0/auth0-PHP on GitHub](https://github.com/auth0/auth0-PHP)
- [Auth0 PHP Web App Quickstart](https://auth0.com/docs/quickstart/webapp/php)
- [PHP Documentation](https://www.php.net/)
