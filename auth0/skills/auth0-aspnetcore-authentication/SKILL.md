---
name: auth0-aspnetcore-authentication
description: >
  Use when adding cookie-based login, logout, or user profile to an ASP.NET Core MVC, Razor Pages, or Blazor Server web app. Integrates Auth0.AspNetCore.Authentication — use even if the user says "add login to my .NET web app" without naming the package.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
  version: '1.0.0'
  openclaw:
    emoji: "\U0001F510"
    homepage: https://github.com/auth0/agent-skills
---

# Auth0 ASP.NET Core Web App Integration

Add login, logout, and user profile to an ASP.NET Core MVC, Razor Pages, or Blazor Server application using `Auth0.AspNetCore.Authentication`.

---

## Prerequisites

- ASP.NET Core application (.NET 8 or higher)
- Auth0 Regular Web Application configured (not an API - must be an Application)
- If you don't have Auth0 set up yet, use the `auth0-quickstart` skill first

## When NOT to Use

- **ASP.NET Core Web APIs with JWT Bearer validation** - Use `auth0-aspnetcore-api` for JWT-protected REST APIs
- **Blazor WebAssembly** - Requires OIDC client-side auth; see the Auth0 Blazor WebAssembly quickstart
- **Single Page Applications** - Use `auth0-react`, `auth0-vue`, or `auth0-angular` for client-side auth
- **Next.js applications** - Use `auth0-nextjs` which handles both client and server
- **Python web apps** - Use `auth0-flask` for Flask or see the Django quickstart

---

## Quick Start Workflow

### 1. Install SDK

```bash
dotnet add package Auth0.AspNetCore.Authentication
```

### 2. Configure Credentials

Add Auth0 settings to `appsettings.json`:

```json
{
  "Auth0": {
    "Domain": "your-tenant.us.auth0.com",
    "ClientId": "your_client_id",
    "ClientSecret": "your_client_secret"
  }
}
```

**For local development**, keep secrets out of source control - use `dotnet user-secrets` to avoid committing `ClientSecret`:

```bash
dotnet user-secrets set "Auth0:Domain" "your-tenant.us.auth0.com"
dotnet user-secrets set "Auth0:ClientId" "your_client_id"
dotnet user-secrets set "Auth0:ClientSecret" "your_client_secret"
```

`Auth0:Domain` is your tenant domain (without `https://`). `Auth0:ClientId` and `Auth0:ClientSecret` come from your Auth0 Application settings.

### 3. Configure Auth0 Dashboard

In your Auth0 Application settings:
- **Allowed Callback URLs**: `http://localhost:5000/callback`
- **Allowed Logout URLs**: `http://localhost:5000`
- **Allowed Web Origins**: `http://localhost:5000`

### 4. Register Auth0 in Program.cs

```csharp
using Auth0.AspNetCore.Authentication;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuth0WebAppAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.ClientId = builder.Configuration["Auth0:ClientId"];
    options.ClientSecret = builder.Configuration["Auth0:ClientSecret"];
});

builder.Services.AddControllersWithViews();

var app = builder.Build();

// Standard middleware...
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.UseAuthentication();    // Must come before UseAuthorization
app.UseAuthorization();     // Critical: order matters

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
```

**Critical:** `UseAuthentication()` must come before `UseAuthorization()`. Reversing these causes silent auth failures where protected routes are never challenged.

### 5. Create AccountController

```csharp
using Auth0.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

public class AccountController : Controller
{
    public async Task Login(string returnUrl = "/")
    {
        var authenticationProperties = new LoginAuthenticationPropertiesBuilder()
            .WithRedirectUri(returnUrl)
            .Build();

        await HttpContext.ChallengeAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
    }

    [Authorize]
    public async Task Logout()
    {
        var authenticationProperties = new LogoutAuthenticationPropertiesBuilder()
            .WithRedirectUri(Url.Action("Index", "Home"))
            .Build();

        await HttpContext.SignOutAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    }

    [Authorize]
    public IActionResult Profile()
    {
        return View();
    }
}
```

