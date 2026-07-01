# Auth0 React SDK API Reference

Complete API documentation for @auth0/auth0-react SDK.

---

## Auth0Provider Configuration

### Complete Configuration Options

```tsx
import { Auth0Provider } from '@auth0/auth0-react';

<Auth0Provider
  // Required
  domain="your-tenant.auth0.com"
  clientId="your-client-id"

  // Authorization parameters
  authorizationParams={{
    redirect_uri: window.location.origin,
    audience: 'https://your-api-identifier', // For API calls
    scope: 'openid profile email', // Default scopes
    connection: 'google-oauth2', // Force specific connection
    prompt: 'login', // Force login prompt
    ui_locales: 'en', // Localization
    screen_hint: 'signup', // Show signup page by default
  }}

  // Token management
  cacheLocation="localstorage" // or "memory" for stricter security (default: "memory")
  useRefreshTokens={true} // Enable refresh tokens (default: false)
  useRefreshTokensFallback={false} // Fall back to iframe if refresh token exchange fails (default: false)
  useMrrt={false} // Enable Multi-Refresh-Token for multi-tenant apps (default: false)

  // MFA / Step-up
  interactiveErrorHandler="popup" // Automatically handle MFA via popup (requires useRefreshTokens)

  // Advanced options
  skipRedirectCallback={false} // Skip automatic callback handling
  context={Auth0Context} // Custom React context

  // Callbacks
  onRedirectCallback={(appState) => {
    // Handle redirect after login
    // appState receives the custom state passed to loginWithRedirect()
    // Example: if login was called with appState: { targetUrl: '/dashboard' }
    // then appState.targetUrl will be '/dashboard' here
    window.location.replace(appState?.returnTo || '/');
  }}
>
  <App />
</Auth0Provider>
```

### Configuration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `domain` | string | **Required** | Your Auth0 tenant domain |
| `clientId` | string | **Required** | Your Auth0 application client ID |
| `authorizationParams` | object | `{}` | Authorization parameters (see below) |
| `cacheLocation` | `'memory' \| 'localstorage'` | `'memory'` | Where to store tokens |
| `useRefreshTokens` | boolean | `false` | Enable refresh token rotation |
| `useRefreshTokensFallback` | boolean | `false` | Fall back to iframe if refresh token exchange fails |
| `useMrrt` | boolean | `false` | Enable Multi-Refresh-Token support for multi-tenant apps. Requires `useRefreshTokens` and `useRefreshTokensFallback` to be `true` |
| `workerUrl` | string | - | Custom worker script URL for token calls. Useful for CSP compliance when using `useRefreshTokens: true` with `cacheLocation: 'memory'` |
| `context` | React.Context | - | Custom React context for nested Auth0Providers. Allows multiple Auth0Providers in same app |
| `interactiveErrorHandler` | `'popup'` | - | Automatically handle MFA via popup when `getAccessTokenSilently` encounters `mfa_required`. Requires `useRefreshTokens={true}` |
| `skipRedirectCallback` | boolean | `false` | Skip automatic callback handling |
| `onRedirectCallback` | function | - | Callback after successful login |

### Authorization Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `redirect_uri` | string | URL to redirect after authentication |
| `audience` | string | API audience identifier |
| `scope` | string | Requested scopes (space-separated) |
| `connection` | string | Force specific connection |
| `prompt` | string | `'none'`, `'login'`, `'consent'`, or `'select_account'` |
| `ui_locales` | string | Language code (e.g., `'en'`, `'es'`) |
| `screen_hint` | string | `'signup'` to show signup by default |
| `max_age` | number | Maximum authentication age in seconds |
| `organization` | string | Organization ID for B2B |
| `invitation` | string | Invitation ID for organization invites |

---

## useAuth0 Hook

### Hook Interface

```typescript
const {
  // Authentication state
  isLoading,
  isAuthenticated,
  error,
  user,

  // Methods
  loginWithRedirect,
  loginWithPopup,
  logout,
  getAccessTokenSilently,
  getAccessTokenWithPopup,
  getIdTokenClaims,
  handleRedirectCallback,

  // MFA API
  mfa,
} = useAuth0();
```

### Authentication State

