# Auth0 React Integration Patterns

Practical implementation patterns and examples for common use cases.

---

## Protected Routes

### Basic Protected Route Component

```tsx
import { useAuth0 } from '@auth0/auth0-react';
import { Navigate } from 'react-router-dom';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading, loginWithRedirect } = useAuth0();

  if (isLoading) {
    return <div>Loading...</div>;
  }

  if (!isAuthenticated) {
    loginWithRedirect();
    return null;
  }

  return <>{children}</>;
}
```

### Usage with React Router

```tsx
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { ProtectedRoute } from './components/ProtectedRoute';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route
          path="/profile"
          element={
            <ProtectedRoute>
              <Profile />
            </ProtectedRoute>
          }
        />
      </Routes>
    </BrowserRouter>
  );
}
```

---

## User Profile

### Display User Information

```tsx
import { useAuth0 } from '@auth0/auth0-react';

export function Profile() {
  const { user, isAuthenticated } = useAuth0();

  if (!isAuthenticated) {
    return <div>Please log in</div>;
  }

  return (
    <div>
      <img src={user?.picture} alt={user?.name} />
      <h2>{user?.name}</h2>
      <p>{user?.email}</p>
    </div>
  );
}
```

---

## Calling APIs

### Call Protected API with Access Token

```tsx
import { useAuth0 } from '@auth0/auth0-react';
import { useState } from 'react';

export function ApiTest() {
  const { getAccessTokenSilently } = useAuth0();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  const callApi = async () => {
    try {
      const token = await getAccessTokenSilently({
        authorizationParams: {
          audience: 'https://your-api-identifier', // Your API identifier
        }
      });

      const response = await fetch('https://your-api.com/data', {
        headers: {
          Authorization: `Bearer ${token}`
        }
      });

      const json = await response.json();
      setData(json);
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div>
      <button onClick={callApi}>Call API</button>
      {error && <div>Error: {error}</div>}
      {data && <pre>{JSON.stringify(data, null, 2)}</pre>}
    </div>
  );
}
```

### Configure Provider for API Calls

When calling APIs, add `audience` to your Auth0Provider:

```tsx
<Auth0Provider
  domain={import.meta.env.VITE_AUTH0_DOMAIN}
  clientId={import.meta.env.VITE_AUTH0_CLIENT_ID}
  authorizationParams={{
    redirect_uri: window.location.origin,
    audience: 'https://your-api-identifier' // Add this
  }}
>
  <App />
</Auth0Provider>
```

---

## Error Handling

### Handle Loading and Error States

```tsx
import { useAuth0 } from '@auth0/auth0-react';

export function App() {
  const { isLoading, error, isAuthenticated, user } = useAuth0();

  if (isLoading) {
    return <div>Loading authentication...</div>;
  }

  if (error) {
    return <div>Authentication error: {error.message}</div>;
  }

  return isAuthenticated ? (
    <div>
      <h1>Welcome back, {user?.name}!</h1>
      <AuthenticatedApp />
    </div>
  ) : (
    <div>
      <h1>Please log in</h1>
      <LoginButton />
    </div>
  );
}
```

---

## Silent Authentication

### Auto-login on Page Load

```tsx
import { useAuth0 } from '@auth0/auth0-react';
import { useEffect } from 'react';

export function App() {
  const { isAuthenticated, isLoading, getAccessTokenSilently } = useAuth0();

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      // Attempt silent authentication
      getAccessTokenSilently().catch(() => {
        // User not logged in, do nothing
      });
    }
  }, [isLoading, isAuthenticated, getAccessTokenSilently]);

  // Rest of your app...
}
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Invalid state" error | Clear browser storage and try again. Ensure `redirect_uri` matches configured callback URL |
| User stuck on loading | Check Auth0 application settings have correct callback URLs configured |
| API calls fail with 401 | Ensure `audience` is configured in Auth0Provider and matches your API identifier |
| Logout doesn't work | Include `returnTo` URL in logout options and configure in Auth0 "Allowed Logout URLs" |
| CORS errors when calling API | Add your application URL to "Allowed Web Origins" in Auth0 application settings |
| Tokens not refreshing | Enable `useRefreshTokens={true}` in Auth0Provider and ensure refresh token rotation is enabled in Auth0 |

---

## MFA Handling

The `@auth0/auth0-react` SDK provides a built-in MFA API for handling Multi-Factor Authentication entirely within your app — no redirects to Universal Login required. Access it via the `mfa` property from `useAuth0()`.

> **Note:** MFA support via SDKs is currently in Early Access. For a simpler approach that uses Universal Login to handle MFA automatically (no custom UI), see the [Step-Up via Popup](#step-up-via-popup-simpler-approach) section below.

### Catching MfaRequiredError

When `getAccessTokenSilently()` encounters an MFA requirement, it throws `MfaRequiredError`. Catch it and inspect `mfa_requirements` to determine the flow:

```tsx
import { useAuth0, MfaRequiredError } from '@auth0/auth0-react';
import { useState } from 'react';

