# Auth0 SPA JS Integration Patterns

---

## Client Initialization

### Using createAuth0Client (Recommended)

`createAuth0Client` initializes the client and automatically calls `checkSession()` to restore any existing session:

```js
import { createAuth0Client } from '@auth0/auth0-spa-js';

const auth0 = await createAuth0Client({
  domain: import.meta.env.VITE_AUTH0_DOMAIN,
  clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
  authorizationParams: {
    redirect_uri: window.location.origin
  }
});
```

### Using Auth0Client Directly

Use when you need more control over initialization order:

```js
import { Auth0Client } from '@auth0/auth0-spa-js';

const auth0 = new Auth0Client({
  domain: import.meta.env.VITE_AUTH0_DOMAIN,
  clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
  authorizationParams: {
    redirect_uri: window.location.origin
  }
});

// Manually check existing session
try {
  await auth0.getTokenSilently();
} catch (error) {
  if (error.error !== 'login_required') {
    throw error;
  }
}
```

---

## Login

### Login with Redirect

```js
// Basic redirect login
await auth0.loginWithRedirect();

// With additional parameters
await auth0.loginWithRedirect({
  authorizationParams: {
    audience: 'https://api.example.com',
    scope: 'openid profile email read:data'
  }
});
```

### Handle Redirect Callback

Call this on page load to process the redirect result after Auth0 returns the user:

```js
const query = new URLSearchParams(window.location.search);
if ((query.has('code') || query.has('error')) && query.has('state')) {
  try {
    const result = await auth0.handleRedirectCallback();
    // result.appState contains data you passed via loginWithRedirect
    console.log('App state:', result.appState);
  } catch (err) {
    console.error('Redirect callback failed:', err);
  }
  // Clean up URL after processing
  window.history.replaceState({}, document.title, window.location.pathname);
}
```

### Login with Popup

Use when you want to avoid a full-page redirect (must be triggered directly by a user click):

```js
document.getElementById('login-popup-btn').addEventListener('click', async () => {
  try {
    await auth0.loginWithPopup();
    const user = await auth0.getUser();
    console.log('Logged in:', user.name);
  } catch (err) {
    if (err.error !== 'popup_cancelled') {
      console.error('Popup login failed:', err);
    }
  }
});
```

---

## Logout

```js
// Logout and return to app origin
auth0.logout({
  logoutParams: {
    returnTo: window.location.origin
  }
});

// Logout without redirect (clear local session only)
auth0.logout({ openUrl: false });

// Logout and redirect to custom URL
auth0.logout({
  logoutParams: {
    returnTo: 'https://your-app.example.com/logged-out'
  }
});
```

---

## User Profile

```js
// Check authentication state
const isAuthenticated = await auth0.isAuthenticated();

// Get user profile (returns undefined if not authenticated)
const user = await auth0.getUser();
if (user) {
  console.log(user.sub);       // Auth0 user ID
  console.log(user.name);      // Full name
  console.log(user.email);     // Email address
  console.log(user.picture);   // Profile picture URL
  console.log(user.email_verified); // Boolean
}
```

---

## Protecting Content

Show/hide content based on authentication state:

```js
async function updateUI() {
  const isAuthenticated = await auth0.isAuthenticated();

  // Toggle login/logout buttons
  document.getElementById('btn-login').style.display = isAuthenticated ? 'none' : 'block';
  document.getElementById('btn-logout').style.display = isAuthenticated ? 'block' : 'none';

  // Show user profile section
  const profileSection = document.getElementById('profile');
  if (profileSection) {
    profileSection.style.display = isAuthenticated ? 'block' : 'none';
  }

  if (isAuthenticated) {
    const user = await auth0.getUser();
    document.getElementById('user-name').textContent = user.name;
    document.getElementById('user-email').textContent = user.email;
    if (document.getElementById('user-picture')) {
      document.getElementById('user-picture').src = user.picture;
    }
  }
}

// Call on page load and after auth state changes
await updateUI();
```

---

## Calling Protected APIs

```js
// Get access token silently (uses cache first, refreshes if expired)
async function callApi(url) {
  const accessToken = await auth0.getTokenSilently();

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (!response.ok) {
    throw new Error(`API error: ${response.status}`);
  }

  return response.json();
}

// Usage
document.getElementById('call-api-btn').addEventListener('click', async () => {
  try {
    const data = await callApi('https://your-api.example.com/private');
    document.getElementById('result').textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    console.error('API call failed:', err);
  }
});
```

### Get Detailed Token Response

```js
const { access_token, token_type, id_token, expires_in } = await auth0.getTokenSilently({
  detailedResponse: true
});
```

### Token for a Specific Audience

```js
const token = await auth0.getTokenSilently({
  authorizationParams: {
    audience: 'https://api.example.com',
    scope: 'read:data write:data'
  }
});
```

---

## Refresh Token Rotation

Enable to maintain sessions across page refreshes without relying on third-party cookies (recommended for modern browsers):

```js
const auth0 = await createAuth0Client({
  domain: import.meta.env.VITE_AUTH0_DOMAIN,
  clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
  useRefreshTokens: true,
  authorizationParams: {
    redirect_uri: window.location.origin,
    scope: 'openid profile email offline_access'  // offline_access required
  }
});
```