`Login` does not need `[Authorize]` - it is the entry point for unauthenticated users. `Logout` requires `[Authorize]` to ensure the sign-out only fires for authenticated sessions. **Always call both `SignOutAsync` methods** - signing out of only the Auth0 scheme leaves a local cookie; signing out of only the cookie scheme skips the Auth0 logout URL.

### 6. Create Profile View

Create `Views/Account/Profile.cshtml`:

```html
@{
    ViewData["Title"] = "User Profile";
}

<div class="row">
    <div class="col-md-2">
        <img src="@User.FindFirst(c => c.Type == "picture")?.Value"
             alt="Profile picture" class="img-fluid rounded-circle" />
    </div>
    <div class="col-md-10">
        <h3>@User.Identity.Name</h3>
        <p><strong>Email:</strong>
           @User.FindFirst(c => c.Type == System.Security.Claims.ClaimTypes.Email)?.Value</p>
        <p><strong>User ID:</strong>
           @User.FindFirst(c => c.Type == System.Security.Claims.ClaimTypes.NameIdentifier)?.Value</p>
    </div>
</div>

<h4 class="mt-4">Claims</h4>
<table class="table">
    <thead><tr><th>Claim Type</th><th>Claim Value</th></tr></thead>
    <tbody>
        @foreach (var claim in User.Claims)
        {
            <tr><td>@claim.Type</td><td>@claim.Value</td></tr>
        }
    </tbody>
</table>
```

### 7. Update Navigation (_Layout.cshtml)

Add login/logout/profile links to your nav bar inside `_Layout.cshtml`:

```html
@if (User.Identity.IsAuthenticated)
{
    <li class="nav-item">
        <a class="nav-link text-dark" asp-controller="Account" asp-action="Profile">@User.Identity.Name</a>
    </li>
    <li class="nav-item">
        <a class="nav-link text-dark" asp-controller="Account" asp-action="Logout">Logout</a>
    </li>
}
else
{
    <li class="nav-item">
        <a class="nav-link text-dark" asp-controller="Account" asp-action="Login">Login</a>
    </li>
}
```

### 8. Test the App

```bash
dotnet run
```

Visit `http://localhost:5000` and click Login to start the Auth0 login flow.

---

## Blazor Server Variant

For Blazor Server apps, use Razor Pages as auth endpoints - Blazor components cannot perform the HTTP redirects required by OAuth challenges.

### Additional Program.cs Setup

```csharp
using Auth0.AspNetCore.Authentication;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuth0WebAppAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.ClientId = builder.Configuration["Auth0:ClientId"];
    options.ClientSecret = builder.Configuration["Auth0:ClientSecret"];
});

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddCascadingAuthenticationState();  // Required for Blazor auth state
builder.Services.AddRazorPages();                     // Required for auth endpoints

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
```

### Login Razor Page (Pages/Login.cshtml.cs)

```csharp
using Auth0.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class LoginModel : PageModel
{
    public async Task OnGet(string returnUrl = "/")
    {
        var authenticationProperties = new LoginAuthenticationPropertiesBuilder()
            .WithRedirectUri(returnUrl)
            .Build();

        await HttpContext.ChallengeAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
    }
}
```

### Logout Razor Page (Pages/Logout.cshtml.cs)

```csharp
using Auth0.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

public class LogoutModel : PageModel
{
    public async Task OnGet()
    {
        var authenticationProperties = new LogoutAuthenticationPropertiesBuilder()
            .WithRedirectUri(Url.Content("~/"))
            .Build();

        await HttpContext.SignOutAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    }
}
```

### Profile Component (Components/Pages/Profile.razor)

