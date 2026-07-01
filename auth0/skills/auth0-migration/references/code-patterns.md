# Code Migration Patterns

Before/after code examples for migrating from common auth providers to Auth0 across different frameworks.

---

## React Migration

### Email/Password Authentication

**Before (typical pattern):**
```typescript
// Old provider pattern
await signIn(email, password);
await signOut();
const user = getCurrentUser();
```

**After (Auth0):**
```typescript
import { useAuth0 } from '@auth0/auth0-react';

const { loginWithRedirect, logout, user, isAuthenticated } = useAuth0();

// Login triggers redirect to Auth0 Universal Login
loginWithRedirect();

// Logout with redirect
logout({ logoutParams: { returnTo: window.location.origin } });

// User available when authenticated
if (isAuthenticated) {
  console.log(user.email);
}
```

---

### Auth State Listener

**Before (typical pattern):**
```typescript
// Old provider pattern
onAuthStateChange((user) => {
  if (user) { /* authenticated */ }
  else { /* not authenticated */ }
});
```

**After (Auth0):**
```typescript
import { useAuth0 } from '@auth0/auth0-react';

function App() {
  const { isAuthenticated, isLoading, user } = useAuth0();

  if (isLoading) return <Loading />;

  return isAuthenticated ? (
    <AuthenticatedApp user={user} />
  ) : (
    <LoginPage />
  );
}
```

---

### Protected Routes

**Before (typical pattern):**
```typescript
// Old provider pattern
function ProtectedRoute({ children }) {
  const user = useCurrentUser();
  return user ? children : <Redirect to="/login" />;
}
```

**After (Auth0):**
```typescript
import { useAuth0 } from '@auth0/auth0-react';

function ProtectedRoute({ children }) {
  const { isAuthenticated, isLoading, loginWithRedirect } = useAuth0();

  if (isLoading) return <Loading />;

  if (!isAuthenticated) {
    loginWithRedirect();
    return null;
  }

  return children;
}
```

---

### API Token Retrieval

**Before (typical pattern):**
```typescript
// Old provider pattern
const token = await user.getIdToken();
fetch('/api/data', { headers: { Authorization: `Bearer ${token}` } });
```

**After (Auth0):**
```typescript
import { useAuth0 } from '@auth0/auth0-react';

function ApiComponent() {
  const { getAccessTokenSilently } = useAuth0();

  const callApi = async () => {
    const token = await getAccessTokenSilently();
    const response = await fetch('/api/data', {
      headers: { Authorization: `Bearer ${token}` }
    });
    return response.json();
  };
}
```

---

## Next.js Migration

### Middleware Protection

**Before (typical pattern):**
```typescript
// Old provider middleware pattern
export function middleware(request) {
  const session = getSession(request);
  if (!session) return redirect('/login');
}
```

**After (Auth0):**
```typescript
// middleware.ts
import { withMiddlewareAuthRequired } from '@auth0/nextjs-auth0/edge';

export default withMiddlewareAuthRequired();

export const config = {
  matcher: ['/dashboard/:path*', '/api/protected/:path*']
};
```

---

### Server Components (App Router)

**Before (typical pattern):**
```typescript
// Old provider pattern
async function DashboardPage() {
  const session = await getServerSession();
  if (!session) redirect('/login');

  return <div>Welcome {session.user.name}</div>;
}
```

**After (Auth0):**
```typescript
import { getSession } from '@auth0/nextjs-auth0';

async function DashboardPage() {
  const session = await getSession();
  if (!session) redirect('/api/auth/login');

  return <div>Welcome {session.user.name}</div>;
}
```

---

### API Routes

**Before (typical pattern):**
```typescript
// Old provider pattern
export async function GET(request) {
  const session = await getSession(request);
  if (!session) return new Response('Unauthorized', { status: 401 });

  return Response.json({ data: 'protected' });
}
```

**After (Auth0):**
```typescript
import { withApiAuthRequired, getSession } from '@auth0/nextjs-auth0';

export const GET = withApiAuthRequired(async function handler(req) {
  const session = await getSession();
  return Response.json({ data: 'protected' });
});
```

---

## Express.js Migration

### Server-Side Session Auth

**Before (typical pattern):**
```typescript
// Old provider pattern with manual session
app.post('/login', async (req, res) => {
  const user = await validateCredentials(req.body);
  req.session.user = user;
  res.redirect('/dashboard');
});

app.get('/dashboard', (req, res) => {
  if (!req.session.user) return res.redirect('/login');
  // ...
});
```

**After (Auth0):**
```typescript
const { auth, requiresAuth } = require('express-openid-connect');

app.use(auth({
  authRequired: false,
  auth0Logout: true,
  secret: process.env.AUTH0_SECRET,
  baseURL: process.env.AUTH0_BASE_URL,
  clientID: process.env.AUTH0_CLIENT_ID,
  issuerBaseURL: process.env.AUTH0_ISSUER_BASE_URL
}));

// Auth0 handles /login, /logout, /callback automatically
app.get('/dashboard', requiresAuth(), (req, res) => {
  // req.oidc.user contains the authenticated user
  res.render('dashboard', { user: req.oidc.user });
});
```

