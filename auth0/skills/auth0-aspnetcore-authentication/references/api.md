# Auth0 ASP.NET Core Authentication API Reference

Complete configuration and API reference for ASP.NET Core web application authentication.

---

## AddAuth0WebAppAuthentication Configuration

### Complete Configuration Options

```csharp
using Auth0.AspNetCore.Authentication;

builder.Services.AddAuth0WebAppAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];         // required: tenant domain (without https://)
    options.ClientId = builder.Configuration["Auth0:ClientId"];     // required: app client ID
    options.ClientSecret = builder.Configuration["Auth0:ClientSecret"]; // required: app client secret
    options.CallbackPath = "/callback";                             // optional: defaults to /callback
    options.Backchannel = null;                                     // optional: custom HttpClient
    options.MaxAge = TimeSpan.FromDays(1);                          // optional: max auth age
    options.LoginParameters = new Dictionary<string, string>        // optional: extra OIDC params
    {
        { "audience", "https://your-api-identifier" }
    };
    options.Scope = "openid profile email";                         // optional: scopes to request
    options.ResponseType = "code";                                  // optional: default is "code"
    options.UsePkce = true;                                         // optional: default is true
    options.SkipCookieMiddleware = false;                           // optional: skip automatic cookie middleware
})
.WithAccessToken(tokenOptions =>
{
    tokenOptions.Audience = "https://your-api-identifier";          // required for API calls
    tokenOptions.UseRefreshTokens = true;                           // optional: enable refresh tokens
});
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `Domain` | Yes | Auth0 tenant domain (e.g., `tenant.us.auth0.com`) - without `https://` |
| `ClientId` | Yes | Application client ID from Auth0 Dashboard |
| `ClientSecret` | Yes | Application client secret from Auth0 Dashboard |
| `CallbackPath` | No | OAuth callback path - defaults to `/callback` |
| `Scope` | No | OIDC scopes - defaults to `openid profile email` |
| `LoginParameters` | No | Additional OIDC authorization parameters |
| `UsePkce` | No | PKCE code challenge - defaults to `true` (recommended) |

---

## LoginAuthenticationPropertiesBuilder

Fluent builder for constructing authentication properties used in the login challenge.

```csharp
var authenticationProperties = new LoginAuthenticationPropertiesBuilder()
    .WithRedirectUri("/dashboard")                 // redirect after login
    .WithParameter("screen_hint", "signup")        // Auth0 Universal Login hint
    .WithParameter("connection", "google-oauth2")  // force specific connection
    .WithParameter("ui_locales", "es")             // locale
    .Build();

await HttpContext.ChallengeAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
```

| Method | Description |
|--------|-------------|
| `.WithRedirectUri(uri)` | Post-login redirect URL |
| `.WithParameter(key, value)` | Arbitrary OIDC authorization parameter |
| `.WithOrganization(orgId)` | Auth0 Organizations support |
| `.WithInvitation(invitationId)` | Organization invitation flow |
| `.Build()` | Returns the configured `AuthenticationProperties` |

---

## LogoutAuthenticationPropertiesBuilder

Fluent builder for constructing authentication properties used in the logout flow.

```csharp
var authenticationProperties = new LogoutAuthenticationPropertiesBuilder()
    .WithRedirectUri(Url.Action("Index", "Home"))  // post-logout redirect
    .Build();

await HttpContext.SignOutAsync(Auth0Constants.AuthenticationScheme, authenticationProperties);
await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
```

| Method | Description |
|--------|-------------|
| `.WithRedirectUri(uri)` | Post-logout redirect URL |
| `.Build()` | Returns the configured `AuthenticationProperties` |

**Always call both `SignOutAsync` methods.** Calling only `Auth0Constants.AuthenticationScheme` signs out of Auth0 but leaves the local cookie intact. Calling only `CookieAuthenticationDefaults.AuthenticationScheme` clears the cookie but skips the Auth0 logout endpoint.

---

## WithAccessToken Options

Configure token storage for API calls via the `.WithAccessToken()` extension:

