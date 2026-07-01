# Auth0 ASP.NET Core Integration Patterns

Server-side authentication patterns for ASP.NET Core MVC, Razor Pages, and Blazor Server.

---

## Protected Routes

### Using [Authorize] Attribute on Controller Actions

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

public class DashboardController : Controller
{
    [Authorize]
    public IActionResult Index()
    {
        var userName = User.Identity.Name;
        return View("Index", userName);
    }
}
```

### Using [Authorize] on an Entire Controller

```csharp
[Authorize]
public class AdminController : Controller
{
    public IActionResult Dashboard()
    {
        return View();
    }

    public IActionResult Settings()
    {
        return View();
    }
}
```

### Manual Check in Action

```csharp
public IActionResult Dashboard()
{
    if (!User.Identity.IsAuthenticated)
    {
        return RedirectToAction("Login", "Account");
    }
    return View();
}
```

### Policy-Based Authorization

```csharp
// Register policy in Program.cs
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("RequireEmail", policy =>
        policy.RequireClaim(System.Security.Claims.ClaimTypes.Email));
});

// Apply to action
[Authorize(Policy = "RequireEmail")]
public IActionResult AdminOnly()
{
    return View();
}
```

### Razor Pages Protection

```csharp
// Program.cs - protect all Razor Pages under /Admin
builder.Services.AddRazorPages(options =>
{
    options.Conventions.AuthorizeFolder("/Admin");
    options.Conventions.AllowAnonymousToPage("/Admin/Login");
});
```

---

## Calling External APIs

### Get Access Token in Controller

```csharp
using Microsoft.AspNetCore.Authentication;

public class ApiController : Controller
{
    private readonly IHttpClientFactory _httpClientFactory;

    public ApiController(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    [Authorize]
    public async Task<IActionResult> CallApi()
    {
        var accessToken = await HttpContext.GetTokenAsync("access_token");
        if (string.IsNullOrEmpty(accessToken))
        {
            return Unauthorized("No access token available");
        }

        var client = _httpClientFactory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", accessToken);

        var response = await client.GetAsync("https://your-api.com/data");
        var content = await response.Content.ReadAsStringAsync();

        return Ok(content);
    }
}
```

### Configure Audience for API Calls

Update `Program.cs` to request an access token for a specific audience:

```csharp
builder.Services.AddAuth0WebAppAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.ClientId = builder.Configuration["Auth0:ClientId"];
    options.ClientSecret = builder.Configuration["Auth0:ClientSecret"];
})
.WithAccessToken(options =>
{
    options.Audience = builder.Configuration["Auth0:Audience"]; // e.g., https://your-api-identifier
    options.UseRefreshTokens = true;
});
```

Add the audience to `appsettings.json`:

```json
{
  "Auth0": {
    "Domain": "your-tenant.us.auth0.com",
    "ClientId": "your_client_id",
    "Audience": "https://your-api-identifier"
  }
}
```

> Store `ClientSecret` in user-secrets (`dotnet user-secrets set "Auth0:ClientSecret" "your_client_secret"`) or environment variables — never commit secrets to source control.

---

## Custom Login Options

### Force a Specific Connection

```csharp
public async Task LoginWithGoogle(string returnUrl = "/")
{
    var authenticationProperties = new LoginAuthenticationPropertiesBuilder()
        .WithRedirectUri(returnUrl)
        .WithParameter("connection", "google-oauth2")
        .Build();

    await HttpContext.ChallengeAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
}
```

### Prompt for Signup

```csharp
public async Task Signup(string returnUrl = "/")
{
    var authenticationProperties = new LoginAuthenticationPropertiesBuilder()
        .WithRedirectUri(returnUrl)
        .WithParameter("screen_hint", "signup")
        .Build();

    await HttpContext.ChallengeAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
}
```

### Custom Logout Return URL

```csharp
[Authorize]
public async Task LogoutToGoodbye()
{
    var authenticationProperties = new LogoutAuthenticationPropertiesBuilder()
        .WithRedirectUri(Url.Action("Goodbye", "Home"))
        .Build();

    await HttpContext.SignOutAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
    await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
}
```

---

## Accessing User Information

### In Controllers

```csharp
[Authorize]
public IActionResult Profile()
{
    var name = User.Identity.Name;
    var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value;
    var picture = User.FindFirst(c => c.Type == "picture")?.Value;
    var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

    var model = new ProfileViewModel
    {
        Name = name,
        Email = email,
        Picture = picture,
        UserId = userId,
        Claims = User.Claims.ToList()
    };

    return View(model);
}
```

### In Views (Razor)

```html
@if (User.Identity.IsAuthenticated)
{
    <p>Welcome, @User.Identity.Name!</p>
    <img src='@User.FindFirst(c => c.Type == "picture")?.Value' alt="Profile" />
}
```

### In Blazor Components

```razor
@using Microsoft.AspNetCore.Components.Authorization
@inject AuthenticationStateProvider AuthStateProvider