---

### Express API Route Protection

**Before (typical pattern):**
```typescript
// Old provider pattern
app.get('/api/data', async (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  const user = await verifyToken(token);

  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  res.json({ data: 'protected' });
});
```

**After (Auth0):**
```typescript
const { auth } = require('express-oauth2-jwt-bearer');

const checkJwt = auth({
  audience: process.env.AUTH0_AUDIENCE,
  issuerBaseURL: process.env.AUTH0_ISSUER_BASE_URL
});

app.get('/api/data', checkJwt, (req, res) => {
  // req.auth contains verified token claims
  res.json({ data: 'protected' });
});
```

---

## Vue.js Migration

### Authentication

**Before (typical pattern):**
```vue
<script setup>
import { onMounted, ref } from 'vue';

const user = ref(null);

onMounted(async () => {
  user.value = await getCurrentUser();
});

const login = async () => {
  await signIn();
};

const logout = async () => {
  await signOut();
};
</script>
```

**After (Auth0):**
```vue
<script setup>
import { useAuth0 } from '@auth0/auth0-vue';

const { user, isAuthenticated, isLoading, loginWithRedirect, logout } = useAuth0();
</script>

<template>
  <div v-if="isLoading">Loading...</div>
  <div v-else-if="isAuthenticated">
    <p>Welcome {{ user.name }}</p>
    <button @click="logout({ logoutParams: { returnTo: window.location.origin }})">
      Logout
    </button>
  </div>
  <button v-else @click="loginWithRedirect()">Login</button>
</template>
```

---

### Vue Router Guards

**Before (typical pattern):**
```typescript
// Old provider pattern
router.beforeEach(async (to, from, next) => {
  const user = await getCurrentUser();

  if (to.meta.requiresAuth && !user) {
    next('/login');
  } else {
    next();
  }
});
```

**After (Auth0):**
```typescript
import { createAuthGuard } from '@auth0/auth0-vue';

router.beforeEach(createAuthGuard((to) => {
  if (to.meta.requiresAuth) {
    return true; // Requires authentication
  }
  return false; // Public route
}));
```

---

## Angular Migration

### Authentication Service

**Before (typical pattern):**
```typescript
// Old provider pattern
@Injectable({ providedIn: 'root' })
export class AuthService {
  async login() {
    return await signIn();
  }

  async logout() {
    return await signOut();
  }

  getCurrentUser() {
    return this.currentUser$;
  }
}
```

**After (Auth0):**
```typescript
import { AuthService } from '@auth0/auth0-angular';
import { inject } from '@angular/core';

@Component({
  selector: 'app-auth',
  template: `
    <div *ngIf="auth.isAuthenticated$ | async; else loggedOut">
      <p>Welcome {{ (auth.user$ | async)?.name }}</p>
      <button (click)="logout()">Logout</button>
    </div>
    <ng-template #loggedOut>
      <button (click)="login()">Login</button>
    </ng-template>
  `
})
export class AuthComponent {
  auth = inject(AuthService);

  login() {
    this.auth.loginWithRedirect();
  }

  logout() {
    this.auth.logout({ logoutParams: { returnTo: window.location.origin } });
  }
}
```

---

### Route Guards

**Before (typical pattern):**
```typescript
// Old provider pattern
@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {
  canActivate(): boolean {
    const user = this.authService.currentUser;
    if (!user) {
      this.router.navigate(['/login']);
      return false;
    }
    return true;
  }
}
```

**After (Auth0):**
```typescript
import { inject } from '@angular/core';
import { AuthGuard } from '@auth0/auth0-angular';

const routes: Routes = [
  {
    path: 'dashboard',
    component: DashboardComponent,
    canActivate: [AuthGuard]
  }
];
```

---

### HTTP Interceptor

**Before (typical pattern):**
```typescript
// Old provider pattern
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler) {
    const token = this.authService.getToken();

    if (token) {
      req = req.clone({
        setHeaders: { Authorization: `Bearer ${token}` }
      });
    }

    return next.handle(req);
  }
}
```

**After (Auth0):**
```typescript
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { authHttpInterceptorFn } from '@auth0/auth0-angular';

export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(
      withInterceptors([authHttpInterceptorFn])
    )
  ]
};
```

---

## React Native Migration

### Authentication

**Before (typical pattern):**
```typescript
// Old provider pattern
const [user, setUser] = useState(null);

const login = async () => {
  const result = await signIn();
  setUser(result.user);
};

const logout = async () => {
  await signOut();
  setUser(null);
};
```

**After (Auth0):**
```typescript
import Auth0 from 'react-native-auth0';

const auth0 = new Auth0({
  domain: process.env.AUTH0_DOMAIN,
  clientId: process.env.AUTH0_CLIENT_ID
});

const [user, setUser] = useState(null);

const login = async () => {
  try {
    const credentials = await auth0.webAuth.authorize({
      scope: 'openid profile email'
    });
    setUser(credentials.idTokenPayload);
  } catch (error) {
    console.error('Login error:', error);
  }
};

const logout = async () => {
  try {
    await auth0.webAuth.clearSession();
    setUser(null);
  } catch (error) {
    console.error('Logout error:', error);
  }
};
```

