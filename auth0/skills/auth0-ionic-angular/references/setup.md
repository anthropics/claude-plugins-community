# auth0-ionic-angular — Setup Guide

## Auth0 Configuration

> **Agent instruction:**
>
> **SECURITY — Never display credentials:**
> After obtaining Auth0 credentials (domain, client ID) — whether from the Auth0 CLI or a user-provided env file — NEVER print, echo, or display them in your text output. Write them directly to the config file (`src/environments/environment.ts`) silently. Do NOT produce output like "Domain: xxx" or "Client ID: yyy". Instead, confirm that the config file has been written and tell the user where to find it.
>
> **Always present the setup choice:**
> Regardless of whether the user has already provided credentials in their prompt, **always** use `AskUserQuestion` to let the developer choose between Automatic and Manual setup:
>
> ```
> AskUserQuestion:
>   question: "How would you like to configure Auth0 for your Ionic Angular app?"
>   options:
>     - label: "Automatic Setup (Recommended)"
>       description: "Uses the Auth0 CLI to create a Native application, configure callback URLs, and store credentials in your project automatically."
>     - label: "Manual Setup"
>       description: "You provide an .env file with your Auth0 Domain and Client ID, and the agent reads it and writes the project configuration for you."
> ```

---

### Option A: Automatic Setup (Auth0 CLI)

The agent executes Auth0 CLI commands to create the application, configure it, retrieve credentials, and write them to the project config file — fully hands-free.

#### Step A1: Pre-flight checks

Run these checks in order. If any fail, guide the user to fix the issue or fall back to Manual Setup.

```bash
# Verify Node.js 20+
node --version

# Verify Auth0 CLI is installed
auth0 --version --no-input

# Verify logged in to Auth0
auth0 tenants list --csv --no-input
```

If the Auth0 CLI is not installed, instruct the user:
```bash
# macOS
brew install auth0/auth0-cli/auth0

# Linux
curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh
```

If not logged in:
```bash
auth0 login
```

#### Step A2: Detect project and appId

- Verify `package.json` contains `@angular/core`, `@ionic/angular`, and `@capacitor/core`
- Read `appId` from `capacitor.config.ts` (match `appId: 'com.example.app'`) or `capacitor.config.json`
- If neither config file exists or `appId` is not found, use `com.example.app` as default and warn the user

#### Step A3: Get the active tenant domain

```bash
auth0 tenants list --csv --no-input
```

Parse the output to find the line containing `→` — the second CSV column on that line is the active domain.

#### Step A4: Create a Native Auth0 application

```bash
auth0 apps create \
  --name "PROJECT_NAME-ionic-angular" \
  --type native \
  --auth-method none \
  --callbacks "PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback" \
  --logout-urls "PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback" \
  --origins "capacitor://localhost,http://localhost" \
  --json --no-input
```

Replace `PROJECT_NAME` with the project name from `package.json`, `PACKAGE_ID` with the `appId` from Step A2, and `DOMAIN` with the tenant domain from Step A3.

Extract `client_id` from the JSON output.

#### Step A5: Enable Username-Password-Authentication connection

```bash
auth0 api get connections
```

Parse the JSON array to find the connection with `"name": "Username-Password-Authentication"`.

- **If it exists** but doesn't include the new `client_id` in `enabled_clients`, update it:
  ```bash
  auth0 api patch "connections/CONNECTION_ID" --data '{"enabled_clients":["EXISTING_ID_1","EXISTING_ID_2","NEW_CLIENT_ID"]}'
  ```
  Keep all existing `enabled_clients` and append the new one.

- **If it doesn't exist**, create it:
  ```bash
  auth0 api post connections --data '{"strategy":"auth0","name":"Username-Password-Authentication","enabled_clients":["CLIENT_ID"]}'
  ```

- **If it already includes the client_id**, skip this step.

#### Step A6: Write config file

Create `src/environments/` directory if it doesn't exist, then write `src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  auth0: {
    domain: 'DOMAIN',
    clientId: 'CLIENT_ID',
    callbackUrl: 'PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback',
    appId: 'PACKAGE_ID',
  },
};
```

#### Step A7: Confirm completion

Tell the user that Auth0 has been configured and credentials have been written to `src/environments/environment.ts`. Do NOT display the domain, client ID, or any credential values in the output.

---

### Option B: Manual Setup

The developer provides an `.env` file containing their Auth0 credentials. The agent reads the file, extracts the values, and writes the project configuration.

#### Step B1: Ask for the env file path

Use `AskUserQuestion` to ask the developer for the path to their `.env` file:

```
AskUserQuestion:
  question: "Please provide the path to your .env file containing Auth0 credentials (AUTH0_DOMAIN and AUTH0_CLIENT_ID):"
```

The `.env` file should contain lines in this format:
```
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your_client_id_here
```

> **Agent instruction:** Read the file at the path the user provides. Extract the values for `AUTH0_DOMAIN` and `AUTH0_CLIENT_ID` by parsing `KEY=VALUE` lines. If the file is missing either key, use `AskUserQuestion` to ask the user to provide the missing value. Accept common variations: `DOMAIN` / `AUTH0_DOMAIN`, `CLIENT_ID` / `AUTH0_CLIENT_ID`.

#### Step B2: Detect appId

Read `appId` from `capacitor.config.ts` (match `appId: 'com.example.app'`) or `capacitor.config.json`. If not found, use `com.example.app` as default and warn the user.

#### Step B3: Write config file

Create `src/environments/` directory if it doesn't exist, then write `src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  auth0: {
    domain: 'DOMAIN',
    clientId: 'CLIENT_ID',
    callbackUrl: 'PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback',
    appId: 'PACKAGE_ID',
  },
};
```

#### Step B4: Remind user to configure Auth0 Dashboard

Since credentials were provided manually, the user must also configure the Auth0 Dashboard themselves. Display these required settings:

| Setting | Value |
|---------|-------|
| **Application Type** | **Native** |
| **Allowed Callback URLs** | `PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback` |
| **Allowed Logout URLs** | `PACKAGE_ID://DOMAIN/capacitor/PACKAGE_ID/callback` |
| **Allowed Origins** | `capacitor://localhost, http://localhost` |