```razor
@page "/profile"
@attribute [Authorize]
@using System.Security.Claims

<h1>Profile</h1>

<AuthorizeView>
    <Authorized>
        <div class="row">
            <div class="col-2">
                <img src="@context.User.FindFirst("picture")?.Value"
                     alt="Profile" class="img-fluid rounded-circle" />
            </div>
            <div class="col-10">
                <h3>@context.User.Identity?.Name</h3>
                <p><strong>Email:</strong> @context.User.FindFirst(ClaimTypes.Email)?.Value</p>
            </div>
        </div>

        <h4 class="mt-4">Claims</h4>
        <table class="table">
            <thead><tr><th>Type</th><th>Value</th></tr></thead>
            <tbody>
                @foreach (var claim in context.User.Claims)
                {
                    <tr><td>@claim.Type</td><td>@claim.Value</td></tr>
                }
            </tbody>
        </table>
    </Authorized>
</AuthorizeView>
```

### Update MainLayout.razor Navigation

```razor
@using Microsoft.AspNetCore.Components.Authorization

<AuthorizeView>
    <Authorized>
        <a href="/profile">@context.User.Identity?.Name</a>
        <a href="/Logout">Logout</a>
    </Authorized>
    <NotAuthorized>
        <a href="/Login">Login</a>
    </NotAuthorized>
</AuthorizeView>
```

### Routes.razor

Wrap the `Router` in `CascadingAuthenticationState` to enable authorization throughout the component tree:

```razor
<CascadingAuthenticationState>
    <Router AppAssembly="typeof(Program).Assembly">
        <Found Context="routeData">
            <AuthorizeRouteView RouteData="routeData" DefaultLayout="typeof(Layout.MainLayout)" />
            <FocusOnNavigate RouteData="routeData" Selector="h1" />
        </Found>
    </Router>
</CascadingAuthenticationState>
```

---

## Razor Pages Variant

For Razor Pages apps (without Blazor), use `AddRazorPages()` instead of `AddControllersWithViews()` in `Program.cs`. Auth endpoints are the same Login/Logout page models shown in the Blazor Server section. Replace navigation in `_Layout.cshtml` using the same `User.Identity.IsAuthenticated` check shown in the MVC section.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Hardcoding `Domain`, `ClientId`, or `ClientSecret` in source | Read from configuration - use `builder.Configuration["Auth0:Domain"]`; never embed credentials |
| Committing `ClientSecret` to source control | Use `dotnet user-secrets` or environment variables for the client secret - never commit it |
| `UseAuthorization()` before `UseAuthentication()` | Must call `UseAuthentication()` first - wrong order causes auth to never fire |
| Signing out of only one scheme | Always call both `SignOutAsync(Auth0Constants.AuthenticationScheme)` and `SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme)` |
| Adding `[Authorize]` to the `Login` action | `Login` must be accessible to unauthenticated users - only apply `[Authorize]` to `Logout` and `Profile` |
| Not configuring Callback URLs in Auth0 Dashboard | Must add `http://localhost:5000/callback` to Allowed Callback URLs |
| Passing `Domain` with `https://` prefix | `Domain` should be the bare domain, e.g., `my-tenant.us.auth0.com`, not `https://my-tenant.us.auth0.com` |
| Not adding `AddCascadingAuthenticationState()` in Blazor | Required for Blazor Server - without it, `AuthorizeView` and `[Authorize]` attributes have no auth context |
| Using Blazor components for login/logout redirects | Blazor components cannot perform HTTP redirects - use Razor Pages (`/Login`, `/Logout`) for auth endpoints |
| Not adding `AddRazorPages()` and `MapRazorPages()` in Blazor | Login and Logout Razor Pages won't be routed without these registrations |
| Using `Auth0.AspNetCore.Authentication.Api` for web apps | That package is for JWT-protected APIs - use `Auth0.AspNetCore.Authentication` for session-based web apps |
| Using `AddJwtBearer` instead of `AddAuth0WebAppAuthentication` | `AddJwtBearer` is for stateless API auth - session-based web apps require `AddAuth0WebAppAuthentication` |
| Not creating `Views/Account/` directory for Profile view | MVC requires the directory to exist before creating the view |

