# Auth0 ASP.NET Core Web API Integration Patterns

Advanced integration patterns for ASP.NET Core Web API applications.

---

## Scope-Based Authorization

### Define Authorization Policies

In `Program.cs`, add policies that map to Auth0 API permissions:

```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("read:messages", policy =>
        policy.RequireClaim("scope", "read:messages"));

    options.AddPolicy("write:messages", policy =>
        policy.RequireClaim("scope", "write:messages"));

    options.AddPolicy("manage:orders", policy =>
    {
        policy.RequireClaim("scope", "read:orders");
        policy.RequireClaim("scope", "write:orders");
    });
});
```

### Apply Policies to Endpoints

**Minimal API:**

```csharp
app.MapGet("/api/messages", (HttpContext ctx) =>
{
    return Results.Ok(new { messages = new[] { "Hello", "World" } });
}).RequireAuthorization("read:messages");

app.MapPost("/api/messages", (HttpContext ctx) =>
{
    return Results.Created("/api/messages/1", new { id = 1 });
}).RequireAuthorization("write:messages");
```

**Controller-based:**

```csharp
[ApiController]
[Route("api/messages")]
public class MessagesController : ControllerBase
{
    [HttpGet]
    [Authorize(Policy = "read:messages")]
    public IActionResult GetMessages() =>
        Ok(new { messages = new[] { "Hello", "World" } });

    [HttpPost]
    [Authorize(Policy = "write:messages")]
    public IActionResult CreateMessage() =>
        Created("/api/messages/1", new { id = 1 });
}
```

### Define Permissions in Auth0

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Click the **Permissions** tab
4. Add permissions matching your policy names (e.g., `read:messages`, `write:messages`)

### Request Tokens with Scopes

Clients must request tokens that include the required scopes:

```bash
# Client Credentials with specific scopes
curl -X POST https://your-tenant.auth0.com/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "YOUR_CLIENT_ID",
    "client_secret": "YOUR_CLIENT_SECRET",
    "audience": "https://my-api.example.com",
    "grant_type": "client_credentials",
    "scope": "read:messages write:messages"
  }'
```

---

## DPoP Support

DPoP (Demonstrating Proof of Possession, RFC 9449) binds tokens to a specific client key pair, preventing token theft.

### Enable DPoP

```csharp
builder.Services.AddAuth0ApiAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.JwtBearerOptions = new JwtBearerOptions
    {
        Audience = builder.Configuration["Auth0:Audience"]
    };
})
.WithDPoP(); // Accept both DPoP and Bearer tokens (Allowed mode)
```

### DPoP Required Mode

To reject standard Bearer tokens and accept only DPoP-bound tokens:

```csharp
.WithDPoP(dpopOptions =>
{
    dpopOptions.Mode = DPoPModes.Required;
});
```

Optionally configure clock skew tolerance:

```csharp
.WithDPoP(dpopOptions =>
{
    dpopOptions.Mode = DPoPModes.Required;
    dpopOptions.IatOffset = 300;  // Allow 5-minute clock skew for iat claim
    dpopOptions.Leeway = 30;      // 30-second leeway for token validation
});
```

### DPoP Modes

| Mode | Behavior |
|------|----------|
| `DPoPModes.Allowed` (default) | Accept both DPoP-bound and standard Bearer tokens |
| `DPoPModes.Required` | Only accept DPoP-bound tokens; reject standard Bearer |
| `DPoPModes.Disabled` | Standard JWT Bearer only, DPoP disabled |

### Enable DPoP on Auth0 API

1. Go to Auth0 Dashboard → Applications → APIs
2. Select your API
3. Enable **Allow Skipping User Consent** and enable DPoP binding requirement

---

## Accessing User Claims

### From HttpContext in Minimal API

```csharp
app.MapGet("/api/profile", (HttpContext ctx) =>
{
    var userId = ctx.User.FindFirst("sub")?.Value;
    var email = ctx.User.FindFirst("https://example.com/email")?.Value; // custom claim
    var scopes = ctx.User.FindFirst("scope")?.Value?.Split(' ') ?? [];

    return Results.Ok(new { userId, scopes });
}).RequireAuthorization();
```

### From Controller

```csharp
[Authorize]
[HttpGet("profile")]
public IActionResult GetProfile()
{
    var userId = User.FindFirst("sub")?.Value;
    var scopes = User.FindFirst("scope")?.Value?.Split(' ') ?? [];

    return Ok(new { userId, scopes });
}
```

