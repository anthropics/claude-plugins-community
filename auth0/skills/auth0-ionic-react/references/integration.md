# Integration Patterns

## Authentication Flow

The Ionic React + Capacitor authentication flow:

1. User taps "Login" button
2. `loginWithRedirect()` is called with a custom `openUrl` that uses `Browser.open()`
3. Capacitor Browser opens Auth0 Universal Login in a system browser (SFSafariViewController on iOS, Chrome Custom Tabs on Android)
4. User authenticates with Auth0
5. Auth0 redirects to the custom scheme callback URL (`packageId://domain/capacitor/packageId/callback`)
6. Capacitor App plugin receives the deep link via `appUrlOpen` event
7. `handleRedirectCallback(url)` processes the authorization code
8. `Browser.close()` dismisses the system browser
9. User is now authenticated — `isAuthenticated` is `true`, `user` is populated

## Auth0Provider Setup

Configure `Auth0Provider` at your app's entry point (`src/main.tsx` or `src/index.tsx`):

```tsx
import React from 'react';
import { createRoot } from 'react-dom/client';
import { Auth0Provider } from '@auth0/auth0-react';
import App from './App';

const domain = "your-tenant.auth0.com";
const clientId = "your-client-id";
const packageId = "com.example.myapp";
const callbackUri = `${packageId}://${domain}/capacitor/${packageId}/callback`;

const root = createRoot(document.getElementById('root')!);

root.render(
  <Auth0Provider
    domain={domain}
    clientId={clientId}
    useRefreshTokens={true}
    useRefreshTokensFallback={false}
    authorizationParams={{
      redirect_uri: callbackUri
    }}
  >
    <App />
  </Auth0Provider>
);
```

### Why These Props Are Required for Capacitor

| Prop | Value | Reason |
|------|-------|--------|
| `useRefreshTokens` | `true` | Mobile apps cannot use iframe-based token renewal. Refresh tokens provide reliable session persistence. |
| `useRefreshTokensFallback` | `false` | Prevents the SDK from attempting iframe fallback, which fails on native. |
| `authorizationParams.redirect_uri` | Custom scheme URL | Native apps use a custom URL scheme, not `http://localhost`. |

## Login Implementation

```tsx
import React from 'react';
import { useAuth0 } from '@auth0/auth0-react';
import { Browser } from '@capacitor/browser';
import { IonButton } from '@ionic/react';

const LoginButton: React.FC = () => {
  const { loginWithRedirect } = useAuth0();

  const login = async () => {
    await loginWithRedirect({
      async openUrl(url) {
        await Browser.open({
          url,
          windowName: "_self"
        });
      }
    });
  };

  return <IonButton onClick={login}>Log in</IonButton>;
};

export default LoginButton;
```

## Deep Link Callback Handling

Handle the callback in your main App component. This must run on app initialization:

```tsx
import React, { useEffect } from 'react';
import { useAuth0 } from '@auth0/auth0-react';
import { App as CapApp } from '@capacitor/app';
import { Browser } from '@capacitor/browser';
import {
  IonApp,
  IonRouterOutlet,
  setupIonicReact
} from '@ionic/react';
import { IonReactRouter } from '@ionic/react-router';

setupIonicReact();

const App: React.FC = () => {
  const { handleRedirectCallback } = useAuth0();

  useEffect(() => {
    const handleAppUrlOpen = async ({ url }: { url: string }) => {
      if (url.includes('state') && (url.includes('code') || url.includes('error'))) {
        await handleRedirectCallback(url);
      }
      await Browser.close();
    };

    CapApp.addListener('appUrlOpen', handleAppUrlOpen);

    return () => {
      CapApp.removeAllListeners();
    };
  }, [handleRedirectCallback]);

  return (
    <IonApp>
      <IonReactRouter>
        <IonRouterOutlet>
          {/* Your routes */}
        </IonRouterOutlet>
      </IonReactRouter>
    </IonApp>
  );
};

export default App;
```

## Logout Implementation

```tsx
import React from 'react';
import { useAuth0 } from '@auth0/auth0-react';
import { Browser } from '@capacitor/browser';
import { IonButton } from '@ionic/react';

const domain = "your-tenant.auth0.com";
const packageId = "com.example.myapp";
const logoutUri = `${packageId}://${domain}/capacitor/${packageId}/callback`;

const LogoutButton: React.FC = () => {
  const { logout } = useAuth0();

  const doLogout = async () => {
    await logout({
      logoutParams: {
        returnTo: logoutUri
      },
      async openUrl(url) {
        await Browser.open({
          url,
          windowName: "_self"
        });
      }
    });
  };

  return <IonButton onClick={doLogout}>Log out</IonButton>;
};

export default LogoutButton;
```

## User Profile Display

```tsx
import React from 'react';
import { useAuth0 } from '@auth0/auth0-react';
import {
  IonCard,
  IonCardContent,
  IonCardHeader,
  IonCardTitle,
  IonAvatar,
  IonItem,
  IonLabel,
  IonSpinner
} from '@ionic/react';

const Profile: React.FC = () => {
  const { user, isLoading, isAuthenticated } = useAuth0();

  if (isLoading) {
    return <IonSpinner />;
  }

  if (!isAuthenticated || !user) {
    return null;
  }

  return (
    <IonCard>
      <IonCardHeader>
        <IonItem lines="none">
          <IonAvatar slot="start">
            <img src={user.picture} alt={user.name} />
          </IonAvatar>
          <IonLabel>
            <IonCardTitle>{user.name}</IonCardTitle>
            <p>{user.email}</p>
          </IonLabel>
        </IonItem>
      </IonCardHeader>
      <IonCardContent>
        <pre>{JSON.stringify(user, null, 2)}</pre>
      </IonCardContent>
    </IonCard>
  );
};