Also add `http://localhost:8100` to Callback URLs, Logout URLs, and Web Origins if the user will use `ionic serve` for local development.

No Client Secret is needed — Native apps use PKCE.

## Auth0 Dashboard Configuration

### Create a Native Application

1. Go to **Auth0 Dashboard → Applications → Create Application**
2. Select **Native** as the application type
3. Note the **Domain** and **Client ID** from the Settings tab

### Configure URLs

Determine your `appId` from `capacitor.config.ts` (e.g., `com.example.myapp`).

| Setting | Value |
|---------|-------|
| **Allowed Callback URLs** | `PACKAGE_ID://YOUR_DOMAIN/capacitor/PACKAGE_ID/callback` |
| **Allowed Logout URLs** | `PACKAGE_ID://YOUR_DOMAIN/capacitor/PACKAGE_ID/callback` |
| **Allowed Origins** | `capacitor://localhost, http://localhost` |

Example with `appId = com.example.myapp` and domain `dev-abc123.us.auth0.com`:
```text
com.example.myapp://dev-abc123.us.auth0.com/capacitor/com.example.myapp/callback
```

## SDK Installation

```bash
npm install @auth0/auth0-angular @capacitor/browser @capacitor/app
```

If Capacitor platforms aren't added yet:
```bash
npx cap add ios
npx cap add android
```

## SDK Configuration

### Standalone Components (Angular 17+)

In `src/app/app.config.ts`:

```typescript
import { ApplicationConfig } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideAuth0 } from '@auth0/auth0-angular';
import { routes } from './app.routes';

// Replace with your capacitor.config.ts appId and Auth0 domain
const appId = 'YOUR_PACKAGE_ID';
const domain = 'YOUR_AUTH0_DOMAIN';
const callbackUri = `${appId}://${domain}/capacitor/${appId}/callback`;

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideAuth0({
      domain,
      clientId: 'YOUR_AUTH0_CLIENT_ID',
      useRefreshTokens: true,
      useRefreshTokensFallback: false,
      authorizationParams: {
        redirect_uri: callbackUri,
      },
    }),
  ],
};
```

### NgModule (Angular 16 and earlier)

In `src/app/app.module.ts`:

```typescript
import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { IonicModule } from '@ionic/angular';
import { AuthModule } from '@auth0/auth0-angular';
import { AppComponent } from './app.component';
import { AppRoutingModule } from './app-routing.module';

const appId = 'YOUR_PACKAGE_ID';
const domain = 'YOUR_AUTH0_DOMAIN';
const callbackUri = `${appId}://${domain}/capacitor/${appId}/callback`;

@NgModule({
  declarations: [AppComponent],
  imports: [
    BrowserModule,
    IonicModule.forRoot(),
    AppRoutingModule,
    AuthModule.forRoot({
      domain,
      clientId: 'YOUR_AUTH0_CLIENT_ID',
      useRefreshTokens: true,
      useRefreshTokensFallback: false,
      authorizationParams: {
        redirect_uri: callbackUri,
      },
    }),
  ],
  bootstrap: [AppComponent],
})
export class AppModule {}
```

## Post-Setup: Deep Linking Configuration

### iOS

The custom URL scheme is automatically registered by Capacitor from `capacitor.config.ts`. Verify in `ios/App/App/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>PACKAGE_ID</string>
    </array>
  </dict>
</array>
```

### Android

Verify the intent filter in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="PACKAGE_ID" />
</intent-filter>
```

## Secret Management

- **No Client Secret needed** — Ionic Capacitor apps are Native apps that use PKCE for authentication
- **Never embed secrets in client-side code** — the Auth0 Angular SDK only requires `domain` and `clientId`
- Configuration values (domain, clientId) can be hardcoded in `app.config.ts` / `app.module.ts` or loaded from `environment.ts`

### Using `environment.ts` (optional)

```typescript
// src/environments/environment.ts
export const environment = {
  production: false,
  auth0: {
    domain: 'YOUR_AUTH0_DOMAIN',
    clientId: 'YOUR_AUTH0_CLIENT_ID',
  },
};
```

```typescript
// src/app/app.config.ts
import { environment } from '../environments/environment';

const appId = 'YOUR_PACKAGE_ID'; // from capacitor.config.ts
const callbackUri = `${appId}://${environment.auth0.domain}/capacitor/${appId}/callback`;

provideAuth0({
  domain: environment.auth0.domain,
  clientId: environment.auth0.clientId,
  useRefreshTokens: true,
  useRefreshTokensFallback: false,
  authorizationParams: {
    redirect_uri: callbackUri,
  },
}),
```

## Verification

After setup, verify:

1. **Build succeeds:** `npm run build`
2. **Capacitor sync:** `npx cap sync`
3. **Run on device/emulator:**
   - iOS: `npx cap open ios` → Run in Xcode
   - Android: `npx cap open android` → Run in Android Studio
4. **Login opens system browser** (not in-app WebView)
5. **Callback returns to app** with user profile