export function ProtectedApiCall() {
  const { getAccessTokenSilently, mfa } = useAuth0();
  const [mfaToken, setMfaToken] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const callApi = async () => {
    try {
      const token = await getAccessTokenSilently();
      // Use token to call API...
    } catch (err) {
      if (err instanceof MfaRequiredError) {
        setMfaToken(err.mfa_token);

        // Check if enrollment or challenge is needed
        const factors = await mfa.getEnrollmentFactors(err.mfa_token);
        if (factors.length > 0) {
          // User needs to enroll — show enrollment UI
        } else {
          // User has authenticators — show challenge UI
          const authenticators = await mfa.getAuthenticators(err.mfa_token);
          // Let user pick authenticator and proceed with challenge
        }
      } else {
        setError(err.message);
      }
    }
  };

  return <button onClick={callApi}>Call Protected API</button>;
}
```

### OTP Enrollment

When the user needs to set up MFA for the first time:

```tsx
import { useAuth0, MfaEnrollmentError } from '@auth0/auth0-react';
import { useState } from 'react';

export function OtpEnrollment({ mfaToken }: { mfaToken: string }) {
  const { mfa } = useAuth0();
  const [barcodeUri, setBarcodeUri] = useState<string | null>(null);
  const [recoveryCodes, setRecoveryCodes] = useState<string[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const startEnrollment = async () => {
    try {
      const enrollment = await mfa.enroll({ mfaToken, factorType: 'otp' });
      setBarcodeUri(enrollment.barcodeUri);
      setRecoveryCodes(enrollment.recoveryCodes);
    } catch (err) {
      if (err instanceof MfaEnrollmentError) {
        setError(err.error_description);
      }
    }
  };

  return (
    <div>
      <button onClick={startEnrollment}>Set up authenticator app</button>
      {barcodeUri && (
        <div>
          <p>Scan this QR code with your authenticator app:</p>
          {/* Render barcodeUri as QR code using a library like qrcode.react */}
          <code>{barcodeUri}</code>
        </div>
      )}
      {recoveryCodes && (
        <div>
          <p>Save these recovery codes:</p>
          <ul>
            {recoveryCodes.map((code, i) => <li key={i}>{code}</li>)}
          </ul>
        </div>
      )}
    </div>
  );
}
```

### Challenge and Verify

When the user already has enrolled authenticators:

```tsx
import {
  useAuth0,
  MfaChallengeError,
  MfaVerifyError,
} from '@auth0/auth0-react';
import { useState } from 'react';

export function MfaChallenge({ mfaToken }: { mfaToken: string }) {
  const { mfa } = useAuth0();
  const [otp, setOtp] = useState('');
  const [error, setError] = useState<string | null>(null);

  const handleVerify = async () => {
    try {
      // For OTP authenticators, you can skip challenge() and go straight to verify()
      const tokens = await mfa.verify({ mfaToken, otp });
      // User is now authenticated — tokens are cached by the SDK
      // Access token available at tokens.access_token
    } catch (err) {
      if (err instanceof MfaVerifyError) {
        setError('Invalid code. Please try again.');
      } else if (err instanceof MfaChallengeError) {
        setError('Challenge failed: ' + err.error_description);
      }
    }
  };

  return (
    <div>
      <h3>Enter your verification code</h3>
      <input
        type="text"
        value={otp}
        onChange={(e) => setOtp(e.target.value)}
        placeholder="6-digit code"
        maxLength={6}
      />
      <button onClick={handleVerify}>Verify</button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
    </div>
  );
}
```

### SMS/Email Challenge (Out-of-Band)

For SMS, Email, Voice, or Push authenticators, you must call `challenge()` first to send the code:

```tsx
// Initiate challenge to send code via SMS/Email
const response = await mfa.challenge({
  mfaToken,
  challengeType: 'oob',
  authenticatorId: authenticator.id,
});

// Verify with the OOB code and the binding code the user received
const tokens = await mfa.verify({
  mfaToken,
  oobCode: response.oobCode,
  bindingCode: userEnteredCode,
});
```

### Step-Up via Popup (Simpler Approach)

If you don't need a custom MFA UI, configure `interactiveErrorHandler` to let the SDK handle MFA automatically via a Universal Login popup:

```tsx
<Auth0Provider
  domain={import.meta.env.VITE_AUTH0_DOMAIN}
  clientId={import.meta.env.VITE_AUTH0_CLIENT_ID}
  authorizationParams={{
    redirect_uri: window.location.origin,
    audience: 'https://your-api-identifier',
  }}
  useRefreshTokens={true}
  interactiveErrorHandler="popup"
>
  <App />
</Auth0Provider>
```

With this setup, `getAccessTokenSilently()` automatically opens a popup when MFA is required. No error handling needed — the token is returned after the user completes MFA in the popup.

---

## Security Considerations

### Client-Side Security

- **Never expose client secret** - React is client-side, use only public client credentials
- **Use PKCE** - Enabled by default with @auth0/auth0-react
- **Validate tokens on backend** - Never trust client-side token validation
- **Use HTTPS in production** - Auth0 requires HTTPS for production redirect URLs
- **Implement proper CORS** - Configure allowed origins in Auth0 application settings

### Token Storage

```tsx
// Default: memory storage for highest security (tokens cleared on page refresh)
<Auth0Provider
  cacheLocation="memory"
  {...other props}
>

// Or localstorage for better UX (tokens persist across refreshes)
<Auth0Provider
  cacheLocation="localstorage"
  {...other props}
>
```

### Secure API Calls

Always validate tokens on your backend:

**Installation:**
```bash
npm install express-oauth2-jwt-bearer
```

**Backend validation example (Node.js):**
```javascript
const { auth, requiredScopes } = require('express-oauth2-jwt-bearer');

const checkJwt = auth({
  audience: process.env.AUTH0_AUDIENCE,
  issuerBaseURL: `https://${process.env.AUTH0_DOMAIN}`,
});

app.get('/api/private', checkJwt, (req, res) => {
  res.json({ message: 'Secured data' });
});

// With scope validation
app.get('/api/users', checkJwt, requiredScopes('read:users'), (req, res) => {
  res.json({ users: [] });
});
```

---

## Advanced Patterns

### Custom Login with Redirect Options

```tsx
const { loginWithRedirect } = useAuth0();

// Login with specific connection
await loginWithRedirect({
  authorizationParams: {
    connection: 'google-oauth2'
  }
});

// Login with prompt
await loginWithRedirect({
  authorizationParams: {
    prompt: 'login' // Force login even if user has session
  }
});

// Login with custom state
await loginWithRedirect({
  appState: { targetUrl: '/protected-page' }
});
```

### Handle Redirect Callback

```tsx
import { useAuth0 } from '@auth0/auth0-react';
import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

export function Callback() {
  const { handleRedirectCallback } = useAuth0();
  const navigate = useNavigate();

  useEffect(() => {
    (async () => {
      const result = await handleRedirectCallback();
      const targetUrl = result.appState?.targetUrl || '/';
      navigate(targetUrl);
    })();
  }, [handleRedirectCallback, navigate]);

  return <div>Processing login...</div>;
}
```

### Custom Logout

```tsx
const { logout } = useAuth0();

// Logout with custom return URL
logout({
  logoutParams: {
    returnTo: `${window.location.origin}/goodbye`
  }
});

// Logout without redirect (federated logout)
logout({
  logoutParams: {
    federated: true
  }
});
```

---

## Testing

### Manual Testing Checklist

1. **Login Flow**
   - Start dev server: `npm run dev` (Vite) or `npm start` (CRA)
   - Click "Login" button
   - Complete Auth0 Universal Login
   - Verify redirect back to your app with user authenticated
   - Check user profile displays correctly

2. **Logout Flow**
   - Click "Logout" button
   - Verify user is logged out
   - Verify redirect to correct page

3. **Protected Routes**
   - Navigate to protected route while logged out
   - Verify redirect to Auth0 login
   - After login, verify redirect back to protected route

4. **API Calls**
   - Call protected API endpoint
   - Verify access token is included in request
   - Verify API responds correctly

---

## Next Steps

- [API Reference](api.md) - Complete SDK documentation, configuration options, hooks reference
- [Setup Guide](setup.md) - Detailed setup instructions and scripts
- [Main Skill](../SKILL.md) - Return to main skill guide