export default Profile;
```

## Protected Routes

Use `withAuthenticationRequired` HOC to protect Ionic pages:

```tsx
import React from 'react';
import { withAuthenticationRequired } from '@auth0/auth0-react';
import { IonPage, IonContent, IonSpinner } from '@ionic/react';

const ProtectedPage: React.FC = () => {
  return (
    <IonPage>
      <IonContent>
        <h1>Protected Content</h1>
      </IonContent>
    </IonPage>
  );
};

export default withAuthenticationRequired(ProtectedPage, {
  onRedirecting: () => (
    <IonPage>
      <IonContent className="ion-text-center ion-padding">
        <IonSpinner />
      </IonContent>
    </IonPage>
  ),
});
```

### Route Setup with IonReactRouter

```tsx
import { Route, Redirect } from 'react-router-dom';
import { IonRouterOutlet } from '@ionic/react';
import { IonReactRouter } from '@ionic/react-router';

import HomePage from './pages/Home';
import ProtectedPage from './pages/Protected';

<IonReactRouter>
  <IonRouterOutlet>
    <Route exact path="/home" component={HomePage} />
    <Route exact path="/protected" component={ProtectedPage} />
    <Redirect exact from="/" to="/home" />
  </IonRouterOutlet>
</IonReactRouter>
```

## Accessing API Tokens

```tsx
import { useAuth0 } from '@auth0/auth0-react';

const ApiCaller: React.FC = () => {
  const { getAccessTokenSilently } = useAuth0();

  const callApi = async () => {
    const token = await getAccessTokenSilently({
      authorizationParams: {
        audience: "https://api.example.com/",
        scope: "read:data",
      }
    });

    const response = await fetch("https://api.example.com/data", {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    return response.json();
  };

  // ...
};
```

To use API tokens, configure the `audience` in Auth0Provider:

```tsx
<Auth0Provider
  domain={domain}
  clientId={clientId}
  useRefreshTokens={true}
  useRefreshTokensFallback={false}
  authorizationParams={{
    redirect_uri: callbackUri,
    audience: "https://api.example.com/",
  }}
>
```

## Conditional Login/Logout UI

```tsx
import React from 'react';
import { useAuth0 } from '@auth0/auth0-react';
import { Browser } from '@capacitor/browser';
import { IonButton } from '@ionic/react';

const AuthButton: React.FC = () => {
  const { isAuthenticated, loginWithRedirect, logout } = useAuth0();

  const domain = "your-tenant.auth0.com";
  const packageId = "com.example.myapp";
  const callbackUri = `${packageId}://${domain}/capacitor/${packageId}/callback`;

  if (isAuthenticated) {
    return (
      <IonButton onClick={() => logout({
        logoutParams: { returnTo: callbackUri },
        async openUrl(url) {
          await Browser.open({ url, windowName: "_self" });
        }
      })}>
        Log out
      </IonButton>
    );
  }

  return (
    <IonButton onClick={() => loginWithRedirect({
      async openUrl(url) {
        await Browser.open({ url, windowName: "_self" });
      }
    })}>
      Log in
    </IonButton>
  );
};

export default AuthButton;
```

## Organizations Support

```tsx
await loginWithRedirect({
  authorizationParams: {
    organization: "org_abc123",
  },
  async openUrl(url) {
    await Browser.open({ url, windowName: "_self" });
  }
});
```

To accept an organization invitation:

```tsx
await loginWithRedirect({
  authorizationParams: {
    organization: "org_abc123",
    invitation: "inv_xyz789",
  },
  async openUrl(url) {
    await Browser.open({ url, windowName: "_self" });
  }
});
```

## Error Handling

```tsx
import { useAuth0 } from '@auth0/auth0-react';

const App: React.FC = () => {
  const { error, isLoading } = useAuth0();

  if (isLoading) {
    return <IonSpinner />;
  }

  if (error) {
    return (
      <IonCard color="danger">
        <IonCardContent>
          <h2>Authentication Error</h2>
          <p>{error.message}</p>
        </IonCardContent>
      </IonCard>
    );
  }

  return <App />;
};
```

### Common Error Types

| Error | Cause | Resolution |
|-------|-------|------------|
| `login_required` | Session expired or not authenticated | Re-trigger `loginWithRedirect()` |
| `consent_required` | User hasn't consented to requested scopes | Re-trigger login with `prompt: 'consent'` |
| `invalid_grant` | Refresh token expired or revoked | Clear session and re-authenticate |
| `access_denied` | User denied consent or rule blocked access | Check Auth0 Actions/Rules for blocks |
| `mfa_required` | MFA is required for the user | Handle MFA enrollment flow |

## Testing Patterns

### Physical Device Testing

Always test authentication flows on a physical device. Simulators and emulators may not correctly handle deep link callbacks or system browser interactions. To test on a physical device:

```bash
ionic build
npx cap sync
npx cap open ios   # Build and run on device from Xcode
npx cap open android  # Build and run on device from Android Studio
```

### Manual Testing Flow

1. Run `ionic serve` for browser testing (limited — deep links won't work)
2. Build and deploy to a physical device:
   ```bash
   ionic build
   npx cap sync
   npx cap open ios   # or: npx cap open android
   ```
3. Build and run from Xcode/Android Studio on a physical device
4. Tap Login → should open system browser
5. Authenticate → should return to app with user data
6. Tap Logout → should clear session and redirect back