---

## Backend API JWT Validation

### Node.js / Express

**Before (typical pattern):**
```typescript
// Old provider pattern
import jwt from 'jsonwebtoken';

const verifyToken = (token) => {
  return jwt.verify(token, process.env.JWT_SECRET, {
    algorithms: ['HS256']
  });
};

app.get('/api/protected', async (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  const user = verifyToken(token);
  res.json({ data: 'protected' });
});
```

**After (Auth0):**
```typescript
import jwt from 'jsonwebtoken';
import { JwksClient } from 'jwks-rsa';

const client = new JwksClient({
  jwksUri: `https://${process.env.AUTH0_DOMAIN}/.well-known/jwks.json`
});

async function validateToken(token) {
  const decoded = jwt.decode(token, { complete: true });
  const key = await client.getSigningKey(decoded.header.kid);

  return jwt.verify(token, key.getPublicKey(), {
    algorithms: ['RS256'],
    audience: process.env.AUTH0_AUDIENCE,
    issuer: `https://${process.env.AUTH0_DOMAIN}/`
  });
}

app.get('/api/protected', async (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  const user = await validateToken(token);
  res.json({ data: 'protected' });
});
```

**Key Differences:**
- **Algorithm:** HS256 (symmetric) → RS256 (asymmetric)
- **Secret:** Shared secret → Public key from JWKS endpoint
- **Issuer:** Custom → Auth0 tenant URL
- **Audience:** Optional → Required for API validation

---

### Python / Flask

**Before (typical pattern):**
```python
# Old provider pattern
import jwt

def verify_token(token):
    return jwt.decode(token, SECRET_KEY, algorithms=['HS256'])

@app.route('/api/protected')
def protected():
    token = request.headers.get('Authorization').split(' ')[1]
    user = verify_token(token)
    return {'data': 'protected'}
```

**After (Auth0):**
```python
from jose import jwt
import requests

def get_jwks():
    jwks_url = f"https://{AUTH0_DOMAIN}/.well-known/jwks.json"
    return requests.get(jwks_url).json()

def verify_token(token):
    jwks = get_jwks()
    unverified_header = jwt.get_unverified_header(token)

    # Find the key
    rsa_key = {}
    for key in jwks['keys']:
        if key['kid'] == unverified_header['kid']:
            rsa_key = {
                'kty': key['kty'],
                'kid': key['kid'],
                'use': key['use'],
                'n': key['n'],
                'e': key['e']
            }

    return jwt.decode(
        token,
        rsa_key,
        algorithms=['RS256'],
        audience=AUTH0_AUDIENCE,
        issuer=f"https://{AUTH0_DOMAIN}/"
    )

@app.route('/api/protected')
def protected():
    token = request.headers.get('Authorization').split(' ')[1]
    user = verify_token(token)
    return {'data': 'protected'}
```

---

## Provider-Specific Patterns

### Firebase to Auth0

**Common Firebase patterns:**
```typescript
// Firebase
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';

const auth = getAuth();
const userCredential = await signInWithEmailAndPassword(auth, email, password);
const user = userCredential.user;
```

**Auth0 equivalent:**
```typescript
// Auth0 - uses redirect flow, not direct credentials
import { useAuth0 } from '@auth0/auth0-react';

const { loginWithRedirect } = useAuth0();
await loginWithRedirect();
```

**Note:** Auth0 uses Universal Login (redirect), not direct email/password submission for better security.

---

### Supabase to Auth0

**Common Supabase patterns:**
```typescript
// Supabase
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(url, key);
const { data, error } = await supabase.auth.signInWithPassword({ email, password });
```

**Auth0 equivalent:**
```typescript
// Auth0
import { useAuth0 } from '@auth0/auth0-react';

const { loginWithRedirect } = useAuth0();
await loginWithRedirect();
```

---

### Clerk to Auth0

**Common Clerk patterns:**
```typescript
// Clerk
import { useUser, useSignIn } from '@clerk/nextjs';

const { isSignedIn, user } = useUser();
const { signIn } = useSignIn();
```

**Auth0 equivalent:**
```typescript
// Auth0
import { useUser } from '@auth0/nextjs-auth0/client';

const { user, error, isLoading } = useUser();
const login = () => window.location.href = '/api/auth/login';
```

---

## References

- [Auth0 React SDK](https://auth0.com/docs/libraries/auth0-react)
- [Auth0 Next.js SDK](https://auth0.com/docs/libraries/nextjs)
- [Auth0 Vue SDK](https://auth0.com/docs/libraries/auth0-vue)
- [Auth0 Angular SDK](https://auth0.com/docs/libraries/auth0-angular)
- [Auth0 React Native SDK](https://auth0.com/docs/libraries/react-native-auth0)
- [Express OpenID Connect](https://auth0.com/docs/libraries/express-openid-connect)