| Property | Type | Description |
|----------|------|-------------|
| `isLoading` | boolean | True while Auth0 is initializing |
| `isAuthenticated` | boolean | True if user is logged in |
| `error` | Error \| undefined | Authentication error if any |
| `user` | User \| undefined | User profile information |

### User Object

```typescript
interface User {
  sub: string;          // User ID
  name: string;         // Display name
  email: string;        // Email address
  email_verified: boolean;
  picture: string;      // Avatar URL
  updated_at: string;   // Last update timestamp
  // Custom claims...
}
```

### Methods

#### loginWithRedirect

```typescript
await loginWithRedirect(options?: RedirectLoginOptions);
```

Redirects to Auth0 Universal Login page.

**Options:**
```typescript
interface RedirectLoginOptions {
  authorizationParams?: {
    redirect_uri?: string;
    audience?: string;
    scope?: string;
    connection?: string;
    prompt?: 'none' | 'login' | 'consent' | 'select_account';
    max_age?: number;
    ui_locales?: string;
    screen_hint?: 'signup' | 'login';
  };
  appState?: any; // Custom state to preserve
  fragment?: string; // URL fragment
}
```

**Example:**
```tsx
// Basic login
await loginWithRedirect();

// Login with specific connection
await loginWithRedirect({
  authorizationParams: {
    connection: 'google-oauth2'
  }
});

// Login with custom state (preserved through redirect)
await loginWithRedirect({
  appState: { targetUrl: '/dashboard' }
});
// After login, onRedirectCallback receives appState.targetUrl = '/dashboard'
```

#### loginWithPopup

```typescript
await loginWithPopup(options?: PopupLoginOptions);
```

Opens Auth0 login in popup window (better UX, but may be blocked).

**Options:**
```typescript
interface PopupLoginOptions {
  authorizationParams?: AuthorizationParams;
  config?: PopupConfigOptions; // Popup window configuration
}
```

**Example:**
```tsx
try {
  await loginWithPopup();
} catch (error) {
  // Handle popup blocked or closed
  console.error('Popup login failed:', error);
}
```

#### logout

```typescript
logout(options?: LogoutOptions);
```

Logs out the user and optionally redirects.

**Options:**
```typescript
interface LogoutOptions {
  logoutParams?: {
    returnTo?: string; // URL to redirect after logout
    federated?: boolean; // Logout from identity provider too
    client_id?: string; // Client ID (if different from current)
  };
  openUrl?: (url: string) => void; // Custom URL opener
}
```

**Example:**
```tsx
// Basic logout
logout();

// Logout with redirect
logout({
  logoutParams: {
    returnTo: window.location.origin
  }
});

// Federated logout (logout from Google/Facebook too)
logout({
  logoutParams: {
    returnTo: window.location.origin,
    federated: true
  }
});
```

#### getAccessTokenSilently

```typescript
const token = await getAccessTokenSilently(options?: GetTokenSilentlyOptions);
```

Gets access token without user interaction (uses refresh token or iframe).

**Options:**
```typescript
interface GetTokenSilentlyOptions {
  authorizationParams?: {
    audience?: string;
    scope?: string;
    ignoreCache?: boolean; // Force new token
    timeoutInSeconds?: number; // Request timeout
    detailedResponse?: boolean; // Return full response with expiry
  };
}
```

**Example:**
```tsx
// Basic usage
const token = await getAccessTokenSilently();

// With specific audience
const token = await getAccessTokenSilently({
  authorizationParams: {
    audience: 'https://api.example.com'
  }
});

// Force fresh token
const token = await getAccessTokenSilently({
  authorizationParams: {
    ignoreCache: true
  }
});

// Get detailed response with expiry
const { access_token, expires_in } = await getAccessTokenSilently({
  authorizationParams: {
    detailedResponse: true
  }
});
```

#### getAccessTokenWithPopup

```typescript
const token = await getAccessTokenWithPopup(options?: GetTokenWithPopupOptions);
```

Gets access token via popup window. Useful as fallback when `getAccessTokenSilently` fails (e.g., third-party cookies blocked).

**Options:**
```typescript
interface GetTokenWithPopupOptions {
  authorizationParams?: {
    audience?: string;
    scope?: string;
  };
  config?: PopupConfigOptions; // Popup window configuration
}
```

