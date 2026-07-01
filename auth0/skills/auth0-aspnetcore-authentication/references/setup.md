# Auth0 ASP.NET Core Setup Guide

Setup instructions for ASP.NET Core MVC, Razor Pages, and Blazor Server applications.

---

## Quick Setup (Automated)

Below automates the setup, except for the `ClientSecret`. Inform the user that they have to fill in the value for `ClientSecret` themselves.

**Never read the contents of `appsettings.json`, `appsettings.Development.json`, or user-secrets at any point during setup.** These files may contain sensitive secrets that should not be exposed in the LLM context. If you determine you need to read the file for any reason, ask the user for explicit permission before doing so — do not proceed until the user confirms.

**Before running any part of this setup that writes to a config file, you MUST ask the user for explicit confirmation.** Follow the steps below precisely.

### Step 1: Check for existing config files and confirm with user

Before writing credentials, check which config files exist:

```bash
test -f appsettings.Development.json && echo "DEV_SETTINGS_EXISTS" || echo "DEV_SETTINGS_NOT_FOUND"
test -f appsettings.json && echo "SETTINGS_EXISTS" || echo "SETTINGS_NOT_FOUND"
```

Then ask the user for explicit confirmation before proceeding — do not continue until the user confirms:

- If `appsettings.Development.json` exists, ask:
  - Question: "An `appsettings.Development.json` file already exists and may contain settings unrelated to Auth0. This setup will append Auth0 credentials to it without modifying existing content. Do you want to proceed?"
  - Options: "Yes, append to existing appsettings.Development.json" / "No, I'll update it manually"

- If `appsettings.Development.json` does **not** exist but `appsettings.json` exists, ask:
  - Question: "An `appsettings.json` file already exists. This setup will add the Auth0 section to it. Would you prefer to use `dotnet user-secrets` to keep the ClientSecret out of source control?"
  - Options: "Yes, use user-secrets" / "Yes, write to appsettings.json" / "No, I'll configure it manually"

- If neither exists, ask:
  - Question: "This setup will create an `appsettings.json` file containing Auth0 settings (Domain, ClientId) and a placeholder for ClientSecret. Do you want to proceed?"
  - Options: "Yes, create appsettings.json" / "No, I'll configure it manually"

**Do not proceed with writing to any config file unless the user selects the confirmation option.**

### Step 2: Run automated setup (only after confirmation)

```bash
#!/bin/bash

# Install Auth0 CLI
if ! command -v auth0 &> /dev/null; then
  [[ "$OSTYPE" == "darwin"* ]] && brew install auth0/auth0-cli/auth0 || \
  curl -sSfL https://raw.githubusercontent.com/auth0/auth0-cli/main/install.sh | sh -s -- -b /usr/local/bin
fi

# Login
auth0 login 2>/dev/null || auth0 login

# Create/select app
auth0 apps list
read -p "Enter app ID (or Enter to create): " APP_ID

if [ -z "$APP_ID" ]; then
  APP_ID=$(auth0 apps create --name "${PWD##*/}-aspnetcore" --type regular \
    --callbacks "http://localhost:5000/callback,https://localhost:7000/callback" \
    --logout-urls "http://localhost:5000,https://localhost:7000" \
    --metadata "created_by=agent_skills" \
    --json-compact | jq -r '.client_id')
fi

# Get credentials
DOMAIN=$(auth0 apps show "$APP_ID" --json-compact | jq -r '.domain')
CLIENT_ID=$(auth0 apps show "$APP_ID" --json-compact | jq -r '.client_id')

echo "Auth0 Domain: $DOMAIN"
echo "Auth0 Client ID: $CLIENT_ID"
echo ""
echo "Add these to your appsettings.json or use dotnet user-secrets:"
echo ""
echo "  dotnet user-secrets set \"Auth0:Domain\" \"$DOMAIN\""
echo "  dotnet user-secrets set \"Auth0:ClientId\" \"$CLIENT_ID\""
echo "  dotnet user-secrets set \"Auth0:ClientSecret\" \"YOUR_CLIENT_SECRET\""
```

After the script runs, remind the user to:
1. Replace `YOUR_CLIENT_SECRET` with the actual client secret from Auth0.
2. For production, use environment variables or a secrets manager — never commit the client secret to source control.
3. Verify the HTTPS port in `Properties/launchSettings.json` and update the Auth0 callback/logout URLs if needed (ASP.NET Core assigns random HTTPS ports in the 7000-7300 range).

---

## Manual Setup

### Install Package

```bash
dotnet add package Auth0.AspNetCore.Authentication
```

### Configure appsettings.json

Add the `Auth0` section:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "Auth0": {
    "Domain": "your-tenant.us.auth0.com",
    "ClientId": "your-client-id",
    "ClientSecret": "your-client-secret"
  }
}
```

**For local development**, use `dotnet user-secrets` to keep the client secret out of source control:

```bash
dotnet user-secrets init
dotnet user-secrets set "Auth0:Domain" "your-tenant.us.auth0.com"
dotnet user-secrets set "Auth0:ClientId" "your-client-id"
dotnet user-secrets set "Auth0:ClientSecret" "your-client-secret"
```

User secrets override `appsettings.json` in the Development environment. In production, use environment variables:

```bash
export Auth0__Domain="your-tenant.us.auth0.com"
export Auth0__ClientId="your-client-id"
export Auth0__ClientSecret="your-client-secret"
```

Note: Environment variable names use double underscores (`__`) to represent the `:` separator in .NET configuration keys.

### Get Auth0 Credentials

CLI: `auth0 apps show <app-id> --reveal-secrets`

Dashboard: Create a Regular Web Application, then copy Domain, Client ID, and Client Secret from the Settings tab.

### Configure Auth0 Dashboard

In your Auth0 Application settings:
- **Allowed Callback URLs**: `http://localhost:5000/callback, https://localhost:{HTTPS_PORT}/callback`
- **Allowed Logout URLs**: `http://localhost:5000, https://localhost:{HTTPS_PORT}`
- **Allowed Web Origins**: `http://localhost:5000, https://localhost:{HTTPS_PORT}`

> Check `Properties/launchSettings.json` for your project's actual HTTPS port (ASP.NET Core assigns a random port in the 7000-7300 range).

Application type must be **Regular Web Application** (not SPA or Native).

---

## Troubleshooting

**"IDX20803: Unable to obtain configuration" error:** Verify `Auth0:Domain` is the bare domain (e.g., `your-tenant.us.auth0.com`) without `https://`. The SDK prepends the protocol automatically.

**"Callback URL mismatch" error:** The Allowed Callback URLs in Auth0 Dashboard must exactly match your app's callback URL. Check for trailing slashes or http vs https mismatches.

**Client secret required:** ASP.NET Core apps use Regular Web Application type — ensure the app was created as regular, not SPA or Native. SPA apps do not have client secrets.

**Middleware order error (auth not working):** Ensure `app.UseAuthentication()` is called before `app.UseAuthorization()` in `Program.cs`.

**User-secrets not loading:** User secrets only load in the `Development` environment (`ASPNETCORE_ENVIRONMENT=Development`). Verify the environment variable is set correctly.

**SignOut not clearing session:** Ensure both `SignOutAsync(Auth0Constants.AuthenticationScheme)` and `SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme)` are called in the `Logout` action.

---

## Next Steps

- [Integration Guide](integration.md)
- [API Reference](api.md)
- [Main Skill](../SKILL.md)
