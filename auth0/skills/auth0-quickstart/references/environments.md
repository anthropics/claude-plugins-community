# Environment Variables Reference

Environment variable configuration for Auth0 across different frameworks and application types.

---

## Single Page Applications (SPAs)

### Vite (React, Vue, Svelte)

Create `.env`:

```bash
VITE_AUTH0_DOMAIN=<your-tenant>.auth0.com
VITE_AUTH0_CLIENT_ID=<your-client-id>
```

**Usage in code:**
```javascript
const domain = import.meta.env.VITE_AUTH0_DOMAIN;
const clientId = import.meta.env.VITE_AUTH0_CLIENT_ID;
```

**Important:**
- Vite requires `VITE_` prefix
- Use `import.meta.env`, NOT `process.env`
- Restart dev server after changing `.env`

---

### Create React App

Create `.env`:

```bash
REACT_APP_AUTH0_DOMAIN=<your-tenant>.auth0.com
REACT_APP_AUTH0_CLIENT_ID=<your-client-id>
```

**Usage in code:**
```javascript
const domain = process.env.REACT_APP_AUTH0_DOMAIN;
const clientId = process.env.REACT_APP_AUTH0_CLIENT_ID;
```

**Important:**
- Create React App requires `REACT_APP_` prefix
- Use `process.env`
- Restart dev server after changing `.env`

---

### Angular

Update `src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  auth0: {
    domain: '<your-tenant>.auth0.com',
    clientId: '<your-client-id>',
    authorizationParams: {
      redirect_uri: window.location.origin
    }
  }
};
```

Update `src/environments/environment.prod.ts`:

```typescript
export const environment = {
  production: true,
  auth0: {
    domain: '<your-tenant>.auth0.com',
    clientId: '<your-client-id>',
    authorizationParams: {
      redirect_uri: 'https://myapp.com'
    }
  }
};
```

**Usage in code:**
```typescript
import { environment } from '../environments/environment';

const domain = environment.auth0.domain;
```

---

## Server-Side Applications

### Next.js

Create `.env.local`:

```bash
AUTH0_SECRET='<use-openssl-rand-hex-32-to-generate>'
AUTH0_BASE_URL='http://localhost:3000'
AUTH0_ISSUER_BASE_URL='https://<your-tenant>.auth0.com'
AUTH0_CLIENT_ID='<your-client-id>'
AUTH0_CLIENT_SECRET='<your-client-secret>'
```

**Generate AUTH0_SECRET:**
```bash
openssl rand -hex 32
```

**Usage in code:**
```javascript
// Automatic via @auth0/nextjs-auth0
// No manual import needed
```

**Important:**
- File must be named `.env.local` (not `.env`)
- Add `.env.local` to `.gitignore`
- `AUTH0_SECRET` must be 32+ characters
- In production, set these as environment variables in your hosting platform

**Production (.env.production):**
```bash
AUTH0_SECRET='<different-secret-from-dev>'
AUTH0_BASE_URL='https://myapp.com'
AUTH0_ISSUER_BASE_URL='https://<your-tenant>.auth0.com'
AUTH0_CLIENT_ID='<your-client-id>'
AUTH0_CLIENT_SECRET='<your-client-secret>'
```

---

### Express.js

Create `.env`:

```bash
AUTH0_SECRET='<use-openssl-rand-hex-32-to-generate>'
AUTH0_BASE_URL='http://localhost:3000'
AUTH0_ISSUER_BASE_URL='https://<your-tenant>.auth0.com'
AUTH0_CLIENT_ID='<your-client-id>'
AUTH0_CLIENT_SECRET='<your-client-secret>'
```

**Usage in code:**
```javascript
require('dotenv').config();

const { auth } = require('express-openid-connect');

app.use(auth({
  secret: process.env.AUTH0_SECRET,
  baseURL: process.env.AUTH0_BASE_URL,
  clientID: process.env.AUTH0_CLIENT_ID,
  issuerBaseURL: process.env.AUTH0_ISSUER_BASE_URL,
  clientSecret: process.env.AUTH0_CLIENT_SECRET
}));
```

**Important:**
- Install `dotenv`: `npm install dotenv`
- Add `.env` to `.gitignore`
- Load dotenv at app entry point: `require('dotenv').config()`

---

## Mobile Applications

### React Native (Expo)

**Using Expo:**

Update `app.json`:

```json
{
  "expo": {
    "extra": {
      "auth0Domain": "<your-tenant>.auth0.com",
      "auth0ClientId": "<your-client-id>"
    }
  }
}
```

