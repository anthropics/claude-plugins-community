# auth0-expo Integration Patterns

## Table of Contents

- [Web Auth Login](#web-auth-login) — Basic login with hooks, Auth0 class, audience, organizations
- [Web Auth Logout](#web-auth-logout) — Hook and class-based logout
- [Credential Management](#credential-management) — Retrieve, check, auto-refresh, Auth0 class
- [Biometric Authentication](#biometric-authentication) — Auth0Provider config, policies, Auth0 class
- [DPoP](#dpop-demonstrating-proof-of-possession) — Enable, API calls, token migration
- [Multi-Resource Refresh Tokens](#multi-resource-refresh-tokens-mrrt) — Multiple API access
- [Custom Token Exchange](#custom-token-exchange-rfc-8693) — External provider tokens
- [Native to Web SSO](#native-to-web-sso) — Session transfer to web apps
- [Organization Invitations](#organization-invitations) — Deep link handling
- [Error Handling](#error-handling) — WebAuth errors, Credentials Manager errors
- [Credential Renewal Retry](#credential-renewal-retry-ios) — iOS retry with backoff
- [Using Custom Headers](#using-custom-headers) — Custom API request headers

## Web Auth Login

The primary authentication method uses Auth0 Universal Login via the system browser. The `useAuth0` hook provides the `authorize` method.

### Basic Login with Hooks

```typescript
import { useAuth0 } from 'react-native-auth0';

function LoginScreen() {
  const { authorize, user, isLoading, error } = useAuth0();

  const login = async () => {
    try {
      await authorize(
        { scope: 'openid profile email' },
        { customScheme: 'auth0sample' }
      );
    } catch (e) {
      console.error('Login error:', e);
    }
  };

  if (isLoading) return <ActivityIndicator />;

  return (
    <View>
      {!user && <Button title="Log In" onPress={login} />}
      {user && <Text>Welcome, {user.name}!</Text>}
      {error && <Text style={{ color: 'red' }}>{error.message}</Text>}
    </View>
  );
}
```

### Login with Auth0 Class (Non-Hook)

```typescript
import Auth0 from 'react-native-auth0';

const auth0 = new Auth0({
  domain: 'YOUR_AUTH0_DOMAIN',
  clientId: 'YOUR_AUTH0_CLIENT_ID',
});

const credentials = await auth0.webAuth.authorize(
  { scope: 'openid profile email' },
  { customScheme: 'auth0sample' }
);
// Access token available at credentials.accessToken
```

### Login with Audience (API Access)

To get an access token for a specific API:

```typescript
await authorize(
  {
    scope: 'openid profile email offline_access',
    audience: 'https://your-api.example.com',
  },
  { customScheme: 'auth0sample' }
);
```

### Login with Organization

```typescript
await authorize(
  {
    scope: 'openid profile email',
    organization: 'org_abc123',
  },
  { customScheme: 'auth0sample' }
);
```

## Web Auth Logout

```typescript
import { useAuth0 } from 'react-native-auth0';

function LogoutButton() {
  const { clearSession } = useAuth0();

  const logout = async () => {
    try {
      await clearSession({ customScheme: 'auth0sample' });
    } catch (e) {
      console.error('Logout error:', e);
    }
  };

  return <Button title="Log Out" onPress={logout} />;
}
```

### Logout with Auth0 Class

```typescript
await auth0.webAuth.clearSession({}, { customScheme: 'auth0sample' });
await auth0.credentialsManager.clearCredentials();
```

## Credential Management

The `Auth0Provider` automatically stores and manages credentials. When using hooks, credentials are saved after login and cleared after logout automatically.

### Retrieve Stored Credentials

```typescript
const { getCredentials } = useAuth0();

const fetchData = async () => {
  try {
    const credentials = await getCredentials();
    const response = await fetch('https://your-api.example.com/data', {
      headers: {
        Authorization: `Bearer ${credentials.accessToken}`,
      },
    });
    const data = await response.json();
  } catch (e) {
    console.error('Failed to get credentials:', e);
  }
};
```

### Check for Valid Credentials

```typescript
const { hasValidCredentials } = useAuth0();

useEffect(() => {
  const checkAuth = async () => {
    const isLoggedIn = await hasValidCredentials();
    if (isLoggedIn) {
      // User has valid stored credentials
      navigation.navigate('Home');
    } else {
      navigation.navigate('Login');
    }
  };
  checkAuth();
}, []);
```

### Credential Auto-Refresh

The credentials manager automatically refreshes expired access tokens using the refresh token. Ensure you request the `offline_access` scope during login:

```typescript
await authorize(
  { scope: 'openid profile email offline_access' },
  { customScheme: 'auth0sample' }
);
```

### Credentials with Auth0 Class

```typescript
// Check for credentials
const isLoggedIn = await auth0.credentialsManager.hasValidCredentials();

// Get credentials (auto-refreshes if expired)
const credentials = await auth0.credentialsManager.getCredentials();

// Save credentials manually (not needed with hooks — auto-managed)
await auth0.credentialsManager.saveCredentials(credentials);

// Clear credentials
await auth0.credentialsManager.clearCredentials();
```

## Biometric Authentication

Protect credential access with biometric authentication (Face ID, Touch ID, fingerprint).

### With Auth0Provider (Hooks)

```typescript
import {
  Auth0Provider,
  BiometricPolicy,
  LocalAuthenticationStrategy,
  LocalAuthenticationLevel,
} from 'react-native-auth0';

export default function App() {
  return (
    <Auth0Provider
      domain="YOUR_AUTH0_DOMAIN"
      clientId="YOUR_AUTH0_CLIENT_ID"
      localAuthenticationOptions={{
        title: 'Authenticate to access credentials',
        subtitle: 'Please verify your identity',
        cancelTitle: 'Cancel',
        evaluationPolicy: LocalAuthenticationStrategy.deviceOwnerWithBiometrics,
        fallbackTitle: 'Use Passcode',
        authenticationLevel: LocalAuthenticationLevel.strong,
        deviceCredentialFallback: true,
        biometricPolicy: BiometricPolicy.session,
        biometricTimeout: 300, // 5 minutes
      }}
    >
      <HomeScreen />
    </Auth0Provider>
  );
}
```

### Biometric Policy Types

| Policy | Behavior |
|--------|----------|
| `BiometricPolicy.default` | System-managed. May skip prompt if recently authenticated. |
| `BiometricPolicy.always` | Always prompts for biometric on every credential access. |
| `BiometricPolicy.session` | Prompts once per session; reuses for the specified timeout. |
| `BiometricPolicy.appLifecycle` | Prompts once until app restarts or credentials are cleared. |

### With Auth0 Class

```typescript
import Auth0, {
  BiometricPolicy,
  LocalAuthenticationStrategy,
  LocalAuthenticationLevel,
} from 'react-native-auth0';

const auth0 = new Auth0({
  domain: 'YOUR_AUTH0_DOMAIN',
  clientId: 'YOUR_AUTH0_CLIENT_ID',
  localAuthenticationOptions: {
    title: 'Authenticate to access credentials',
    evaluationPolicy: LocalAuthenticationStrategy.deviceOwnerWithBiometrics,
    authenticationLevel: LocalAuthenticationLevel.strong,
    biometricPolicy: BiometricPolicy.always,
  },
});
```

## DPoP (Demonstrating Proof-of-Possession)

DPoP cryptographically binds tokens to a client-specific key pair, preventing token theft.

### Enable DPoP

DPoP is enabled by default in react-native-auth0:

```typescript
<Auth0Provider
  domain="YOUR_AUTH0_DOMAIN"
  clientId="YOUR_AUTH0_CLIENT_ID"
  // DPoP is enabled by default (useDPoP: true)
>
  <App />
</Auth0Provider>
```

### Make API Calls with DPoP

```typescript
const { getCredentials, getDPoPHeaders } = useAuth0();

const callApi = async () => {
  const credentials = await getCredentials();
  const headers = await getDPoPHeaders({
    url: 'https://api.example.com/data',
    method: 'GET',
    accessToken: credentials.accessToken,
    tokenType: credentials.tokenType,
  });

  const response = await fetch('https://api.example.com/data', {
    method: 'GET',
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
};
```

### Handle DPoP Token Migration

```typescript
const { getCredentials, clearSession, authorize } = useAuth0();

const ensureDPoP = async () => {
  const credentials = await getCredentials();
  if (credentials.tokenType !== 'DPoP') {
    await clearSession({ customScheme: 'auth0sample' });
    await authorize(
      { scope: 'openid profile email' },
      { customScheme: 'auth0sample' }
    );
  }
};
```

## Multi-Resource Refresh Tokens (MRRT)

Access tokens for multiple APIs using a single refresh token:

```typescript
const { authorize, getApiCredentials, clearApiCredentials } = useAuth0();

// Login with offline_access
await authorize(
  {
    scope: 'openid profile email offline_access',
    audience: 'https://primary-api.example.com',
  },
  { customScheme: 'auth0sample' }
);

// Get token for a different API
const apiCredentials = await getApiCredentials(
  'https://second-api.example.com',
  'read:data write:data'
);
// Access token available at apiCredentials.accessToken
```

## Custom Token Exchange (RFC 8693)

Exchange external provider tokens for Auth0 tokens:

```typescript
import { useAuth0, AuthenticationException, AuthenticationErrorCodes } from 'react-native-auth0';

const { customTokenExchange } = useAuth0();

try {
  const credentials = await customTokenExchange({
    subjectToken: 'token-from-external-provider',
    subjectTokenType: 'urn:acme:legacy-system-token',
    scope: 'openid profile email',
  });
} catch (e) {
  if (e instanceof AuthenticationException) {
    if (e.type === AuthenticationErrorCodes.INVALID_SUBJECT_TOKEN) {
      console.error('External token is invalid or expired');
    }
  }
}
```

## Native to Web SSO

Transfer authenticated sessions from the Expo app to a web application:

```typescript
import { useAuth0 } from 'react-native-auth0';
import { Linking } from 'react-native';

const { getSSOCredentials } = useAuth0();

const openWebApp = async () => {
  const ssoCredentials = await getSSOCredentials();
  const webAppUrl = `https://your-web-app.com/login?session_transfer_token=${ssoCredentials.sessionTransferToken}`;
  await Linking.openURL(webAppUrl);
};
```

## Organization Invitations

Handle organization invitation links:

```typescript
import { Linking } from 'react-native';

const handleInvitation = async (url: string) => {
  await auth0.webAuth.authorize(
    { invitationUrl: url },
    { customScheme: 'auth0sample' }
  );
};

// Listen for deep links
Linking.addEventListener('url', ({ url }) => {
  if (url.includes('invitation=')) {
    handleInvitation(url);
  }
});
```

## Error Handling

### WebAuth Errors

```typescript
import { WebAuthError, WebAuthErrorCodes } from 'react-native-auth0';

try {
  await authorize(
    { scope: 'openid profile email' },
    { customScheme: 'auth0sample' }
  );
} catch (e) {
  if (e instanceof WebAuthError) {
    switch (e.type) {
      case WebAuthErrorCodes.USER_CANCELLED:
        console.log('User cancelled login');
        break;
      case WebAuthErrorCodes.BROWSER_NOT_AVAILABLE:
        console.log('No browser available on device');
        break;
      case WebAuthErrorCodes.PKCE_NOT_ALLOWED:
        console.log('PKCE not enabled — set app type to Native in Auth0 Dashboard');
        break;
      case WebAuthErrorCodes.NETWORK_ERROR:
        console.log('Network error — check connectivity');
        break;
      default:
        console.error('Auth error:', e.message);
    }
  }
}
```

### Credentials Manager Errors

```typescript
import {
  CredentialsManagerError,
  CredentialsManagerErrorCodes,
} from 'react-native-auth0';

try {
  const credentials = await getCredentials();
} catch (e) {
  if (e instanceof CredentialsManagerError) {
    switch (e.type) {
      case CredentialsManagerErrorCodes.NO_CREDENTIALS:
        console.log('No credentials stored — user needs to log in');
        break;
      case CredentialsManagerErrorCodes.NO_REFRESH_TOKEN:
        console.log('No refresh token — request offline_access scope');
        break;
      case CredentialsManagerErrorCodes.RENEW_FAILED:
        console.log('Token refresh failed — re-authentication required');
        break;
      case CredentialsManagerErrorCodes.BIOMETRICS_FAILED:
        console.log('Biometric authentication failed');
        break;
      default:
        console.error('Credentials error:', e.message);
    }
  }
}
```

## Credential Renewal Retry (iOS)

For unstable network conditions, configure automatic retry for credential renewal:

```typescript
<Auth0Provider
  domain="YOUR_AUTH0_DOMAIN"
  clientId="YOUR_AUTH0_CLIENT_ID"
  maxRetries={2}
>
  <App />
</Auth0Provider>
```

This retries on network errors, HTTP 429, and HTTP 5xx responses with exponential backoff. iOS only — the parameter is ignored on Android.

If using refresh token rotation, configure a token overlap period of at least **180 seconds** in your Auth0 tenant settings.

## Using Custom Headers

```typescript
<Auth0Provider
  domain="YOUR_AUTH0_DOMAIN"
  clientId="YOUR_AUTH0_CLIENT_ID"
  headers={{
    'Accept-Language': 'fr-CA',
    'X-App-Version': '1.0.0',
  }}
>
  <App />
</Auth0Provider>
```
