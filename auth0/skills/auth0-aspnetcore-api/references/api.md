# Auth0 ASP.NET Core Web API - API Reference

Complete reference for Auth0.AspNetCore.Authentication.Api configuration options and extension methods.

---

## Extension Methods

### `AddAuth0ApiAuthentication`

Registers Auth0 JWT Bearer authentication with the dependency injection container.

```csharp
builder.Services.AddAuth0ApiAuthentication(options =>
{
    options.Domain = "your-tenant.auth0.com";
    options.JwtBearerOptions = new JwtBearerOptions
    {
        Audience = "https://my-api.example.com"
    };
});
```

---

## Auth0ApiAuthenticationOptions

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `Domain` | `string` | Yes | Auth0 tenant domain. Format: `your-tenant.auth0.com` (no `https://` prefix) |
| `JwtBearerOptions` | `JwtBearerOptions` | Yes | Microsoft JWT Bearer options. Set `Audience` here. |

### `Domain`

Your Auth0 tenant domain. The library constructs the authority URL as `https://{Domain}/`.

```csharp
options.Domain = builder.Configuration["Auth0:Domain"];
// e.g., "dev-abc123.us.auth0.com"
```

### `JwtBearerOptions`

Full access to the underlying [Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerOptions](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.authentication.jwtbearer.jwtbeareroptions).

Key sub-properties:

| Property | Type | Description |
|----------|------|-------------|
| `Audience` | `string` | API Identifier from Auth0. Must exactly match. |
| `TokenValidationParameters` | `TokenValidationParameters` | Additional token validation rules |
| `Events` | `JwtBearerEvents` | Hooks into authentication lifecycle |
| `SaveToken` | `bool` | Whether to save the raw token in the auth properties |
| `RequireHttpsMetadata` | `bool` | Defaults to `true` in production |
| `IncludeErrorDetails` | `bool` | Include error details in 401/403 responses |

---

## Auth0ApiAuthenticationBuilder

Returned by `AddAuth0ApiAuthentication`. Fluent builder for additional configuration.

### `.WithDPoP()`

Enables DPoP token validation with default settings (Allowed mode).

```csharp
builder.Services.AddAuth0ApiAuthentication(options => { ... })
    .WithDPoP();
```

### `.WithDPoP(Action<DPoPOptions> configureDPoP)`

Enables DPoP with custom configuration.

```csharp
builder.Services.AddAuth0ApiAuthentication(options => { ... })
    .WithDPoP(dpop =>
    {
        dpop.Mode = DPoPModes.Required;
        dpop.IatOffset = 300;
        dpop.Leeway = 30;
    });
```

---

## DPoPOptions

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Mode` | `DPoPModes` | `Allowed` | Controls which token types are accepted |
| `IatOffset` | `int` | `0` | Allowed clock skew in seconds for the `iat` claim |
| `Leeway` | `int` | `0` | Additional leeway in seconds for token time validation |

### DPoPModes Enum

| Value | Description |
|-------|-------------|
| `DPoPModes.Allowed` | Accept both DPoP-bound and standard Bearer tokens |
| `DPoPModes.Required` | Only accept DPoP-bound tokens; reject standard Bearer |
| `DPoPModes.Disabled` | Disable DPoP; standard JWT Bearer only |

---

## ASP.NET Core Authorization

Auth0 does not provide custom authorization attributes. Use standard ASP.NET Core authorization:

### Policy-Based Authorization

```csharp
// Register policies
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("read:messages", policy =>
        policy.RequireClaim("scope", "read:messages"));
});

// Apply to Minimal API
app.MapGet("/endpoint", handler).RequireAuthorization("read:messages");

// Apply to controller action
[Authorize(Policy = "read:messages")]
public IActionResult GetMessages() { ... }
```

### Attribute-Based Authorization

```csharp
// Require any authenticated user
[Authorize]
public IActionResult Private() { ... }

// Require specific policy
[Authorize(Policy = "read:messages")]
public IActionResult Messages() { ... }

// Allow anonymous on an otherwise protected controller
[AllowAnonymous]
public IActionResult Public() { ... }
```

---

## JwtBearerEvents Hooks

Configure callbacks for authentication lifecycle events:

| Event | When | Common Use |
|-------|------|------------|
| `OnTokenValidated` | After token is validated | Extract custom claims, enrich identity |
| `OnAuthenticationFailed` | Token validation fails | Custom logging, error responses |
| `OnChallenge` | 401 response about to be sent | Customize 401 response body |
| `OnForbidden` | 403 response about to be sent | Customize 403 response body |
| `OnMessageReceived` | Before token extraction | Extract token from non-standard location |

**Example - Custom 401 response:**

```csharp
options.JwtBearerOptions = new JwtBearerOptions
{
    Audience = "...",
    Events = new JwtBearerEvents
    {
        OnChallenge = context =>
        {
            context.HandleResponse();
            context.Response.StatusCode = 401;
            context.Response.ContentType = "application/json";
            return context.Response.WriteAsJsonAsync(new
            {
                error = "unauthorized",
                error_description = "A valid access token is required."
            });
        }
    }
};
```

---

## References

- [Auth0 ASP.NET Core Web API Quickstart](https://auth0.com/docs/quickstart/backend/aspnet-core-webapi)
- [SDK GitHub Repository](https://github.com/auth0/aspnetcore-api)
- [Microsoft JWT Bearer Documentation](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/jwtbearer)