```csharp
builder.Services.AddAuth0WebAppAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.ClientId = builder.Configuration["Auth0:ClientId"];
    options.ClientSecret = builder.Configuration["Auth0:ClientSecret"];
})
.WithAccessToken(tokenOptions =>
{
    tokenOptions.Audience = builder.Configuration["Auth0:Audience"]; // required for API calls
    tokenOptions.UseRefreshTokens = true;                            // enable refresh token rotation
    tokenOptions.Events = new Auth0WebAppWithAccessTokenEvents       // optional event hooks
    {
        OnMissingRefreshToken = async (context) =>
        {
            await context.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            context.Response.Redirect("/login");
        }
    };
});
```

Retrieve the access token in controllers:

```csharp
var accessToken = await HttpContext.GetTokenAsync("access_token");
```

---

## Claims Reference

After login, user claims are available via `User.FindFirst()` or `HttpContext.User.FindFirst()`.

| Claim Type | Value | Access Pattern |
|------------|-------|----------------|
| `sub` | Auth0 user ID (e.g., `google-oauth2\|123456`) | `User.FindFirst(ClaimTypes.NameIdentifier)?.Value` |
| `name` | Display name | `User.Identity.Name` |
| `email` | Email address | `User.FindFirst(ClaimTypes.Email)?.Value` |
| `picture` | Avatar URL | `User.FindFirst(c => c.Type == "picture")?.Value` |
| `email_verified` | Boolean string | `User.FindFirst(c => c.Type == "email_verified")?.Value` |
| `nickname` | Username/nickname | `User.FindFirst(c => c.Type == "nickname")?.Value` |
| `updated_at` | Last profile update | `User.FindFirst(c => c.Type == "updated_at")?.Value` |

**Note:** Standard claims like `email` are mapped to `ClaimTypes.Email` by ASP.NET Core's OIDC middleware. Custom claims added via Auth0 Rules or Actions are available by their exact type string.

---

## Cookie Configuration

The SDK uses ASP.NET Core's cookie authentication middleware by default. Cookie behavior is configurable:

```csharp
builder.Services.AddAuth0WebAppAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.ClientId = builder.Configuration["Auth0:ClientId"];
    options.ClientSecret = builder.Configuration["Auth0:ClientSecret"];
    options.SkipCookieMiddleware = true; // take control of cookie middleware yourself
});

// Configure cookie manually when SkipCookieMiddleware = true
builder.Services.AddAuthentication()
    .AddCookie(options =>
    {
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;     // HTTPS only in production
        options.Cookie.HttpOnly = true;                               // no JS access
        options.Cookie.SameSite = SameSiteMode.Lax;                  // CSRF protection
        options.SlidingExpiration = true;
        options.ExpireTimeSpan = TimeSpan.FromHours(1);
    });
```

---

## Middleware Configuration

```csharp
var app = builder.Build();

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.UseAuthentication();    // MUST come before UseAuthorization
app.UseAuthorization();     // Checks [Authorize] attributes

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
```

Middleware order is critical:
1. `UseRouting()` - before auth middleware so route information is available
2. `UseAuthentication()` - reads the cookie and sets `HttpContext.User`
3. `UseAuthorization()` - enforces `[Authorize]` policies using the populated `HttpContext.User`

---

## Auth0Constants

```csharp
Auth0Constants.AuthenticationScheme  // = "Auth0"
```

Use this constant instead of the string `"Auth0"` to avoid typos.

---

## Testing

### Local Testing

1. Configure `appsettings.json` or user-secrets with your Auth0 credentials
2. Start your app: `dotnet run`
3. Visit `http://localhost:5000/Account/Login`
4. Complete the Auth0 Universal Login flow
5. Verify redirect back to app and claims accessible on profile page
6. Click logout and verify both cookies are cleared

---

## References

- [Auth0.AspNetCore.Authentication on NuGet](https://www.nuget.org/packages/Auth0.AspNetCore.Authentication)
- [Auth0.AspNetCore.Authentication GitHub](https://github.com/auth0/auth0-aspnetcore-authentication)
- [ASP.NET Core Authentication Documentation](https://learn.microsoft.com/en-us/aspnet/core/security/authentication)

---

## Next Steps

- [Integration Guide](integration.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
