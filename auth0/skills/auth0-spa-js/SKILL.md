---
name: auth0-spa-js
description: >
  Use when adding Auth0 login or token management to a Vanilla JS, Svelte, or framework-agnostic SPA. Integrates @auth0/auth0-spa-js — use when there is no framework-specific Auth0 SDK available.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 SPA JS Integration

Add authentication to any browser-based single-page application using `@auth0/auth0-spa-js` — the low-level Auth0 SDK for Vanilla JS, Svelte, SolidJS, and any SPA not using React, Angular, or Vue.

> **Agent instruction:** Before providing SDK setup instructions, fetch the latest release version by running:
> ```
> gh api repos/auth0/auth0-spa-js/releases/latest --jq '.tag_name'
> ```
> Use the returned version in all dependency lines instead of any hardcoded version below. If the command fails, fall back to checking https://github.com/auth0/auth0-spa-js/releases.

## Prerequisites

- Modern browser with ES2017+ support
- npm or yarn (or use CDN for no-bundler apps)
- Auth0 account with a Single Page Application configured
- If you don't have Auth0 set up, see [auth0-quickstart](/auth0-quickstart)

## When NOT to Use

- **React SPAs** (hooks, Auth0Provider): Use [auth0-react](/auth0-react)
- **Angular SPAs** (AuthModule, AuthGuard): Use [auth0-angular](/auth0-angular)
- **Vue 3 SPAs** (createAuth0, useAuth0): Use [auth0-vue](/auth0-vue)
- **Next.js** (server-side sessions, App Router): Use [auth0-nextjs](/auth0-nextjs)
- **Nuxt** (server-side SSR): Use [auth0-nuxt](/auth0-nuxt)
- **Express server-side web apps**: Use [auth0-express](/auth0-express)
- **React Native / Expo mobile apps**: Use [auth0-react-native](/auth0-react-native)

## Quick Start Workflow

### 1. Install SDK

```bash
npm install @auth0/auth0-spa-js
```

Or via CDN (no bundler). Run this to get the latest version, then use it in your HTML:
```bash
VERSION=$(npm view @auth0/auth0-spa-js version)
```
```html
<script src="https://cdn.auth0.com/js/auth0-spa-js/$VERSION/auth0-spa-js.production.js"></script>
```

### 2. Configure Auth0

**For automated setup with Auth0 CLI**, see [Setup Guide](references/setup.md) for complete scripts.

**For manual setup**, create `.env` (Vite):

```bash
VITE_AUTH0_DOMAIN=your-tenant.auth0.com
VITE_AUTH0_CLIENT_ID=your-client-id
```

In Auth0 Dashboard, set for your **Single Page Application**:
- **Allowed Callback URLs**: `http://localhost:5173`
- **Allowed Logout URLs**: `http://localhost:5173`
- **Allowed Web Origins**: `http://localhost:5173`

### 3. Initialize Auth0 Client

```js
import { createAuth0Client } from '@auth0/auth0-spa-js';

const auth0 = await createAuth0Client({
  domain: import.meta.env.VITE_AUTH0_DOMAIN,
  clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
  authorizationParams: {
    redirect_uri: window.location.origin
  }
});

// Handle redirect callback after login
const query = new URLSearchParams(window.location.search);
if ((query.has('code') || query.has('error')) && query.has('state')) {
  await auth0.handleRedirectCallback();
  window.history.replaceState({}, document.title, window.location.pathname);
}
```

### 4. Add Login / Logout

> **Agent instruction:** Before adding new UI elements, search the project for existing click handlers for login, logout, sign-in, or sign-out buttons. If existing handlers are found, hook the Auth0 code into them without modifying the existing UI. Only create new buttons if no existing handlers are found.

```js
// Login
document.getElementById('login-btn').addEventListener('click', async () => {
  await auth0.loginWithRedirect();
});

// Logout
document.getElementById('logout-btn').addEventListener('click', () => {
  auth0.logout({
    logoutParams: { returnTo: window.location.origin }
  });
});

// Update UI based on auth state
const isAuthenticated = await auth0.isAuthenticated();
if (isAuthenticated) {
  const user = await auth0.getUser();
  console.log(user.name, user.email);
}
```

### 5. Get Access Tokens for API Calls

```js
const accessToken = await auth0.getTokenSilently();

const response = await fetch('https://your-api.example.com/data', {
  headers: { Authorization: `Bearer ${accessToken}` }
});
```

### 6. Build & Verify