---

## Key SDK Methods

| Method/Property | Usage | Purpose |
|-----------------|-------|---------|
| `AddAuth0WebAppAuthentication` | `builder.Services.AddAuth0WebAppAuthentication(options => { ... })` | Registers Auth0 cookie-based authentication |
| `LoginAuthenticationPropertiesBuilder` | `new LoginAuthenticationPropertiesBuilder().WithRedirectUri(url).Build()` | Builds properties for the login challenge |
| `LogoutAuthenticationPropertiesBuilder` | `new LogoutAuthenticationPropertiesBuilder().WithRedirectUri(url).Build()` | Builds properties for the logout redirect |
| `ChallengeAsync` | `await HttpContext.ChallengeAsync(Auth0Constants.AuthenticationScheme, props)` | Initiates the Auth0 Universal Login redirect |
| `SignOutAsync` (Auth0) | `await HttpContext.SignOutAsync(Auth0Constants.AuthenticationScheme, props)` | Signs out of Auth0 and redirects to logout URL |
| `SignOutAsync` (Cookie) | `await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme)` | Clears the local session cookie |
| `User.FindFirst` | `User.FindFirst(c => c.Type == "picture")?.Value` | Accesses individual user claims in controllers/views |
| `User.Identity.IsAuthenticated` | `@if (User.Identity.IsAuthenticated)` | Checks authentication state in views/layouts |
| `[Authorize]` | `[Authorize]` attribute on controller action or Razor component | Protects routes requiring authentication |
| `AddCascadingAuthenticationState` | `builder.Services.AddCascadingAuthenticationState()` | Required for Blazor Server auth state propagation |

---

## Related Skills

- `auth0-aspnetcore-api` - For ASP.NET Core Web APIs with JWT Bearer token validation
- `auth0-express` - For server-rendered Express web apps with login/logout sessions
- `auth0-flask` - For Flask web applications with session-based auth

---

## Quick Reference

**SDK registration:**
```csharp
builder.Services.AddAuth0WebAppAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];        // required
    options.ClientId = builder.Configuration["Auth0:ClientId"];    // required
    options.ClientSecret = builder.Configuration["Auth0:ClientSecret"]; // required
});
```

**Login action:**
```csharp
var props = new LoginAuthenticationPropertiesBuilder().WithRedirectUri(returnUrl).Build();
await HttpContext.ChallengeAsync(Auth0Constants.AuthenticationScheme, props);
```

**Logout action (always call both):**
```csharp
var props = new LogoutAuthenticationPropertiesBuilder().WithRedirectUri(Url.Action("Index", "Home")).Build();
await HttpContext.SignOutAsync(Auth0Constants.AuthenticationScheme, props);
await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
```

**Route protection:**
```csharp
[Authorize]
public IActionResult Profile() { return View(); }
```

**appsettings.json configuration keys:**
- `Auth0:Domain` - Auth0 tenant domain (e.g., `tenant.us.auth0.com`)
- `Auth0:ClientId` - Application client ID
- `Auth0:ClientSecret` - Application client secret (use user-secrets in development)

---

## Detailed Documentation

- **[Setup Guide](references/setup.md)** - Automated setup scripts, credential configuration, Auth0 CLI usage
- **[Integration Guide](references/integration.md)** - Protected routes, calling APIs, Blazor patterns, error handling
- **[API Reference](references/api.md)** - Complete SDK configuration, builder options, claims reference

---

## References

- [Auth0.AspNetCore.Authentication on NuGet](https://www.nuget.org/packages/Auth0.AspNetCore.Authentication)
- [Auth0 ASP.NET Core MVC Quickstart](https://auth0.com/docs/quickstart/webapp/aspnet-core)
- [Auth0 ASP.NET Core Blazor Server Quickstart](https://auth0.com/docs/quickstart/webapp/aspnet-core-blazor-server)
- [ASP.NET Core Documentation](https://learn.microsoft.com/en-us/aspnet/core)
