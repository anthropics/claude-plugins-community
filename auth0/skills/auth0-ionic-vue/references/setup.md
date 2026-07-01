# Auth0 Ionic Vue (Capacitor) — Setup Guide

## Auth0 Configuration

> **Agent instruction:**
>
> **IMPORTANT — Never display credentials:** After obtaining credentials from the CLI or user input, write them directly into config files. Do NOT echo, print, or display the domain, client ID, or any credential values in conversation output.
>
> Always ask the user to choose between automatic and manual setup using `AskUserQuestion`:
> _"How would you like to configure Auth0 for this Ionic Vue project?"_
>   - **Automatic setup (Recommended)** — uses the Auth0 CLI to create a Native application, configure callback URLs, and store credentials in the project `.env` file automatically
>   - **Manual setup** — you provide an existing `.env` file or Auth0 credentials (domain, client ID) and the agent writes them to the project config
>
> **If credentials are already provided in the user's prompt:** Use them directly — skip to "SDK Installation" below. Do NOT call `AskUserQuestion` to re-confirm.

### Auth0 CLI Automated Setup

> **Agent instruction:** Execute these steps in order. Do NOT run `auth0 login` from the agent — it is interactive and will hang. All other `auth0` CLI commands below are non-interactive and safe to run.
>
> ---
>
> #### Step A — Check Auth0 CLI is installed
>
> ```bash
> command -v auth0
> ```
>
> If missing, install it:
> ```bash
> brew install auth0/auth0-cli/auth0
> ```
> On Linux: `curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh`
>
> ---
>
> #### Step B — Verify Auth0 CLI login session
>
> ```bash
> auth0 tenants list --csv --no-input 2>&1
> ```
>
> - **If the command succeeds** and returns CSV output with tenant rows: proceed to Step C.
> - **If the command fails** (exit code non-zero, or output contains "login" / "unauthorized" / is empty):
>   - Tell the user: _"You're not logged in to the Auth0 CLI. Please run `auth0 login` in your terminal and let me know when done."_
>   - Use `AskUserQuestion` to wait for confirmation.
>   - After confirmation, re-run this check. Retry up to 3 times.
>   - If still failing after 3 retries: use `AskUserQuestion` to ask the user for their Auth0 Domain and Client ID manually, then skip to Step F.
>
> ---
>
> #### Step C — Detect active Auth0 tenant domain
>
> Parse the CSV output from Step B. The active tenant line contains `→` (Unicode arrow U+2192).
>
> ```
> Example output:
>   ACTIVE,DOMAIN
>   →,dev-example.us.auth0.com
>     ,dev-other.us.auth0.com
> ```
>
> Extract the domain from the second column of the `→` line (e.g., `dev-example.us.auth0.com`).
>
> Tell the user: _"Your active Auth0 tenant is: `<domain>`. Is this correct?"_
> - If no, ask the user to run `auth0 tenants use <correct-tenant-domain>`, then re-run Step B.
>
> Store this as `AUTH0_DOMAIN`.
>
> ---
>
> #### Step D — Detect package ID from Capacitor config
>
> Read `capacitor.config.ts` (or `capacitor.config.json`) in the project root:
>
> - For `.ts`: parse `appId: 'com.example.myapp'` using regex.
> - For `.json`: parse the `appId` field from JSON.
>
> Store this as `PACKAGE_ID` (e.g., `com.example.myapp`).
>
> Also extract `appName` if available (for the Auth0 app display name). Fall back to the project name from `package.json` if not found.
>
> ---
>
> #### Step E — Create Native Auth0 application
>
> Build the callback URL: `PACKAGE_ID://AUTH0_DOMAIN/capacitor/PACKAGE_ID/callback`
>
> ```bash
> auth0 apps create \
>   --name "APP_NAME" \
>   --type native \
>   --auth-method none \
>   --callbacks "PACKAGE_ID://AUTH0_DOMAIN/capacitor/PACKAGE_ID/callback" \
>   --logout-urls "PACKAGE_ID://AUTH0_DOMAIN/capacitor/PACKAGE_ID/callback" \
>   --origins "capacitor://localhost,http://localhost" \
>   --json \
>   --no-input
> ```
>
> Replace `APP_NAME`, `PACKAGE_ID`, and `AUTH0_DOMAIN` with the actual values from Steps C and D.
>
> **Parse the JSON output** to extract `client_id`. Example response:
> ```json
> {
>   "client_id": "abc123def456...",
>   "name": "my-app",
>   "app_type": "native",
>   ...
> }
> ```
>
> Store `client_id` as `AUTH0_CLIENT_ID`.
>
> If this command fails due to session expiry, ask the user to run `auth0 login` again and retry. Retry up to 3 times.
>
> ---
>
> #### Step F — Write `.env` with real credentials
>
> Write (or update) the `.env` file in the project root with the actual values from Steps C–E:
>
> ```bash
> VITE_AUTH0_DOMAIN=AUTH0_DOMAIN
> VITE_AUTH0_CLIENT_ID=AUTH0_CLIENT_ID
> VITE_AUTH0_CALLBACK_URI=PACKAGE_ID://AUTH0_DOMAIN/capacitor/PACKAGE_ID/callback
> ```
>
> Replace `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, and `PACKAGE_ID` with the actual values.
>
> - **If `.env` already exists:** Update or add these three variables without removing other existing variables.
> - **If `.env` does not exist:** Create the file.
> - **If `.gitignore` does not include `.env`:** Add `.env` to `.gitignore`.
>
> ---
>
> #### Step G — Update `src/main.ts` to use env vars
>
> Read `src/main.ts` and wire it to read credentials from `import.meta.env`:
>
> **If `createAuth0()` already exists in the file:**
> - Replace any hardcoded `domain` value (e.g., `"YOUR_AUTH0_DOMAIN"` or a real domain string) with `import.meta.env.VITE_AUTH0_DOMAIN`.
> - Replace any hardcoded `clientId` value with `import.meta.env.VITE_AUTH0_CLIENT_ID`.
> - Replace the `redirect_uri` value with `` `${packageId}://${import.meta.env.VITE_AUTH0_DOMAIN}/capacitor/${packageId}/callback` `` (where `packageId` is read from the Capacitor config or hardcoded if it never changes).
>
> **If `createAuth0()` does NOT exist in the file:**
> 1. Add the import: `import { createAuth0 } from '@auth0/auth0-vue';`
> 2. Add the Auth0 plugin registration before `router.isReady()` or `app.mount()`:
>    ```typescript
>    const packageId = "PACKAGE_ID"; // From capacitor.config.ts appId
>
>    app.use(
>      createAuth0({
>        domain: import.meta.env.VITE_AUTH0_DOMAIN,
>        clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
>        useRefreshTokens: true,
>        useRefreshTokensFallback: false,
>        authorizationParams: {
>          redirect_uri: `${packageId}://${import.meta.env.VITE_AUTH0_DOMAIN}/capacitor/${packageId}/callback`
>        }
>      })
>    );
>    ```
>
> Replace `PACKAGE_ID` with the actual package ID from Step D.
>
> ---
>
> #### Step H — Confirm setup to user (never display credentials)
>
> After completing all steps, tell the user:
> - _"Auth0 application created and configured successfully."_
> - _"Credentials have been written to `.env` (`VITE_AUTH0_DOMAIN` and `VITE_AUTH0_CLIENT_ID`)."_
> - _"`src/main.ts` reads credentials from `import.meta.env`."_
>
> **Do NOT display the actual domain, client ID, or callback URL values.** Only confirm that the setup succeeded and where the credentials were saved.
>
> If the CLI keeps failing after retries, fall back to **Manual Setup** below.

### Manual Setup (User-Provided Configuration)

> **Agent instruction:** Ask the user to provide their Auth0 configuration. Accept either:
> - **An `.env` file path** — read the file to extract the Auth0 domain and client ID, then copy or reference it in the project.
> - **Direct credentials** — ask using `AskUserQuestion`: _"Please provide your Auth0 Domain and Client ID."_
>
> Once credentials are obtained, write them to the project `.env` file using `VITE_AUTH0_DOMAIN` and `VITE_AUTH0_CLIENT_ID` variable names. **Do NOT display the credentials in conversation output.**

### Callback URL Format

| Field | Value |
|-------|-------|
| **Allowed Callback URLs** | `YOUR_PACKAGE_ID://YOUR_DOMAIN/capacitor/YOUR_PACKAGE_ID/callback` |
| **Allowed Logout URLs** | `YOUR_PACKAGE_ID://YOUR_DOMAIN/capacitor/YOUR_PACKAGE_ID/callback` |
| **Allowed Web Origins** | `capacitor://localhost, http://localhost` |

