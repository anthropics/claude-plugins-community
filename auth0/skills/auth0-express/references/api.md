## Common Patterns

### Template Rendering with EJS

**Install EJS:**
```bash
npm install ejs
```

**Configure:**
```javascript
app.set('view engine', 'ejs');
```

**Create `views/index.ejs`:**
```html
<!DOCTYPE html>
<html>
<head>
  <title>My Auth0 App</title>
</head>
<body>
  <% if (isAuthenticated) { %>
    <h1>Welcome, <%= user.name %>!</h1>
    <img src="<%= user.picture %>" alt="<%= user.name %>" />
    <p><%= user.email %></p>
    <a href="/logout">Logout</a>
  <% } else { %>
    <h1>Please log in</h1>
    <a href="/login">Login</a>
  <% } %>
</body>
</html>
```

**Update route:**
```javascript
app.get('/', (req, res) => {
  res.render('index', {
    isAuthenticated: req.oidc.isAuthenticated(),
    user: req.oidc.user
  });
});
```

---

### Custom Login with Return URL

```javascript
app.get('/dashboard', requiresAuth(), (req, res) => {
  res.render('dashboard', { user: req.oidc.user });
});

// Login redirects to dashboard after authentication
app.get('/login-to-dashboard', (req, res) => {
  res.oidc.login({
    returnTo: '/dashboard'
  });
});
```

---

### Access User Information

```javascript
app.get('/user-info', requiresAuth(), (req, res) => {
  // User profile
  const user = req.oidc.user;

  // Check if authenticated
  const isAuth = req.oidc.isAuthenticated();

  // ID token
  const idToken = req.oidc.idToken;

  // ID token claims
  const idTokenClaims = req.oidc.idTokenClaims;

  res.json({
    user,
    isAuthenticated: isAuth,
    idToken: idToken
  });
});
```

---

### Call External APIs

```javascript
app.get('/call-api', requiresAuth(), async (req, res) => {
  try {
    // Extract the token string from the access token object
    const { access_token } = req.oidc.accessToken;

    const response = await fetch('https://your-api.com/data', {
      headers: {
        Authorization: `Bearer ${access_token}`
      }
    });

    const data = await response.json();
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

**Note:** To call APIs, add `authorizationParams` to middleware config:

```javascript
app.use(auth({
  authRequired: false,
  auth0Logout: true,
  secret: process.env.SECRET,
  baseURL: process.env.BASE_URL,
  clientID: process.env.CLIENT_ID,
  issuerBaseURL: process.env.ISSUER_BASE_URL,
  clientSecret: process.env.CLIENT_SECRET,
  authorizationParams: {
    response_type: 'code',
    audience: 'https://your-api-identifier',  // Add this
    scope: 'openid profile email'
  }
}));
```

---

### Custom Logout Redirect

```javascript
app.get('/custom-logout', (req, res) => {
  res.oidc.logout({
    returnTo: 'https://your-app.com/goodbye'
  });
});
```

---

### Conditional Authentication

```javascript
// Protect specific routes
app.get('/admin', requiresAuth(), (req, res) => {
  // Only authenticated users can access
  res.render('admin', { user: req.oidc.user });
});

// Optional authentication (check manually)
app.get('/home', (req, res) => {
  if (req.oidc.isAuthenticated()) {
    res.render('home-auth', { user: req.oidc.user });
  } else {
    res.render('home-public');
  }
});
```

---

## Configuration Options

### Complete Middleware Configuration

```javascript
app.use(auth({
  authRequired: false,          // Don't require auth globally
  auth0Logout: true,            // Enable logout route
  secret: process.env.SECRET,
  baseURL: process.env.BASE_URL,
  clientID: process.env.CLIENT_ID,
  issuerBaseURL: process.env.ISSUER_BASE_URL,
  clientSecret: process.env.CLIENT_SECRET,

  // Authorization parameters
  authorizationParams: {
    response_type: 'code',
    audience: 'https://your-api-identifier',
    scope: 'openid profile email'
  },

  // Custom routes
  routes: {
    login: '/auth/login',       // Default: /login
    logout: '/auth/logout',     // Default: /logout
    callback: '/auth/callback', // Default: /callback
    postLogoutRedirect: '/'     // Where to go after logout
  },

  // Session configuration
  session: {
    rolling: true,              // Extend session on activity
    rollingDuration: 86400,     // 24 hours in seconds
    absoluteDuration: 604800    // 7 days in seconds
  }
}));
```

---

## Testing

1. Start your server: `node app.js` or `npm start`
2. Visit `http://localhost:3000`
3. Click "Login" - redirects to Auth0
4. Complete authentication
5. Verify redirect back with session established
6. Visit `/profile` to see protected route
7. Click "Logout" and verify session cleared

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Missing required parameter: state" | Ensure `SECRET` is set and at least 32 characters |
| Session not persisting | Check cookies are enabled and `BASE_URL` is correct |
| Infinite redirect loop | Check `authRequired: false` for middleware config |
| Callback URL mismatch | Verify `BASE_URL/callback` is in Auth0 allowed callback URLs |
| "Invalid redirect URI" | Ensure callback URL in Auth0 matches `BASE_URL` exactly |

---

## Advanced Configuration Options

### attemptSilentLogin

Automatically attempt silent login on the first unauthenticated request. Useful for checking if user is already logged in at their IDP without showing login prompt.

```javascript
app.use(auth({
  authRequired: false,
  attemptSilentLogin: true  // Try silent auth first (default: false)
}));
```

### errorOnRequiredAuth

Return 401 error instead of redirecting to login for protected routes. Useful for API endpoints that should return status codes instead of HTML redirects.

```javascript
app.use(auth({
  errorOnRequiredAuth: true  // Return 401 instead of redirecting (default: false)
}));
```

### idpLogout

Log the user out from Auth0 (federated logout) when they log out of your application, not just the application session.

```javascript
app.use(auth({
  idpLogout: true  // Also logout from Auth0 (default: false)
}));
```

### afterCallback

Execute custom logic after authentication callback, such as fetching additional user data or modifying the session.

```javascript
app.use(auth({
  afterCallback: async (req, res, session, state) => {
    // Fetch additional user profile data
    const userProfile = await fetchUserProfile(session.user.sub);

    // Add to session
    return {
      ...session,
      userProfile  // Access via req.oidc.userProfile
    };
  }
}));
```

### getLoginState

Customize the state parameter passed during login to preserve custom application state through the authentication flow.

```javascript
app.use(auth({
  getLoginState(req, options) {
    return {
      returnTo: options.returnTo || req.originalUrl,
      customData: 'custom-value'  // Your custom state
    };
  }
}));
```

---

## Security Considerations

- **Keep secrets secure** - Never commit `.env` to version control
- **Use HTTPS in production** - Auth0 requires secure callback URLs
- **Rotate secrets regularly** - Update `SECRET` periodically
- **Validate on server** - Authentication is server-side, tokens are secure
- **Configure session properly** - Set appropriate session durations
- **Use helmet** - Add security headers with `npm install helmet`

```javascript
const helmet = require('helmet');
app.use(helmet());
```

---

## Related Skills

- `auth0-quickstart` - Initial Auth0 account setup
- `auth0-migration` - Migrate from another auth provider
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-organizations` - B2B multi-tenancy support

---

## References

- [express-openid-connect Documentation](https://auth0.com/docs/libraries/express-openid-connect)
- [express-openid-connect GitHub](https://github.com/auth0/express-openid-connect)
- [Auth0 Express Quickstart](https://auth0.com/docs/quickstart/webapp/express)
- [Express.js Documentation](https://expressjs.com/)