**Example:**
```tsx
// Try silent auth, fall back to popup
try {
  const token = await getAccessTokenSilently();
} catch (error) {
  // Fallback to popup if silent auth fails
  const token = await getAccessTokenWithPopup();
}

// Direct popup usage with specific audience
const token = await getAccessTokenWithPopup({
  authorizationParams: {
    audience: 'https://api.example.com'
  }
});
```

#### getIdTokenClaims

```typescript
const claims = await getIdTokenClaims();
```

Returns ID token claims.

**Example:**
```tsx
const claims = await getIdTokenClaims();
console.log(claims.sub); // User ID
console.log(claims.email);
console.log(claims.custom_claim);
```

#### handleRedirectCallback

```typescript
const result = await handleRedirectCallback(url?: string);
```

Manually handle redirect callback (when `skipRedirectCallback` is true).

**Returns:**
```typescript
interface RedirectLoginResult {
  appState: any; // Custom state from login
}
```

#### mfa

The `mfa` property provides access to the MFA API client for in-app Multi-Factor Authentication flows.

**Methods:**

| Method | Description |
|--------|-------------|
| `mfa.getAuthenticators(mfaToken)` | List enrolled authenticators for the user |
| `mfa.getEnrollmentFactors(mfaToken)` | Get available enrollment factors (when user needs to enroll) |
| `mfa.enroll(params)` | Enroll a new authenticator (OTP, SMS, Email, Voice, Push) |
| `mfa.challenge(params)` | Initiate an MFA challenge for an enrolled authenticator |
| `mfa.verify(params)` | Verify an MFA challenge and complete authentication |

**Enroll params:**

```typescript
// OTP enrollment
await mfa.enroll({ mfaToken, factorType: 'otp' });
// Returns: { barcodeUri, recoveryCodes, ... }

// SMS enrollment
await mfa.enroll({ mfaToken, factorType: 'sms', phoneNumber: '+12025551234' });

// Email enrollment
await mfa.enroll({ mfaToken, factorType: 'email', email: 'user@example.com' });

// Voice enrollment
await mfa.enroll({ mfaToken, factorType: 'voice', phoneNumber: '+12025551234' });

// Push enrollment
await mfa.enroll({ mfaToken, factorType: 'push' });
```

**Challenge params:**

```typescript
// OTP challenge (optional — code is already in authenticator app)
await mfa.challenge({ mfaToken, challengeType: 'otp', authenticatorId });

// SMS/Voice/Email/Push challenge (required — sends code to user)
await mfa.challenge({ mfaToken, challengeType: 'oob', authenticatorId });
// Returns: { oobCode }
```

**Verify params:**

```typescript
// Verify with OTP code
const tokens = await mfa.verify({ mfaToken, otp: '123456' });

// Verify with OOB code (SMS/Voice/Email)
const tokens = await mfa.verify({ mfaToken, oobCode, bindingCode: '123456' });

// Verify with recovery code
const tokens = await mfa.verify({ mfaToken, recoveryCode: 'recovery-code-here' });
```

---

### MFA Error Types

All MFA error types are importable from `@auth0/auth0-react`.

| Error | When thrown | Key properties |
|-------|-----------|----------------|
| `MfaRequiredError` | `getAccessTokenSilently()` encounters an MFA requirement | `mfa_token`, `mfa_requirements` |
| `MfaEnrollmentError` | `mfa.enroll()` fails | `error_description` |
| `MfaChallengeError` | `mfa.challenge()` fails | `error_description` |
| `MfaVerifyError` | `mfa.verify()` fails (e.g., invalid OTP code) | `error_description` |
| `MfaListAuthenticatorsError` | `mfa.getAuthenticators()` fails | `error_description` |
| `MfaEnrollmentFactorsError` | `mfa.getEnrollmentFactors()` fails | `error_description` |

**MfaRequiredError properties:**
- `mfa_token` — Token used for all subsequent MFA operations
- `mfa_requirements.enroll` — Array of factor types the user can enroll in (present when user needs to set up MFA)
- `mfa_requirements.challenge` — Array of factor types the user can challenge (present when user has enrolled authenticators)