**Usage in code:**
```javascript
import Constants from 'expo-constants';

const domain = Constants.expoConfig.extra.auth0Domain;
const clientId = Constants.expoConfig.extra.auth0ClientId;
```

---

### React Native (CLI)

Create `.env`:

```bash
AUTH0_DOMAIN=<your-tenant>.auth0.com
AUTH0_CLIENT_ID=<your-client-id>
```

**Using react-native-config:**

```bash
npm install react-native-config
```

**Usage in code:**
```javascript
import Config from 'react-native-config';

const domain = Config.AUTH0_DOMAIN;
const clientId = Config.AUTH0_CLIENT_ID;
```

---

### Alternative: Config File

Create `auth0.config.js`:

```javascript
export default {
  domain: '<your-tenant>.auth0.com',
  clientId: '<your-client-id>'
};
```

**Usage:**
```javascript
import auth0Config from './auth0.config';
```

**Important:**
- Add `auth0.config.js` to `.gitignore`
- Create `auth0.config.example.js` as template

---

## API Protection (Backend)

### Node.js / Express API

Create `.env`:

```bash
AUTH0_AUDIENCE='https://api.myapp.com'
AUTH0_ISSUER_BASE_URL='https://<your-tenant>.auth0.com'
```

**Usage:**
```javascript
const { auth } = require('express-oauth2-jwt-bearer');

const checkJwt = auth({
  audience: process.env.AUTH0_AUDIENCE,
  issuerBaseURL: process.env.AUTH0_ISSUER_BASE_URL
});

app.get('/api/protected', checkJwt, (req, res) => {
  res.json({ message: 'Protected endpoint' });
});
```

---

### Python / Flask API

Create `.env`:

```bash
AUTH0_DOMAIN=<your-tenant>.auth0.com
AUTH0_AUDIENCE=https://api.myapp.com
```

**Usage:**
```python
import os
from dotenv import load_dotenv

load_dotenv()

AUTH0_DOMAIN = os.getenv('AUTH0_DOMAIN')
AUTH0_AUDIENCE = os.getenv('AUTH0_AUDIENCE')
```

---

## Security Best Practices

### ✅ DO

- **Use environment variables** for all secrets
- **Add `.env` files to `.gitignore`** immediately
- **Create `.env.example`** with placeholder values for team
- **Use different secrets** for development and production
- **Rotate secrets regularly** (every 90 days recommended)
- **Use strong AUTH0_SECRET** (32+ random characters)

### ❌ DON'T

- **Never commit `.env` files** to version control
- **Never hardcode credentials** in source code
- **Never use same secrets** across environments
- **Never share secrets** via Slack/email/chat
- **Never use weak secrets** like "secret123"

---

## Example `.env.example`

Create this file to help team members:

```bash
# Auth0 Configuration
# Get these from: https://manage.auth0.com/dashboard

AUTH0_SECRET='use-openssl-rand-hex-32-to-generate'
AUTH0_BASE_URL='http://localhost:3000'
AUTH0_ISSUER_BASE_URL='https://YOUR-TENANT.auth0.com'
AUTH0_CLIENT_ID='YOUR-CLIENT-ID'
AUTH0_CLIENT_SECRET='YOUR-CLIENT-SECRET'

# Optional: API Configuration
AUTH0_AUDIENCE='https://api.myapp.com'
```

---

## Troubleshooting

### Variables Not Loading

**Symptoms:**
- `undefined` when accessing environment variables
- Auth fails with "domain is required" errors

**Solutions:**

1. **Restart dev server** after changing `.env`
2. **Check variable prefix** (VITE_, REACT_APP_, etc.)
3. **Verify file name** (.env vs .env.local)
4. **Check file location** (must be in project root)
5. **Load dotenv** for Node.js: `require('dotenv').config()`

### Wrong Import Method

**Vite:**
```javascript
// ❌ Wrong
process.env.VITE_AUTH0_DOMAIN

// ✅ Correct
import.meta.env.VITE_AUTH0_DOMAIN
```

**Create React App:**
```javascript
// ❌ Wrong
import.meta.env.REACT_APP_AUTH0_DOMAIN

// ✅ Correct
process.env.REACT_APP_AUTH0_DOMAIN
```

---

## References

- [Vite Environment Variables](https://vitejs.dev/guide/env-and-mode.html)
- [Create React App Environment Variables](https://create-react-app.dev/docs/adding-custom-environment-variables/)
- [Next.js Environment Variables](https://nextjs.org/docs/basic-features/environment-variables)
- [Expo Environment Variables](https://docs.expo.dev/guides/environment-variables/)
- [dotenv Documentation](https://github.com/motdotla/dotenv)