> **Agent instruction:** After completing the integration, build the project to verify it compiles successfully:
> ```bash
> npm run build
> ```
> If the build fails, analyze the error output and fix the issues. Common integration build failures include:
> - **Module not found**: Missing `npm install @auth0/auth0-spa-js` — run the install command
> - **Cannot find name 'import.meta'**: TypeScript target too low — set `"target": "ES2020"` or higher in `tsconfig.json`
> - **`createAuth0Client` is not a function**: Wrong import path or CDN usage without bundle step
> - **Env vars undefined at runtime**: Vite requires `VITE_` prefix; webpack/CRA requires `REACT_APP_` prefix
>
> Re-run the build after each fix. Track the number of build-fix iterations.
>
> **Failcheck:** If the build still fails after 5–6 fix attempts, stop and ask the user using `AskUserQuestion`:
> _"The build is still failing after several fix attempts. How would you like to proceed?"_
> - **Let the skill continue fixing iteratively** — continue the build-fix loop for another 5–6 attempts
> - **Fix it manually** — show the remaining errors and let the user resolve them
> - **Skip build verification** — proceed without a successful build

## Detailed Documentation

- [**Setup Guide**](references/setup.md) — Automated setup scripts (Bash/PowerShell), Auth0 CLI commands, `.env` configuration, callback URL setup
- [**Integration Patterns**](references/integration.md) — Token management, calling APIs, refresh tokens, organizations, MFA, DPoP, error handling, advanced patterns
- [**Testing & Reference**](references/api.md) — Configuration options, claims reference, testing checklist, common issues, security considerations

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Callback URL port mismatch (e.g., `localhost:3001` vs `localhost:5173`) | Match Allowed Callback URLs exactly to your dev server port in Auth0 Dashboard |
| `client_secret` in SPA code | SPAs must never have a client secret — remove it. Auth0 sets auth method to `None` for SPA apps |
| Tokens stored in `localStorage` | Use in-memory storage (default) or `sessionStorage`. Never `localStorage` — XSS risk |
| `getTokenSilently()` throws `login_required` on page refresh | Add your app origin to **Allowed Web Origins** in Auth0 Dashboard |
| `handleRedirectCallback()` not called after redirect | Must call after login redirect to exchange the auth code; without this the URL params persist and re-trigger |
| Domain includes `https://` prefix | Auth0 domain should be hostname only: `your-tenant.auth0.com`, not `https://your-tenant.auth0.com` |
| `loginWithPopup()` called from async init code | Popups must be triggered directly from a user gesture (click handler). Never call from init or page load code |
| Using `Auth0Provider` from `@auth0/auth0-react` in Vanilla JS | For Vanilla JS, use `createAuth0Client()` directly — no provider component needed |

## Related Skills

- [auth0-quickstart](/auth0-quickstart) — Set up an Auth0 account and application
- [auth0-react](/auth0-react) — Auth0 for React SPAs with hooks
- [auth0-angular](/auth0-angular) — Auth0 for Angular SPAs
- [auth0-vue](/auth0-vue) — Auth0 for Vue 3 SPAs
- [auth0-mfa](/auth0-mfa) — Add Multi-Factor Authentication
- [auth0-cli](/auth0-cli) — Manage Auth0 resources from the terminal

## Quick Reference

### Core Methods

| Method | Description |
|--------|-------------|
| `createAuth0Client(options)` | Create and initialize client (calls `checkSession` internally) |
| `new Auth0Client(options)` | Instantiate without auto session check |
| `auth0.loginWithRedirect(options?)` | Redirect to Auth0 Universal Login |
| `auth0.loginWithPopup(options?)` | Open Auth0 login in a popup |
| `auth0.logout(options?)` | Clear session and redirect |
| `auth0.handleRedirectCallback(url?)` | Process redirect result after login |
| `auth0.isAuthenticated()` | `Promise<boolean>` |
| `auth0.getUser()` | `Promise<User \| undefined>` |
| `auth0.getTokenSilently(options?)` | `Promise<string>` — access token |
| `auth0.checkSession()` | Attempt silent re-authentication |

### Common Use Cases

- Login/Logout → See Step 4 above
- Protecting content → [Integration Guide](references/integration.md#protecting-content)
- API calls with tokens → [Integration Guide](references/integration.md#calling-protected-apis)
- Refresh tokens → [Integration Guide](references/integration.md#refresh-token-rotation)
- Organizations → [Integration Guide](references/integration.md#organizations)
- MFA handling → [Integration Guide](references/integration.md#mfa-handling)
- Error handling → [Integration Guide](references/integration.md#error-handling)

## References

- [Auth0 SPA JS SDK Documentation](https://auth0.com/docs/libraries/auth0-spa-js)
- [Auth0 Vanilla JS Quickstart](https://auth0.com/docs/quickstart/spa/vanillajs)
- [SDK GitHub Repository](https://github.com/auth0/auth0-spa-js)
- [EXAMPLES.md — Advanced patterns](https://github.com/auth0/auth0-spa-js/blob/main/EXAMPLES.md)
- [API Documentation](https://auth0.github.io/auth0-spa-js/)