**Import:**

```typescript
import {
  MfaRequiredError,
  MfaEnrollmentError,
  MfaChallengeError,
  MfaVerifyError,
} from '@auth0/auth0-react';
```

---

## Custom Hooks

### withAuth0

Higher-order component for class components:

```tsx
import { withAuth0 } from '@auth0/auth0-react';

class Profile extends React.Component {
  render() {
    const { auth0, isLoading, isAuthenticated, user } = this.props;
    // Use auth0 methods and state
  }
}

export default withAuth0(Profile);
```

### withAuthenticationRequired

HOC to protect components requiring authentication:

```tsx
import { withAuthenticationRequired } from '@auth0/auth0-react';

const ProtectedComponent = () => {
  return <div>Protected content</div>;
};

export default withAuthenticationRequired(ProtectedComponent, {
  onRedirecting: () => <div>Loading...</div>,
  returnTo: '/profile', // Where to return after login
  loginOptions: {
    authorizationParams: {
      connection: 'google-oauth2'
    }
  }
});
```

---

## Testing

### Testing with React Testing Library

```tsx
import { render, screen } from '@testing-library/react';
import { Auth0Provider } from '@auth0/auth0-react';
import App from './App';

// Mock Auth0
jest.mock('@auth0/auth0-react', () => ({
  ...jest.requireActual('@auth0/auth0-react'),
  Auth0Provider: ({ children }) => children,
  useAuth0: () => ({
    isLoading: false,
    isAuthenticated: true,
    user: {
      name: 'Test User',
      email: 'test@example.com'
    },
    loginWithRedirect: jest.fn(),
    logout: jest.fn(),
  }),
}));

test('renders authenticated app', () => {
  render(<App />);
  expect(screen.getByText('Test User')).toBeInTheDocument();
});
```

### Testing with Custom Mock

```tsx
// testUtils.tsx
import { Auth0Provider } from '@auth0/auth0-react';

export const mockAuth0User = {
  name: 'Test User',
  email: 'test@example.com',
  picture: 'https://example.com/avatar.jpg',
};

export function renderWithAuth0(ui: React.ReactElement, isAuthenticated = true) {
  return render(
    <Auth0Provider
      domain="test.auth0.com"
      clientId="test-client-id"
      authorizationParams={{
        redirect_uri: window.location.origin
      }}
    >
      {ui}
    </Auth0Provider>
  );
}
```

---

## TypeScript Types

### Import Types

```typescript
import type {
  Auth0ContextInterface,
  User,
  RedirectLoginOptions,
  PopupLoginOptions,
  LogoutOptions,
  GetTokenSilentlyOptions,
  MfaApiClient,
  Authenticator,
  EnrollParams,
  ChallengeResponse,
  VerifyParams,
  EnrollmentFactor,
} from '@auth0/auth0-react';

// MFA error types (value imports, not type-only)
import {
  MfaRequiredError,
  MfaEnrollmentError,
  MfaChallengeError,
  MfaVerifyError,
} from '@auth0/auth0-react';
```

### Type User Profile

```typescript
interface CustomUser extends User {
  app_metadata?: {
    roles?: string[];
  };
  user_metadata?: {
    preferences?: any;
  };
}

const { user } = useAuth0<CustomUser>();
console.log(user?.app_metadata?.roles);
```

---

## Related Skills

- `auth0-quickstart` - Initial Auth0 account setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-organizations` - B2B multi-tenancy support
- `auth0-passkeys` - Add passkey authentication

---

## References

- [Auth0 React SDK Documentation](https://auth0.com/docs/libraries/auth0-react)
- [Auth0 React SDK GitHub](https://github.com/auth0/auth0-react)
- [Auth0 React Quickstart](https://auth0.com/docs/quickstart/spa/react)
- [useAuth0 Hook API](https://auth0.github.io/auth0-react/interfaces/Auth0ContextInterface.html)
- [Auth0 React API Reference](https://auth0.github.io/auth0-react/)
- [Auth0 Universal Login](https://auth0.com/docs/universal-login)
- [PKCE Flow](https://auth0.com/docs/get-started/authentication-and-authorization-flow/authorization-code-flow-with-proof-key-for-code-exchange-pkce)
