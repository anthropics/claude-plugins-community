# Auth0 Ionic React (Capacitor) — Setup Guide

## Auth0 Configuration

> **Agent instruction:**
>
> **IMPORTANT — Never display credentials:** After obtaining credentials from the CLI or user input, write them directly into config files. Do NOT echo, print, or display the domain, client ID, or any credential values in conversation output.
>
> Always ask the user to choose between automatic and manual setup using `AskUserQuestion`:
> _"How would you like to configure Auth0 for this Ionic React project?"_
>   - **Automatic setup (Recommended)** — uses the Auth0 CLI to create a Native application, configure callback URLs, and store credentials in the project config files automatically
>   - **Manual setup** — you provide an existing `.env` file or Auth0 credentials (domain, client ID) and the agent writes them to the project config

### Automatic Setup (Auth0 CLI)

> **Agent instruction:** Run these pre-flight checks before creating the Auth0 application. Do NOT run `auth0 login` from the agent — it is interactive and will hang.
>
> 1. **Check Auth0 CLI**: `command -v auth0`. If missing, install it: `brew install auth0/auth0-cli/auth0`.
> 2. **Check Auth0 login**: `auth0 tenants list --csv --no-input 2>&1`. If it fails or returns empty:
>    - Tell the user: _"Please run `auth0 login` in your terminal and let me know when done."_
>    - Wait for confirmation, then re-run the check. Retry up to 3 times before treating as a persistent failure.
> 3. **Confirm active tenant**: Parse the `→` line from the CSV output. Tell the user: _"Your active Auth0 tenant is: `<domain>`. Is this correct?"_
>    - If no, ask the user to run `auth0 tenants use <tenant-domain>`, then re-run step 2.
>
> Once confirmed, run the following steps:
>
> **Step A — Detect package ID:**
> Read `capacitor.config.ts` (or `capacitor.config.json`) and extract the `appId` field (e.g., `com.example.myapp`).
>
> **Step B — Create Native application:**
> ```bash
> auth0 apps create \
>   --name "APP_NAME" \
>   --type native \
>   --auth-method None \
>   --callbacks "PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback" \
>   --logout-urls "PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback" \
>   --origins "capacitor://localhost,http://localhost" \
>   --json \
>   --no-input
> ```
> Parse the JSON output to extract `client_id` and `domain` (the tenant domain).
>
> **Step C — Write credentials to config files (never display them):**
> Write the `client_id` and `domain` from Step B directly into the project `.env` file. Detect whether the project uses Vite (`VITE_` prefix) or CRA (`REACT_APP_` prefix) and use the appropriate variable names. **Do NOT echo, print, or display the domain, client ID, or any credential values in your conversation output.** Simply confirm that the Auth0 app was created and credentials were saved, without showing the actual values.
>
> If any CLI command fails due to session expiry, ask the user to run `auth0 login` again, then retry. Retry up to 3 times.
> Only if the CLI keeps failing after retries: fall back to **Manual Setup** below.

### Manual Setup (User-Provided Configuration)

> **Agent instruction:** Ask the user to provide their Auth0 configuration. Accept either:
> - **An `.env` file path** — read the file to extract the Auth0 domain and client ID, then copy or reference it in the project.
> - **Direct credentials** — ask using `AskUserQuestion`: _"Please provide your Auth0 Domain and Client ID."_
>
> Once credentials are obtained, write them to the project `.env` file. Detect whether the project uses Vite (`VITE_` prefix) or CRA (`REACT_APP_` prefix) and use the appropriate variable names. **Do NOT display the credentials in conversation output.**

### Callback URL Format

| Field | Value |
|-------|-------|
| **Allowed Callback URLs** | `YOUR_PACKAGE_ID://YOUR_DOMAIN/capacitor/YOUR_PACKAGE_ID/callback` |
| **Allowed Logout URLs** | `YOUR_PACKAGE_ID://YOUR_DOMAIN/capacitor/YOUR_PACKAGE_ID/callback` |
| **Allowed Web Origins** | `capacitor://localhost, http://localhost` |

Replace `YOUR_PACKAGE_ID` with your app's package ID (e.g., `com.example.myapp`) and `YOUR_DOMAIN` with your Auth0 domain. These are set automatically when using the CLI commands above.

## SDK Installation

```bash
npm install @auth0/auth0-react @capacitor/browser @capacitor/app
npx cap sync
```

### Plugin purposes

| Package | Purpose |
|---------|---------|
| `@auth0/auth0-react` | Auth0 React SDK — provides `Auth0Provider` and `useAuth0` hook |
| `@capacitor/browser` | Opens Auth0 Universal Login in system browser (SFSafariViewController / Chrome Custom Tabs) |
| `@capacitor/app` | Handles deep link callbacks from Auth0 after login/logout |

## Post-Setup Steps

### 1. Verify Capacitor Configuration

Ensure `capacitor.config.ts` has the correct `appId`:

```typescript
import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.myapp', // Must match YOUR_PACKAGE_ID in callback URLs
  appName: 'My App',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  }
};

export default config;
```

### 2. Sync Native Projects

After installing plugins, always sync:

```bash
npx cap sync
```

### 3. Verify Platform Setup

**iOS:** Open the iOS project to verify:
```bash
npx cap open ios
```
Ensure the Bundle Identifier in Xcode matches `appId` in `capacitor.config.ts`.

**Android:** Open the Android project to verify:
```bash
npx cap open android
```
Ensure `applicationId` in `android/app/build.gradle` matches `appId` in `capacitor.config.ts`.

## Secret Management

**Ionic React + Capacitor apps are Native applications** — they do not use a client secret.

- Configuration contains only: **Domain**, **Client ID**, and **Callback URL**
- These values are not secrets and can be included in source code
- Token validation uses PKCE (Proof Key for Code Exchange) — no client secret needed
- Never include a client secret in a mobile/native application

### Environment Variables (Optional)

If you prefer environment variables for Domain and Client ID during development:

```bash
# .env (for Vite-based Ionic projects)
VITE_AUTH0_DOMAIN=your-tenant.auth0.com
VITE_AUTH0_CLIENT_ID=your-client-id

# .env (for CRA-based Ionic projects)
REACT_APP_AUTH0_DOMAIN=your-tenant.auth0.com
REACT_APP_AUTH0_CLIENT_ID=your-client-id
```

Then reference in code:
```tsx
<Auth0Provider
  domain={import.meta.env.VITE_AUTH0_DOMAIN}
  clientId={import.meta.env.VITE_AUTH0_CLIENT_ID}
  // ...
>
```

## Verification

After setup, verify the configuration:

1. Run `ionic serve` — the app should load without Auth0 errors
2. Run `ionic build && npx cap sync` — native projects should sync cleanly
3. Open in Xcode/Android Studio and build — no missing plugin errors
4. Tap login — system browser should open Auth0 Universal Login
5. After login — app should receive the deep link callback and show the user profile