> **Note:** Enable **Allow Offline Access** on your Auth0 API in the Dashboard for `offline_access` scope to work.

---

## Organizations

### Login to a Specific Organization

```js
await auth0.loginWithRedirect({
  authorizationParams: {
    organization: 'org_xxxxxxxxxxxx'  // or organization name
  }
});
```

### Initialize Client with Organization

```js
const auth0 = await createAuth0Client({
  domain: import.meta.env.VITE_AUTH0_DOMAIN,
  clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
  authorizationParams: {
    redirect_uri: window.location.origin,
    organization: 'org_xxxxxxxxxxxx'
  }
});
```

### Switch Organizations

```js
async function switchOrganization(orgId) {
  await auth0.logout({ openUrl: false });
  await auth0.loginWithRedirect({
    authorizationParams: { organization: orgId }
  });
}
```

### Accept User Invitations

```js
const url = new URL(window.location.href);
const organization = url.searchParams.get('organization');
const invitation = url.searchParams.get('invitation');

if (organization && invitation) {
  await auth0.loginWithRedirect({
    authorizationParams: { organization, invitation }
  });
}
```

---

## MFA Handling

Handle MFA when `getTokenSilently()` requires a second factor:

```js
import { MfaRequiredError } from '@auth0/auth0-spa-js';

try {
  const token = await auth0.getTokenSilently();
} catch (error) {
  if (error instanceof MfaRequiredError) {
    // Trigger MFA challenge via popup or redirect
    await auth0.loginWithPopup({
      authorizationParams: {
        mfa_token: error.mfa_token
      }
    });
  }
}
```

---

## DPoP (Device-Bound Tokens)

Enable DPoP to bind access tokens to the client's cryptographic key pair:

```js
const auth0 = await createAuth0Client({
  domain: import.meta.env.VITE_AUTH0_DOMAIN,
  clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
  useDpop: true,
  authorizationParams: {
    redirect_uri: window.location.origin
  }
});

// Use createFetcher to automatically handle DPoP proof generation
const fetcher = auth0.createFetcher({ dpopNonceId: 'my_api' });

const response = await fetcher.fetchWithAuth('https://api.example.com/data', {
  method: 'GET'
});
```

---

## Error Handling

```js
import {
  AuthenticationError,
  GenericError,
  TimeoutError,
  PopupTimeoutError,
  PopupCancelledError,
  PopupOpenError,
  MfaRequiredError,
  MissingRefreshTokenError
} from '@auth0/auth0-spa-js';

// Handle redirect callback errors
try {
  await auth0.handleRedirectCallback();
} catch (err) {
  if (err instanceof AuthenticationError) {
    // Auth0 returned an error in the callback (e.g., access_denied)
    console.error('Auth error:', err.error, err.error_description);
  } else {
    console.error('Unexpected error:', err);
  }
}

// Handle token errors
try {
  const token = await auth0.getTokenSilently();
} catch (err) {
  if (err.error === 'login_required') {
    // User needs to log in — redirect to login
    await auth0.loginWithRedirect();
  } else if (err instanceof MissingRefreshTokenError) {
    // Refresh token missing — user needs to re-authenticate
    await auth0.loginWithRedirect();
  } else if (err instanceof TimeoutError) {
    console.error('Request timed out');
  } else {
    console.error('Token error:', err);
  }
}

// Handle popup errors
try {
  await auth0.loginWithPopup();
} catch (err) {
  if (err instanceof PopupOpenError) {
    console.error('Popups are blocked. Please allow popups for this site.');
  } else if (err instanceof PopupCancelledError) {
    console.log('User closed the popup');
  } else if (err instanceof PopupTimeoutError) {
    console.error('Popup timed out');
  }
}
```

---

## Authentication Flow

```
User clicks Login
      ↓
auth0.loginWithRedirect()
      ↓
Browser redirects to Auth0 Universal Login
      ↓
User enters credentials / social login
      ↓
Auth0 redirects back to redirect_uri?code=xxx&state=xxx
      ↓
auth0.handleRedirectCallback() — exchanges code for tokens
      ↓
Tokens stored in memory (or refresh token if useRefreshTokens: true)
      ↓
auth0.isAuthenticated() → true
auth0.getUser() → user profile
auth0.getTokenSilently() → access token
```

---

## Testing Patterns

### Test Authentication State

```js
describe('Auth0 integration', () => {
  it('should show login button when not authenticated', async () => {
    const isAuthenticated = await auth0.isAuthenticated();
    expect(isAuthenticated).toBe(false);
    expect(document.getElementById('btn-login').style.display).toBe('block');
  });
});
```

### Mock Auth0 Client in Tests

```js
// Vitest / Jest
vi.mock('@auth0/auth0-spa-js', () => ({
  createAuth0Client: vi.fn().mockResolvedValue({
    isAuthenticated: vi.fn().mockResolvedValue(true),
    getUser: vi.fn().mockResolvedValue({ name: 'Test User', email: 'test@example.com' }),
    loginWithRedirect: vi.fn(),
    logout: vi.fn(),
    getTokenSilently: vi.fn().mockResolvedValue('mock-access-token'),
    handleRedirectCallback: vi.fn().mockResolvedValue({ appState: null })
  })
}));
```
