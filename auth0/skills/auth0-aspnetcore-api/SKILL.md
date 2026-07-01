---
name: auth0-aspnetcore-api
description: >
  Use when protecting ASP.NET Core Web API endpoints with JWT Bearer token validation, scope checks, or DPoP binding. Integrates Auth0.AspNetCore.Authentication.Api for stateless REST APIs receiving access tokens from frontends or mobile apps.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 ASP.NET Core Web API Integration

Protect ASP.NET Core Web API endpoints with JWT access token validation using Auth0.AspNetCore.Authentication.Api.

---

## Prerequisites

- .NET 8.0 SDK or higher
- Auth0 API configured (not Application - must be API resource)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **Server-rendered web applications** - Use session-based auth (Auth0.AspNetCore.Authentication) for MVC/Razor Pages apps
- **Single Page Applications** - Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Mobile applications** - Use `auth0-react-native` for React Native/Expo
- **Blazor WebAssembly** - Requires different auth approach (OIDC client-side)

---

## Quick Start Workflow

### 1. Install SDK

```bash
dotnet add package Auth0.AspNetCore.Authentication.Api
```

### 2. Create Auth0 API

You need an **API** (not Application) in Auth0.

> **STOP — ask the user before proceeding.**
>
> Ask exactly this question and wait for their answer before doing anything else:
>
> > "How would you like to create the Auth0 API resource?
> > 1. **Automated** — I'll run Auth0 CLI scripts that create the resource and write the exact values to your appsettings.json automatically.
> > 2. **Manual** — You create the API yourself in the Auth0 Dashboard (or via `auth0 apis create`) and provide me the Domain and Audience.
> >
> > Which do you prefer? (1 = Automated / 2 = Manual)"
>
> Do NOT proceed to any setup steps until the user has answered. Do NOT default to manual.

**If the user chose Automated**, follow the [Setup Guide](references/setup.md) for complete CLI scripts. The automated path writes `appsettings.json` for you — skip Step 3 below and proceed directly to Step 4.

**If the user chose Manual**, follow the [Setup Guide](references/setup.md) (Manual Setup section) for full instructions including User Secrets and environment variable options. Then continue with Step 3 below.

Quick reference for manual API creation:

```bash
# Using Auth0 CLI
auth0 apis create \
  --name "My ASP.NET Core API" \
  --identifier https://my-api.example.com
```

Or create manually in Auth0 Dashboard → Applications → APIs

### 3. Configure appsettings.json

```json
{
  "Auth0": {
    "Domain": "your-tenant.auth0.com",
    "Audience": "https://my-api.example.com"
  }
}
```

**Important:** Domain must NOT include `https://`. The library constructs the authority URL automatically.

### 4. Configure Program.cs

```csharp
var builder = WebApplication.CreateBuilder(args);

// Register Auth0 JWT validation
builder.Services.AddAuth0ApiAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.JwtBearerOptions = new JwtBearerOptions
    {
        Audience = builder.Configuration["Auth0:Audience"]
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

// Middleware order matters: authentication before authorization
app.UseAuthentication();
app.UseAuthorization();

// Add your endpoints here (see Step 5)
app.MapGet("/api/public", () => Results.Ok(new { message = "Public" }));

app.Run();
```

### 5. Protect Endpoints

**Minimal API:**

```csharp
// Public endpoint - no authentication
app.MapGet("/api/public", () => Results.Ok(new { message = "Hello from a public endpoint!" }));

// Protected endpoint - requires valid JWT
app.MapGet("/api/private", (HttpContext ctx) =>
{
    var userId = ctx.User.FindFirst("sub")?.Value;
    return Results.Ok(new { message = "Hello from a protected endpoint!", userId });
}).RequireAuthorization();
```

**Controller-based:**

```csharp
[ApiController]
[Route("api")]
public class MessagesController : ControllerBase
{
    [HttpGet("public")]
    public IActionResult Public() =>
        Ok(new { message = "Hello from a public endpoint!" });

    [Authorize]
    [HttpGet("private")]
    public IActionResult Private() =>
        Ok(new { message = "Hello from a protected endpoint!", userId = User.FindFirst("sub")?.Value });
}
```

### 6. Test API

Test public endpoint:

```bash
curl http://localhost:5000/api/public
```

Test protected endpoint (requires access token):

```bash
curl http://localhost:5000/api/private \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Get a test token via Client Credentials flow or Auth0 Dashboard → APIs → Test tab.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Domain includes `https://` | Use `your-tenant.auth0.com` format only - no scheme prefix |
| Audience doesn't match API Identifier | Must exactly match the API Identifier set in Auth0 Dashboard |
| Created Application instead of API in Auth0 | Must create API resource in Auth0 Dashboard → Applications → APIs |
| Wrong middleware order | `UseAuthentication()` must come before `UseAuthorization()` |
| Using ID token instead of access token | Must use **access token** for API auth, not ID token |
| HTTPS certificate errors locally | Run `dotnet dev-certs https --trust` |

---

## Scope-Based Authorization

See [Integration Guide](references/integration.md#scope-based-authorization) for defining and enforcing scope policies.

---

## DPoP Support

Built-in proof-of-possession token binding per RFC 9449. See [Integration Guide](references/integration.md#dpop-support) for configuration.

---

## Related Skills

- `auth0-quickstart` - Basic Auth0 setup
- `auth0-mfa` - Add Multi-Factor Authentication
- `auth0-cli` - Manage Auth0 resources from the terminal

---

## Quick Reference

**Configuration Options:**
- `options.Domain` - Auth0 tenant domain, no `https://` prefix (required)
- `options.JwtBearerOptions.Audience` - API Identifier from Auth0 API settings (required)
- `options.JwtBearerOptions` - Full access to underlying Microsoft JWT Bearer options

**User Claims:**
- `ctx.User.FindFirst("sub")?.Value` - User ID (subject)
- `ctx.User.FindFirst("scope")?.Value` - Space-separated scopes
- `ctx.User.FindAll("scope")` - All scope claims

**Common Use Cases:**
- Protect Minimal API routes → `.RequireAuthorization()` (see Step 5)
- Protect controller actions → `[Authorize]` attribute (see Step 5)
- Scope enforcement → [Integration Guide](references/integration.md#scope-based-authorization)
- DPoP token binding → [Integration Guide](references/integration.md#dpop-support)
- Advanced JWT Bearer config → [API Reference](references/api.md)

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Auth0 CLI setup, environment configuration
- **[Integration Guide](references/integration.md)** - Scope policies, DPoP, controller patterns, error handling
- **[API Reference](references/api.md)** - Complete configuration options and extension methods

---

## References

- [Auth0 ASP.NET Core Web API Quickstart](https://auth0.com/docs/quickstart/backend/aspnet-core-webapi)
- [SDK GitHub Repository](https://github.com/auth0/aspnetcore-api)
- [API Documentation](https://auth0.github.io/aspnetcore-api)
- [Access Tokens Guide](https://auth0.com/docs/secure/tokens/access-tokens)