### Common JWT Claims

| Claim | Description |
|-------|-------------|
| `sub` | User ID (subject) |
| `scope` | Space-separated list of granted scopes |
| `aud` | Audience (your API identifier) |
| `iss` | Issuer (your Auth0 tenant URL) |
| `exp` | Expiration timestamp |
| `iat` | Issued-at timestamp |

Custom claims added via Auth0 Actions use namespaced keys, e.g., `https://your-domain.com/role`.

---

## Error Handling

### Return Problem Details for Auth Errors

```csharp
builder.Services.AddProblemDetails();

// Customize auth error responses
builder.Services.AddAuth0ApiAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.JwtBearerOptions = new JwtBearerOptions
    {
        Audience = builder.Configuration["Auth0:Audience"],
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
            },
            OnForbidden = context =>
            {
                context.Response.StatusCode = 403;
                context.Response.ContentType = "application/json";
                return context.Response.WriteAsJsonAsync(new
                {
                    error = "insufficient_scope",
                    error_description = "The access token does not have the required scopes."
                });
            }
        }
    };
});
```

### Standard Error Responses

| Status | Cause | Fix |
|--------|-------|-----|
| 401 | Missing or invalid token | Include valid `Authorization: Bearer <token>` header |
| 401 | Expired token | Request a fresh access token |
| 401 | Wrong audience | Token's `aud` claim must match your API Identifier |
| 403 | Insufficient scope | Token must include required scopes |

---

## Mixed Public and Protected Endpoints

```csharp
// Public - no auth needed
app.MapGet("/api/public", () =>
    Results.Ok(new { message = "Public endpoint" }));

// Protected - requires valid JWT
app.MapGet("/api/private", (HttpContext ctx) =>
    Results.Ok(new { message = "Private endpoint", userId = ctx.User.FindFirst("sub")?.Value }))
    .RequireAuthorization();

// Protected with scope
app.MapGet("/api/messages", (HttpContext ctx) =>
    Results.Ok(new { messages = Array.Empty<string>() }))
    .RequireAuthorization("read:messages");
```

---

## Custom Token Validation

For advanced scenarios, configure additional JWT validation parameters:

```csharp
builder.Services.AddAuth0ApiAuthentication(options =>
{
    options.Domain = builder.Configuration["Auth0:Domain"];
    options.JwtBearerOptions = new JwtBearerOptions
    {
        Audience = builder.Configuration["Auth0:Audience"],
        TokenValidationParameters = new TokenValidationParameters
        {
            NameClaimType = "sub",  // Map sub claim to User.Identity.Name
            ClockSkew = TimeSpan.FromSeconds(30)
        }
    };
});
```

---

## Testing

### Integration Testing with WebApplicationFactory

```csharp
public class ApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ApiTests(WebApplicationFactory<Program> factory) =>
        _factory = factory;

    [Fact]
    public async Task PublicEndpoint_Returns200()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/public");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task ProtectedEndpoint_WithoutToken_Returns401()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/private");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ProtectedEndpoint_WithValidToken_Returns200()
    {
        // Option 1: Real token from Auth0 CLI (requires network, good for integration tests)
        //   auth0 test token --audience https://my-api.example.com
        //
        // Option 2: Mock JWT for fast unit tests — override auth in WebApplicationFactory:
        //   _factory.WithWebHostBuilder(b => b.ConfigureTestServices(services =>
        //   {
        //       services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, o =>
        //       {
        //           o.TokenValidationParameters = new TokenValidationParameters
        //           {
        //               ValidateIssuer = false,
        //               ValidateAudience = false,
        //               ValidateLifetime = false,
        //               SignatureValidator = (token, _) => new JwtSecurityToken(token)
        //           };
        //       });
        //   }));
        //   Then generate a token with: new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(...))
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", "YOUR_TEST_TOKEN");

        var response = await client.GetAsync("/api/private");
        response.EnsureSuccessStatusCode();
    }
}
```

---

## Security Considerations

- **Never hardcode Domain or Audience** - Always use configuration (appsettings, User Secrets, environment variables)
- **Use HTTPS in production** - Auth0 requires HTTPS for token validation
- **Use minimal scopes** - Only request and enforce scopes your API actually needs
- **Keep packages updated** - Regularly update `Auth0.AspNetCore.Authentication.Api` for security patches

---

## References

- [API Reference](api.md)
- [Setup Guide](setup.md)
- [Main Skill](../SKILL.md)