<AuthorizeView>
    <Authorized>
        <p>Welcome, @context.User.Identity?.Name!</p>
        <img src='@context.User.FindFirst("picture")?.Value' alt="Profile" />
    </Authorized>
    <NotAuthorized>
        <p>Please <a href="/Login">log in</a>.</p>
    </NotAuthorized>
</AuthorizeView>
```

---

## Injecting User into All Views

Use a base controller or view imports to make the user available everywhere:

```csharp
// BaseController.cs
public abstract class BaseController : Controller
{
    protected string CurrentUserName => User.Identity.Name ?? "Guest";
    protected bool IsAuthenticated => User.Identity.IsAuthenticated;
}

// DashboardController.cs
public class DashboardController : BaseController
{
    [Authorize]
    public IActionResult Index()
    {
        ViewBag.UserName = CurrentUserName;
        return View();
    }
}
```

Or use `ViewData` in `_ViewStart.cshtml` via a filter:

```csharp
// AuthUserFilter.cs - inject user into all views automatically
public class AuthUserFilter : IActionFilter
{
    public void OnActionExecuting(ActionExecutingContext context)
    {
        if (context.Controller is Controller controller)
        {
            controller.ViewData["CurrentUser"] = controller.User.Identity.Name;
        }
    }

    public void OnActionExecuted(ActionExecutedContext context) { }
}

// Program.cs
builder.Services.AddControllersWithViews(options =>
{
    options.Filters.Add<AuthUserFilter>();
});
```

---

## Error Handling

### Global Unauthorized Redirect

```csharp
// Program.cs - redirect 401/403 to login page
app.UseStatusCodePages(async statusCodeContext =>
{
    var response = statusCodeContext.HttpContext.Response;
    if (response.StatusCode == 401)
    {
        response.Redirect("/Account/Login");
    }
    else if (response.StatusCode == 403)
    {
        response.Redirect("/Home/AccessDenied");
    }
});
```

### Handling Token Expiry (with .WithAccessToken)

```csharp
.WithAccessToken(options =>
{
    options.Audience = builder.Configuration["Auth0:Audience"];
    options.UseRefreshTokens = true;
    options.Events = new Auth0WebAppWithAccessTokenEvents
    {
        OnMissingRefreshToken = async (context) =>
        {
            // Refresh token missing - force re-login
            await context.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            context.Response.Redirect("/Account/Login");
        }
    };
});
```

---

## Blazor Server: Auth in Components

### AuthorizeView Component

```razor
<AuthorizeView>
    <Authorized>
        <!-- Only shown to authenticated users -->
        <p>Welcome, @context.User.Identity?.Name!</p>
    </Authorized>
    <NotAuthorized>
        <!-- Only shown to unauthenticated users -->
        <a href="/Login">Please log in</a>
    </NotAuthorized>
    <Authorizing>
        <!-- Shown while auth state is loading -->
        <p>Loading...</p>
    </Authorizing>
</AuthorizeView>
```

### Programmatic Auth State in Blazor

```razor
@inject AuthenticationStateProvider AuthStateProvider

@code {
    private bool isAuthenticated;
    private string userName = "";

    protected override async Task OnInitializedAsync()
    {
        var authState = await AuthStateProvider.GetAuthenticationStateAsync();
        var user = authState.User;
        isAuthenticated = user.Identity?.IsAuthenticated ?? false;
        userName = user.Identity?.Name ?? "";
    }
}
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Callback URL mismatch" | Ensure the callback URL in Auth0 Dashboard matches exactly (include both `http://localhost:5000/callback` and `https://localhost:{HTTPS_PORT}/callback` — check `Properties/launchSettings.json` for the actual port) |
| User not authenticated after login | Verify `UseAuthentication()` is before `UseAuthorization()` in `Program.cs` |
| Claims are `null` or missing | Check `Scope` includes `openid profile email` in configuration |
| Access token is empty | Configure `.WithAccessToken()` with `Audience` in `Program.cs` |
| Blazor `[Authorize]` not working | Add `AddCascadingAuthenticationState()` and `AddRazorPages()` to `Program.cs` |
| Redirect loop on login | Verify `Login` action does not have `[Authorize]` attribute |
| Logout does not end Auth0 session | Must call `SignOutAsync(Auth0Constants.AuthenticationScheme)` - calling only the cookie scheme skips Auth0 |

---

## Next Steps

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