Replace `YOUR_PACKAGE_ID` with your app's package ID (e.g., `com.example.myapp`) and `YOUR_DOMAIN` with your Auth0 domain. These are set automatically when using the CLI commands above.

## SDK Installation

```bash
npm install @auth0/auth0-vue @capacitor/browser @capacitor/app
npx cap sync
```

### Plugin purposes

| Package | Purpose |
|---------|---------|
| `@auth0/auth0-vue` | Auth0 Vue SDK — provides `createAuth0` plugin and `useAuth0` composable |
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

**Ionic Vue + Capacitor apps are Native applications** — they do not use a client secret.

- Configuration contains only: **Domain**, **Client ID**, and **Callback URL**
- These values are not secrets and can be included in source code
- Token validation uses PKCE (Proof Key for Code Exchange) — no client secret needed
- Never include a client secret in a mobile/native application

### Environment Variables (Optional)

If you prefer environment variables for Domain and Client ID during development:

```bash
# .env (for Vite-based Ionic Vue projects)
VITE_AUTH0_DOMAIN=your-tenant.auth0.com
VITE_AUTH0_CLIENT_ID=your-client-id
```

Then reference in code:
```typescript
app.use(
  createAuth0({
    domain: import.meta.env.VITE_AUTH0_DOMAIN,
    clientId: import.meta.env.VITE_AUTH0_CLIENT_ID,
    useRefreshTokens: true,
    useRefreshTokensFallback: false,
    authorizationParams: {
      redirect_uri: `${packageId}://${import.meta.env.VITE_AUTH0_DOMAIN}/capacitor/${packageId}/callback`
    }
  })
);
```

## Verification

After setup, verify the configuration:

1. Run `ionic serve` — the app should load without Auth0 errors
2. Run `ionic build && npx cap sync` — native projects should sync cleanly
3. Open in Xcode/Android Studio and build — no missing plugin errors
4. Tap login — system browser should open Auth0 Universal Login
5. After login — app should receive the deep link callback and show the user profile
